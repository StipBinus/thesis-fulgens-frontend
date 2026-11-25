import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/finance_api.dart';
import '../finance/finance_local_store.dart';
import '../finance/finance_repository.dart';
import '../../core/db/outbox_store.dart';
import '../../core/db/uuid_v7.dart';
import '../../core/sync/sync_scheduler.dart';
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

  // Entry delete: queues a soft delete for each removed entry
  Future<void> deleteEntries(List<String> entryIds);

  // Current balance from the SQLite `users_children` row.
  Future<int> readBalance();

  // Balance and pocket changes for one entry edit.
  Future<void> moveMoney({
    required int balanceDelta,
    String? pocketId,
    required int pocketDelta,
    String? note,
  });
}

class ApiLogbookRepository implements LogbookRepository {
  ApiLogbookRepository({
    FinanceApi? api,
    LogbookLocalStore? local,
    OutboxStore? outbox,
    FinanceLocalStore? finance,
    ChildIdentity? identity,
    this.localOnly = false,
  }) : _api = api ?? FinanceApi(),
       _local = local ?? LogbookLocalStore(),
       _outbox = outbox ?? OutboxStore(),
       _finance = finance ?? FinanceLocalStore(),
       _identity = identity ?? ChildIdentity();

  final FinanceApi _api;
  final LogbookLocalStore _local;
  final OutboxStore _outbox;
  final FinanceLocalStore _finance;
  final ChildIdentity _identity;

  @override
  final bool localOnly;

  @override
  Future<LogbookState?> load() async {
    try {
      await _local.bindChild(await _identity.childId());
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
    final logClientId = (clientId == null || clientId.isEmpty)
        ? uuidV7()
        : clientId;
    final now = DateTime.now().toIso8601String();

    String? childId;
    try {
      childId = await _identity.childId();
    } catch (_) {
      // Local mode still works without a readable session.
    }

    // Sync only: server log ids are the app's client ids now
    await _enqueueDay(childId, dateKey, logClientId, note, stamped, now);

    unawaited(_drain());

    return LogbookDay(
      clientId: logClientId,
      logId: logId,
      entries: stamped,
      note: note,
    );
  }

  @override
  Future<void> deleteEntries(List<String> entryIds) async {
    String? childId;
    try {
      childId = await _identity.childId();
    } catch (_) {
      // Deleting offline is still allowed; the queue drains later.
    }

    final now = DateTime.now().toIso8601String();
    for (final id in entryIds) {
      if (id.isEmpty) continue;
      try {
        // Replaces any unsent upsert; unknown ids are a no-op on the server
        await _outbox.enqueue(
          entity: 'transaction_entries',
          entityId: id,
          op: 'delete',
          childId: childId,
          payload: {'client_id': id, 'deleted_at': now},
        );
      } catch (_) {
        // Keep the local delete even if queuing fails.
      }
    }
    unawaited(_drain());
  }

  @override
  Future<int> readBalance() async {
    final childId = await _identity.childId();
    return _finance.childBalance(childId);
  }

  @override
  Future<void> moveMoney({
    required int balanceDelta,
    String? pocketId,
    required int pocketDelta,
    String? note,
  }) async {
    if (balanceDelta == 0 && pocketDelta == 0) return;
    // Cached child id: an expired token offline must not drop the money move
    final childId = await _identity.childId();
    if (balanceDelta != 0) {
      await _finance.adjustBalance(childId, balanceDelta);
    }
    if (pocketDelta != 0 && _isRealPocket(pocketId)) {
      await _finance.adjustPocket(childId, pocketId!, pocketDelta, note: note);
    }
  }

  bool _isRealPocket(String? pocketId) {
    return pocketId != null &&
        pocketId.isNotEmpty &&
        pocketId != 'cash' &&
        pocketId != '-1';
  }

  Future<void> _enqueueDay(
    String? childId,
    String dateKey,
    String logClientId,
    String note,
    List<LogbookEntry> entries,
    String now,
  ) async {
    try {
      // A removed entry must not come back on the next login pull.
      try {
        final keep = {for (final entry in entries) entry.id};
        final pending = await _outbox.pending(childId: childId, limit: 1000);
        for (final item in pending) {
          if (item.entity != 'transaction_entries') continue;
          if (item.payload['log_client_id'] != logClientId) continue;
          if (keep.contains(item.entityId)) continue;
          await _outbox.discardPending('transaction_entries', item.entityId);
        }
      } catch (_) {
        // The newest rows still queue below.
      }

      await _outbox.enqueue(
        entity: 'daily_transaction_logs',
        entityId: logClientId,
        op: 'upsert',
        childId: childId,
        payload: {
          'client_id': logClientId,
          'child_id': childId,
          'log_date': dateKey,
          'summary': note,
          'created_at': now,
          'updated_at': now,
          'original_text': null,
          'ai_input_process': null,
        },
      );

      for (final entry in entries) {
        await _outbox.enqueue(
          entity: 'transaction_entries',
          entityId: entry.id,
          op: 'upsert',
          childId: childId,
          payload: {
            'client_id': entry.id,
            'log_client_id': logClientId,
            'transaction_type': logbookEntryTypeApiName(entry.type),
            'name': entry.title.trim().isEmpty
                ? entry.category.label
                : entry.title,
            'amount': entry.amount,
            'created_at': now,
            'category': logbookCategoryApiName(entry.category),
            'pocket_id': entry.pocketId,
            'pocket_name': entry.pocketName,
          },
        );
      }
    } catch (_) {
      // A failed queue write must not block the local save.
    }
  }

  Future<void> _drain() => SyncScheduler.instance.request();

  // Entries created offline need a stable key the UI can edit and delete.
  List<LogbookEntry> _stampLocalIds(List<LogbookEntry> entries) {
    return [
      for (final entry in entries)
        entry.id.isNotEmpty ? entry : entry.copyWith(id: uuidV7()),
    ];
  }

  LogbookDay _dayFromLog(Map<String, dynamic> raw) {
    final rawTransactions = raw['transactions'] as List<dynamic>? ?? const [];
    return LogbookDay(
      clientId: raw['logId']?.toString() ?? '',
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
}

final logbookRepositoryProvider = Provider<LogbookRepository>(
  (ref) => ApiLogbookRepository(
    localOnly: true,
    identity: ref.watch(childIdentityProvider),
  ),
);
