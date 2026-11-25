import '../../kids/finance/finance_api.dart';
import '../../kids/logbook/logbook_local_store.dart';
import '../db/local_data.dart';
import '../db/outbox_store.dart';

class SyncReport {
  const SyncReport({this.sent = 0, this.failed = 0, this.pending = 0});

  final int sent;
  final int failed;
  final int pending;

  bool get clean => pending == 0 && failed == 0;
}

// Drains the outbox. New rows go through /api/sync, pulled rows stay on REST.
class SyncEngine {
  SyncEngine({OutboxStore? outbox, FinanceApi? api, LogbookLocalStore? logbook})
    : _outbox = outbox ?? OutboxStore(),
      _api = api ?? FinanceApi(),
      _logbook = logbook ?? LogbookLocalStore();

  static const String legacyLog = 'legacy_daily_transaction_log';

  // Batch: everything /api/sync accepts in one envelope
  static const Set<String> batchEntities = {
    'daily_transaction_logs',
    'transaction_entries',
    'users_pocket',
    'users_goals',
  };

  static const Set<String> syncableEntities = {legacyLog, ...batchEntities};

  // Conflict message: "... already exists with id <id>; re-key ..."
  static final RegExp _conflictId = RegExp(r'with id (\S+?);');

  final OutboxStore _outbox;
  final FinanceApi _api;
  final LogbookLocalStore _logbook;

  Future<SyncReport> syncNow({String? childId}) async {
    final id = childId ?? await _api.childId();
    var sent = 0;
    var failed = 0;

    final legacy = await _outbox.pending(childId: id, entities: {legacyLog});
    for (final row in legacy) {
      if (await _sendLegacy(row)) {
        sent++;
      } else {
        failed++;
      }
    }

    // Retry once after a conflict re-key
    for (var round = 0; round < 2; round++) {
      final result = await _sendBatch(id);
      sent += result.sent;
      failed += result.failed;
      if (!result.rekeyed) break;
    }

    final pending = await _outbox.pendingCount(
      childId: id,
      entities: syncableEntities,
    );
    return SyncReport(sent: sent, failed: failed, pending: pending);
  }

  Future<({int sent, int failed, bool rekeyed})> _sendBatch(String id) async {
    final batch = await _outbox.pending(
      childId: id,
      limit: 200,
      entities: batchEntities,
    );
    if (batch.isEmpty) return (sent: 0, failed: 0, rekeyed: false);

    var sent = 0;
    var failed = 0;
    try {
      final payload = await _api.post('/api/sync', {
        'schemaVersion': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'childId': id,
        'ops': [
          for (final row in batch)
            {
              'entity': row.entity,
              'op': row.op,
              'entityId': row.entityId,
              'payload': _withChild(row, id),
            },
        ],
      });

      final results = <String, Map<String, dynamic>>{};
      if (payload is Map<String, dynamic> && payload['results'] is List) {
        for (final item in (payload['results'] as List)) {
          if (item is! Map<String, dynamic>) continue;
          results['${item['entity']}|${item['entityId']}'] = item;
        }
      }

      // Conflict: move the day onto the server's id before marking anything
      final rekeyed = <String>{};
      for (final row in batch) {
        if (row.entity != 'daily_transaction_logs') continue;
        final item = results['${row.entity}|${row.entityId}'];
        if (item?['status'] != 'CONFLICT') continue;
        final match = _conflictId.firstMatch('${item?['message'] ?? ''}');
        final serverId = match?.group(1);
        if (serverId == null || serverId == row.entityId) continue;
        await _logbook.rekeyLog(row.entityId, serverId);
        await _outbox.rekeyLog(row.entityId, serverId);
        rekeyed.add(row.entityId);
      }
      if (rekeyed.isNotEmpty) LocalData.instance.bump();

      for (final row in batch) {
        final movedLog =
            row.entity == 'daily_transaction_logs' &&
            rekeyed.contains(row.entityId);
        final movedEntry =
            row.entity == 'transaction_entries' &&
            rekeyed.contains(row.payload['log_client_id']);
        if (movedLog || movedEntry) continue;

        final status = results['${row.entity}|${row.entityId}']?['status'];
        if (status == 'SUCCESS' || status == 'SKIPPED') {
          await _outbox.markSent(row.id);
          sent++;
        } else {
          final message = results['${row.entity}|${row.entityId}']?['message'];
          await _outbox.markFailed(
            row.id,
            'Sync rejected (${status ?? 'no result'}): ${message ?? ''}',
          );
          failed++;
        }
      }
      return (sent: sent, failed: failed, rekeyed: rekeyed.isNotEmpty);
    } catch (error) {
      for (final row in batch) {
        await _outbox.markFailed(row.id, error);
      }
      return (sent: 0, failed: batch.length, rekeyed: false);
    }
  }

  // Child id: rows may have been queued before the session was readable
  Map<String, dynamic> _withChild(OutboxItem row, String id) {
    switch (row.entity) {
      case 'daily_transaction_logs':
        return {...row.payload, 'child_id': id};
      case 'users_pocket':
      case 'users_goals':
        return row.op == 'delete' ? row.payload : {...row.payload, 'childId': id};
      default:
        return row.payload;
    }
  }

  Future<bool> _sendLegacy(OutboxItem row) async {
    try {
      if (row.op == 'delete') {
        await _api.delete('/api/transaction-logs/${row.entityId}');
      } else {
        await _api.put('/api/transaction-logs/${row.entityId}', row.payload);
      }
      await _outbox.markSent(row.id);
      return true;
    } catch (error) {
      await _outbox.markFailed(row.id, error);
      return false;
    }
  }
}
