import '../../kids/finance/finance_api.dart';
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
  SyncEngine({OutboxStore? outbox, FinanceApi? api})
    : _outbox = outbox ?? OutboxStore(),
      _api = api ?? FinanceApi();

  static const String legacyLog = 'legacy_daily_transaction_log';

  static const Set<String> batchEntities = {
    'daily_transaction_logs',
    'transaction_entries',
  };

  final OutboxStore _outbox;
  final FinanceApi _api;

  Future<SyncReport> syncNow({String? childId}) async {
    final id = childId ?? await _api.childId();
    final rows = await _outbox.pending(childId: id);
    var sent = 0;
    var failed = 0;

    for (final row in rows.where((item) => item.entity == legacyLog)) {
      if (await _sendLegacy(row)) {
        sent++;
      } else {
        failed++;
      }
    }

    final batch = rows
        .where((item) => batchEntities.contains(item.entity))
        .toList();

    if (batch.isNotEmpty) {
      try {
        final payload = await _api.post('/api/sync/transactions', {
          'schemaVersion': 1,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'childId': id,
          'ops': [
            for (final row in batch)
              {
                'entity': row.entity,
                'op': row.op,
                'entityId': row.entityId,
                'payload': row.payload,
              },
          ],
        });

        final statuses = <String, String>{};
        if (payload is Map<String, dynamic> && payload['results'] is List) {
          for (final item in (payload['results'] as List)) {
            if (item is! Map<String, dynamic>) continue;
            statuses['${item['entity']}|${item['entityId']}'] =
                '${item['status']}';
          }
        }

        for (final row in batch) {
          final status = statuses['${row.entity}|${row.entityId}'];
          if (status == 'SUCCESS' || status == 'SKIPPED') {
            await _outbox.markSent(row.id);
            sent++;
          } else {
            await _outbox.markFailed(
              row.id,
              'Sync rejected (${status ?? 'no result'})',
            );
            failed++;
          }
        }
      } catch (error) {
        for (final row in batch) {
          await _outbox.markFailed(row.id, error);
        }
        failed += batch.length;
      }
    }

    final pending = await _outbox.pendingCount(childId: id);
    return SyncReport(sent: sent, failed: failed, pending: pending);
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
