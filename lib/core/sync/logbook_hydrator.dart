import 'package:sqflite/sqflite.dart';

import '../../kids/finance/finance_api.dart';
import '../../kids/logbook/logbook_local_store.dart';
import '../../kids/logbook/logbook_models.dart';
import '../db/app_db.dart';
import '../db/uuid_v7.dart';

// Downloads the logbook once per child, when that child has no local rows.
class LogbookHydrator {
  LogbookHydrator({
    FinanceApi? api,
    LogbookLocalStore? store,
    AppDb? db,
  }) : _api = api ?? FinanceApi(),
       _store = store ?? LogbookLocalStore(),
       _appDb = db ?? AppDb.instance;

  final FinanceApi _api;
  final LogbookLocalStore _store;
  final AppDb _appDb;

  Future<bool> ensureHydrated({String? childId}) async {
    final id = childId ?? await _api.childId();
    if (await _marked(id)) return false;

    if (await _store.hasRows(id)) {
      await _mark(id);
      return false;
    }

    final payload = await _api.get('/api/transaction-logs/child/$id');
    if (payload is! List) return false;

    final days = <String, LogbookDay>{};
    for (final raw in payload.whereType<Map<String, dynamic>>()) {
      final dateKey = raw['logDate'] as String? ?? '';
      if (dateKey.isEmpty) continue;

      final entries = <LogbookEntry>[];
      for (final item in (raw['transactions'] as List? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        entries.add(
          LogbookEntry(
            id: uuidV7(),
            type: logbookEntryTypeFromApi(item['transactionType']),
            amount: (item['amount'] as num?)?.toInt() ?? 0,
            category: logbookCategoryFromApi(item['category']),
            title: item['name'] as String? ?? '',
          ),
        );
      }

      days[dateKey] = LogbookDay(
        clientId: uuidV7(),
        logId: (raw['logId'] as num?)?.toInt(),
        entries: entries,
        note: raw['summary'] as String? ?? '',
      );
    }

    await _store.saveHydrated(
      id,
      LogbookState(days: days, berries: 0, coinsEarned: 0, loaded: true),
    );
    await _mark(id);
    return true;
  }

  Future<bool> _marked(String childId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'sync_state',
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _mark(String childId) async {
    final db = await _appDb.db;
    await db.insert('sync_state', {
      'child_id': childId,
      'hydrated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
