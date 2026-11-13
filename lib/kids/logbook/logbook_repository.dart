import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/finance_api.dart';
import '../../core/db/outbox_store.dart';
import '../../core/db/uuid_v7.dart';
import 'logbook_local_store.dart';
import 'logbook_models.dart';

/// Transaction-log persistence backed by `/api/transaction-logs`.
///
/// Entries and daily notes are read from and written to the backend. Local
/// preferences only keep a fallback copy plus non-transaction UI state
/// (berries, coins, reward flags, zero-spend marks) so the logbook still opens
/// when the device is offline.
abstract class LogbookRepository {
  Future<LogbookState?> load();

  /// True while the app runs on SQLite only and skips the backend.
  bool get localOnly;

  Future<void> save(LogbookState state);

  Future<LogbookDay> upsertDay({
    required String dateKey,
    required String note,
    required List<LogbookEntry> entries,
    int? logId,
    String? clientId,
  });

  Future<void> deleteLog({int? logId, required String dateKey});
}

class ApiLogbookRepository implements LogbookRepository {
  ApiLogbookRepository({
    FinanceApi? api,
    LogbookLocalStore? local,
    OutboxStore? outbox,
    this.localOnly = false,
  }) : _api = api ?? FinanceApi(),
       _local = local ?? LogbookLocalStore(),
       _outbox = outbox ?? OutboxStore();

  final FinanceApi _api;
  final LogbookLocalStore _local;
  final OutboxStore _outbox;

  @override
  final bool localOnly;

  @override
  Future<LogbookState?> load() async {
    try {
      await _local.bindChild(await _api.childId());
    } catch (_) {
      // A parent session has no child id; the mirror keeps its last known one.
    }
    await _local.migrateFromPreferences();
    final local = await _local.load();
    if (localOnly) return local;

    try {
      final childId = await _api.childId();
      final payload = await _api.get('/api/transaction-logs/child/$childId');
      if (payload is! List) return local;

      final days = <String, LogbookDay>{};
      for (final raw in payload.whereType<Map<String, dynamic>>()) {
        final dateKey = raw['logDate'] as String?;
        if (dateKey == null || dateKey.isEmpty) continue;
        days[dateKey] = _dayFromLog(raw);
      }

      if (local != null) {
        for (final item in local.days.entries) {
          final remote = days[item.key];
          if (remote == null) {
            // Keep days that only carry local UI state (zero-spend/reward).
            if (item.value.entries.isEmpty) days[item.key] = item.value;
            continue;
          }

          days[item.key] = remote.copyWith(
            entries: _mergeEntryMeta(remote.entries, item.value.entries),
            rewardClaimed: item.value.rewardClaimed,
            zeroSpend: item.value.zeroSpend,
            completedAt: item.value.completedAt,
          );
        }
      }

      final merged = LogbookState(
        days: days,
        berries: local?.berries ?? 0,
        coinsEarned: local?.coinsEarned ?? 0,
        lastClaimKey: local?.lastClaimKey,
        lastClaimCoins: local?.lastClaimCoins ?? 0,
        lastClaimBerries: local?.lastClaimBerries ?? 0,
        loaded: true,
      );
      await _local.save(merged);
      return merged;
    } catch (_) {
      // Offline or a parent session: use the last local copy.
      return local;
    }
  }

  @override
  Future<void> save(LogbookState state) async {
    try {
      await _local.save(state);
    } catch (_) {
      // Local caching is a fallback; a failed write must not break logging.
    }
  }

  @override
  Future<LogbookDay> upsertDay({
    required String dateKey,
    required String note,
    required List<LogbookEntry> entries,
    int? logId,
    String? clientId,
  }) async {
    final stamped = _stampLocalIds(entries);
    String childId = 'local';
    try {
      childId = await _api.childId();
    } catch (_) {
      // Local mode still works without a readable session.
    }
    final body = <String, dynamic>{
      'childId': childId,
      'logDate': dateKey,
      'summary': note,
      'transactions': stamped.map(_entryToRequest).toList(),
    };

    final queueId = await _outbox.enqueue(
      entity: 'daily_transaction_log',
      entityId: dateKey,
      op: 'upsert',
      payload: body,
    );

    if (localOnly) {
      return LogbookDay(
        clientId: clientId ?? '',
        logId: logId,
        entries: stamped,
        note: note,
      );
    }

    dynamic payload;
    try {
      if (logId != null) {
        payload = await _api.put('/api/transaction-logs/$logId', body);
      } else {
        try {
          payload = await _api.post('/api/transaction-logs', body);
        } catch (_) {
          // The backend allows one log per child per date. If a log already
          // exists (for example after an offline start), update it instead.
          final existingId = await _findLogId(dateKey);
          if (existingId == null) rethrow;
          payload = await _api.put('/api/transaction-logs/$existingId', body);
        }
      }
      await _outbox.markSent(queueId);
    } catch (error) {
      await _outbox.markFailed(queueId, error);
      rethrow;
    }

    return _dayFromLog(_asMap(payload));
  }

  @override
  Future<void> deleteLog({int? logId, required String dateKey}) async {
    final queueId = await _outbox.enqueue(
      entity: 'daily_transaction_log',
      entityId: logId?.toString() ?? dateKey,
      op: 'delete',
      payload: {'logId': logId, 'logDate': dateKey},
    );

    if (localOnly) return;
    if (logId == null) return;
    try {
      await _api.delete('/api/transaction-logs/$logId');
      await _outbox.markSent(queueId);
    } catch (error) {
      await _outbox.markFailed(queueId, error);
      rethrow;
    }
  }

  Future<int?> _findLogId(String dateKey) async {
    try {
      final childId = await _api.childId();
      final payload = await _api.get('/api/transaction-logs/child/$childId');
      if (payload is! List) return null;

      for (final raw in payload.whereType<Map<String, dynamic>>()) {
        if (raw['logDate'] != dateKey) continue;
        final id = raw['logId'];
        if (id is num) return id.toInt();
      }
    } catch (_) {
      // Fall through and let the original error surface.
    }
    return null;
  }

  // Entries created offline need a stable key the UI can edit and delete.
  List<LogbookEntry> _stampLocalIds(List<LogbookEntry> entries) {
    return [
      for (final entry in entries)
        entry.id.isNotEmpty ? entry : entry.copyWith(id: uuidV7()),
    ];
  }

  Map<String, dynamic> _entryToRequest(LogbookEntry entry) {
    final title = entry.title.trim();
    return {
      'transactionType': logbookEntryTypeApiName(entry.type),
      'name': title.isEmpty ? entry.category.label : title,
      'amount': entry.amount,
      'category': logbookCategoryApiName(entry.category),
    };
  }

  LogbookDay _dayFromLog(Map<String, dynamic> raw) {
    final rawTransactions = raw['transactions'] as List<dynamic>? ?? const [];
    return LogbookDay(
      logId: (raw['logId'] as num?)?.toInt(),
      note: raw['summary'] as String? ?? '',
      entries:
          rawTransactions
              .whereType<Map<String, dynamic>>()
              .map(_entryFromLog)
              .toList(),
    );
  }

  LogbookEntry _entryFromLog(Map<String, dynamic> raw) {
    return LogbookEntry(
      id: raw['transactionId']?.toString() ?? '',
      type: logbookEntryTypeFromApi(raw['transactionType']),
      amount: (raw['amount'] as num?)?.toInt() ?? 0,
      category: logbookCategoryFromApi(raw['category']),
      title: raw['name'] as String? ?? '',
    );
  }

  List<LogbookEntry> _mergeEntryMeta(
    List<LogbookEntry> remote,
    List<LogbookEntry> local,
  ) {
    if (remote.isEmpty || local.isEmpty) return remote;

    return [
      for (var i = 0; i < remote.length; i++)
        i < local.length
            ? remote[i].copyWith(
              pocketId: local[i].pocketId,
              pocketName: local[i].pocketName,
              note: local[i].note,
            )
            : remote[i],
    ];
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    throw const FinanceApiException('Unexpected response from the server.');
  }
}

final logbookRepositoryProvider = Provider<LogbookRepository>(
  (ref) => ApiLogbookRepository(localOnly: true),
);
