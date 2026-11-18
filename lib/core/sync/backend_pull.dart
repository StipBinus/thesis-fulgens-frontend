// Replaces the phone child data with the backend copy at login, then re-applies
// the writes still waiting in the outbox.

import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../kids/finance/finance_api.dart';
import '../../kids/finance/finance_local_store.dart';
import '../../kids/finance/finance_models.dart';
import '../../kids/logbook/logbook_local_store.dart';
import '../../kids/logbook/logbook_models.dart';
import '../db/app_db.dart';
import '../db/outbox_store.dart';
import '../db/uuid_v7.dart';
import '../profile/child_profile.dart';
import '../profile/child_profile_store.dart';
import 'sync_engine.dart';

class BackendPull {
  BackendPull({
    FinanceApi? api,
    FinanceLocalStore? finance,
    LogbookLocalStore? logbook,
    OutboxStore? outbox,
    ChildProfileStore? profile,
    AppDb? db,
  }) : _api = api ?? FinanceApi(),
       _finance = finance ?? FinanceLocalStore(),
       _logbook = logbook ?? LogbookLocalStore(),
       _outbox = outbox ?? OutboxStore(),
       _profile = profile ?? ChildProfileStore.instance,
       _appDb = db ?? AppDb.instance;

  final FinanceApi _api;
  final FinanceLocalStore _finance;
  final LogbookLocalStore _logbook;
  final OutboxStore _outbox;
  final ChildProfileStore _profile;
  final AppDb _appDb;

  // One pull per child per launch; login forces it again.
  static Future<bool>? _inFlight;
  static final Set<String> _pulled = <String>{};

  // Downloads every child table first, then rewrites SQLite in one pass.
  Future<bool> run({String? childId, bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _run(childId: childId, force: force);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<bool> _run({String? childId, bool force = false}) async {
    final String id;
    try {
      id = childId ?? await _api.childId();
    } catch (_) {
      return false;
    }

    if (!force && _pulled.contains(id)) return false;

    final ChildProfile profile;
    final List<ChildPocket> pockets;
    final List<ChildGoal> goals;
    final List<Map<String, dynamic>> logs;

    try {
      final results = await Future.wait<Object?>([
        _api.get('/api/home/profile/child'),
        _api.get('/api/pocket/child/$id'),
        _api.get('/api/goals/child/$id'),
        _api.get('/api/transaction-logs/child/$id'),
      ]).timeout(const Duration(seconds: 10));

      final rawProfile = results[0];
      if (rawProfile is! Map<String, dynamic>) return false;

      profile = ChildProfile.fromJson(rawProfile);
      pockets = _pocketList(results[1]);
      goals = _goalList(results[2]);
      logs = _logList(results[3]);
    } catch (_) {
      // Offline: keep the local copy untouched.
      return false;
    }

    try {
      await _profile.storeRemote(profile);
      await _finance.replaceFromRemote(id, pockets: pockets, goals: goals);
      await _logbook.saveHydrated(id, _stateFromLogs(logs), replace: true);

      final delta = await _applyOutbox(id);
      if (delta != 0) {
        await _finance.adjustBalance(id, delta);
        await _profile.reload();
      }
      _pulled.add(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<ChildPocket> _pocketList(Object? payload) {
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChildPocket.fromJson)
        .toList();
  }

  List<ChildGoal> _goalList(Object? payload) {
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChildGoal.fromJson)
        .toList();
  }

  List<Map<String, dynamic>> _logList(Object? payload) {
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  LogbookState _stateFromLogs(List<Map<String, dynamic>> logs) {
    final days = <String, LogbookDay>{};
    for (final raw in logs) {
      final dateKey = raw['logDate'] as String? ?? '';
      if (dateKey.isEmpty) continue;

      final entries = <LogbookEntry>[];
      for (final item in (raw['transactions'] as List? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        entries.add(
          LogbookEntry(
            id: item['transactionId']?.toString() ?? '',
            type: logbookEntryTypeFromApi(item['transactionType']),
            amount: (item['amount'] as num?)?.toInt() ?? 0,
            category: logbookCategoryFromApi(item['category']),
            title: item['name'] as String? ?? '',
          ),
        );
      }

      days[dateKey] = LogbookDay(
        logId: (raw['logId'] as num?)?.toInt(),
        entries: entries,
        note: raw['summary'] as String? ?? '',
      );
    }

    return LogbookState(days: days, berries: 0, coinsEarned: 0, loaded: true);
  }

  Future<int> _applyOutbox(String childId) async {
    final items = await _outbox.pending(childId: childId, limit: 1000);
    if (items.isEmpty) return 0;

    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    final newLogs = <String>{
      for (final item in items)
        if (item.entity == 'daily_transaction_logs' && item.op == 'upsert')
          item.entityId,
    };
    final changedPockets = <String>{
      for (final item in items)
        if (item.entity == 'users_pocket' && item.op != 'delete')
          item.entityId,
    };

    var delta = 0;

    await db.transaction((txn) async {
      for (final item in items) {
        if (item.entity == 'users_pocket') {
          await _applyPocket(txn, childId, item, now);
        } else if (item.entity == 'users_goals') {
          await _applyGoal(txn, childId, item, now);
        }
      }

      for (final item in items) {
        if (item.entity != 'daily_transaction_logs') continue;
        final clientId = item.entityId.isEmpty
            ? '${item.payload['client_id'] ?? ''}'
            : item.entityId;
        if (clientId.isEmpty) continue;

        if (item.op == 'delete') {
          delta -= await _logNet(txn, clientId);
          await txn.delete(
            'transaction_entries',
            where: 'log_client_id = ?',
            whereArgs: [clientId],
          );
          await txn.delete(
            'daily_transaction_logs',
            where: 'client_id = ?',
            whereArgs: [clientId],
          );
          continue;
        }

        final dateKey = '${item.payload['log_date'] ?? ''}';
        if (dateKey.isNotEmpty) {
          // The queued day wins over the pulled row for the same date.
          final sameDate = await txn.query(
            'daily_transaction_logs',
            columns: ['client_id'],
            where: 'child_id = ? AND log_date = ? AND client_id <> ?',
            whereArgs: [childId, dateKey, clientId],
          );
          for (final row in sameDate) {
            final oldId = row['client_id'] as String? ?? '';
            if (oldId.isEmpty) continue;
            delta -= await _logNet(txn, oldId);
            await txn.delete(
              'transaction_entries',
              where: 'log_client_id = ?',
              whereArgs: [oldId],
            );
            await txn.delete(
              'daily_transaction_logs',
              where: 'client_id = ?',
              whereArgs: [oldId],
            );
          }
        }

        final row = {
          'child_id': childId,
          'log_date': dateKey,
          'summary': item.payload['summary'] as String? ?? '',
          'created_at': '${item.payload['created_at'] ?? now}',
          'updated_at': '${item.payload['updated_at'] ?? now}',
          'original_text': item.payload['original_text'],
          'ai_input_process': item.payload['ai_input_process'],
        };
        final exists = await txn.query(
          'daily_transaction_logs',
          columns: ['client_id'],
          where: 'client_id = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        if (exists.isEmpty) {
          await txn.insert('daily_transaction_logs', {
            'client_id': clientId,
            'server_id': null,
            ...row,
          });
        } else {
          await txn.update(
            'daily_transaction_logs',
            row,
            where: 'client_id = ?',
            whereArgs: [clientId],
          );
        }
      }

      for (final item in items) {
        if (item.entity != 'transaction_entries') continue;
        final logClientId = '${item.payload['log_client_id'] ?? ''}';
        if (!newLogs.contains(logClientId)) continue;

        final clientId = item.entityId.isEmpty
            ? '${item.payload['client_id'] ?? ''}'
            : item.entityId;
        if (clientId.isEmpty) continue;

        if (item.op == 'delete') {
          await txn.delete(
            'transaction_entries',
            where: 'client_id = ?',
            whereArgs: [clientId],
          );
          continue;
        }

        final type = logbookEntryTypeFromApi(item.payload['transaction_type']);
        final amount = _int(item.payload['amount']);
        final signed = type == LogbookEntryType.income ? amount : -amount;
        delta += signed;

        await txn.insert('transaction_entries', {
          'client_id': clientId,
          'log_client_id': logClientId,
          'transaction_type': logbookEntryTypeApiName(type),
          'name': '${item.payload['name'] ?? ''}',
          'amount': amount,
          'created_at': '${item.payload['created_at'] ?? now}',
          'category': item.payload['category'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final pocketId = item.payload['pocket_id'] as String?;
        if (_isRealPocket(pocketId) && !changedPockets.contains(pocketId)) {
          await txn.rawUpdate(
            'UPDATE users_pocket SET allocated_balance = allocated_balance + ? '
            'WHERE pocket_id = ? AND child_id = ?',
            [signed, pocketId, childId],
          );
        }
      }

      for (final item in items) {
        if (item.entity != SyncEngine.legacyLog) continue;
        final logId = int.tryParse(item.entityId);
        if (logId == null) continue;

        final rows = await txn.query(
          'daily_transaction_logs',
          columns: ['client_id'],
          where: 'server_id = ?',
          whereArgs: [logId],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final clientId = rows.first['client_id'] as String? ?? '';
        if (clientId.isEmpty) continue;

        final oldNet = await _logNet(txn, clientId);

        if (item.op == 'delete') {
          delta -= oldNet;
          await txn.delete(
            'transaction_entries',
            where: 'log_client_id = ?',
            whereArgs: [clientId],
          );
          await txn.delete(
            'daily_transaction_logs',
            where: 'client_id = ?',
            whereArgs: [clientId],
          );
          continue;
        }

        await txn.update(
          'daily_transaction_logs',
          {
            'summary': item.payload['summary'] as String? ?? '',
            'updated_at': now,
          },
          where: 'client_id = ?',
          whereArgs: [clientId],
        );
        await txn.delete(
          'transaction_entries',
          where: 'log_client_id = ?',
          whereArgs: [clientId],
        );

        var newNet = 0;
        for (final raw in (item.payload['transactions'] as List? ?? const [])) {
          if (raw is! Map<String, dynamic>) continue;
          final type = logbookEntryTypeFromApi(raw['transactionType']);
          final amount = _int(raw['amount']);
          newNet += type == LogbookEntryType.income ? amount : -amount;
          await txn.insert('transaction_entries', {
            'client_id': uuidV7(),
            'log_client_id': clientId,
            'transaction_type': logbookEntryTypeApiName(type),
            'name': '${raw['name'] ?? ''}',
            'amount': amount,
            'created_at': now,
            'category': '${raw['category'] ?? ''}',
          });
        }
        delta += newNet - oldNet;
      }
    });

    return delta;
  }

  Future<void> _applyPocket(
    DatabaseExecutor txn,
    String childId,
    OutboxItem item,
    String now,
  ) async {
    final pocketId = '${item.payload['pocketId'] ?? item.entityId}';
    if (pocketId.isEmpty) return;

    if (item.op == 'delete') {
      await txn.delete(
        'users_pocket',
        where: 'pocket_id = ?',
        whereArgs: [pocketId],
      );
      return;
    }

    await txn.insert('users_pocket', {
      'pocket_id': pocketId,
      'child_id': childId,
      'pocket_image': item.payload['pocketImage'],
      'pocket_name': '${item.payload['pocketName'] ?? ''}',
      'pocket_desc': item.payload['pocketDesc'],
      'allocated_balance': _int(item.payload['allocatedBalance']),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _applyGoal(
    DatabaseExecutor txn,
    String childId,
    OutboxItem item,
    String now,
  ) async {
    final goalId = '${item.payload['goalId'] ?? item.entityId}';
    if (goalId.isEmpty) return;

    if (item.op == 'delete') {
      await txn.delete(
        'users_goals',
        where: 'goal_id = ?',
        whereArgs: [goalId],
      );
      return;
    }

    await txn.insert('users_goals', {
      'goal_id': goalId,
      'child_id': childId,
      'goals_name': '${item.payload['goalsName'] ?? ''}',
      'goals_desc': item.payload['goalsDesc'],
      'allocated_balance': _int(item.payload['allocatedBalance']),
      'goal_price': _int(item.payload['goalPrice']),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _logNet(DatabaseExecutor txn, String logClientId) async {
    final rows = await txn.query(
      'transaction_entries',
      columns: ['transaction_type', 'amount'],
      where: 'log_client_id = ?',
      whereArgs: [logClientId],
    );

    var net = 0;
    for (final row in rows) {
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      net += row['transaction_type'] == 'INCOME' ? amount : -amount;
    }
    return net;
  }

  bool _isRealPocket(String? pocketId) {
    return pocketId != null &&
        pocketId.isNotEmpty &&
        pocketId != 'cash' &&
        pocketId != '-1';
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
