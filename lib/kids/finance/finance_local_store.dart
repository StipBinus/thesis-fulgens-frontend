// SQLite store for pockets, goals and the child balance.
//
// Rows are keyed by device UUIDs; every write also queues an outbox row so the
// backend sync can replay it later.

import 'package:sqflite/sqflite.dart';

import '../../core/db/app_db.dart';
import '../../core/db/outbox_store.dart';
import '../../core/db/uuid_v7.dart';
import 'finance_models.dart';

class FinanceLocalStore {
  FinanceLocalStore({AppDb? db, OutboxStore? outbox})
    : _appDb = db ?? AppDb.instance,
      _outbox = outbox ?? OutboxStore();

  final AppDb _appDb;
  final OutboxStore _outbox;

  Future<int> childBalance(String childId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'users_children',
      columns: ['balance'],
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['balance'] as num?)?.toInt() ?? 0;
  }

  Future<void> saveBalance(String childId, int balance) async {
    final db = await _appDb.db;
    await _ensureChild(db, childId);
    await db.update(
      'users_children',
      {'balance': balance},
      where: 'child_id = ?',
      whereArgs: [childId],
    );
  }

  // Pockets

  Future<List<ChildPocket>> fetchPockets(String childId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'users_pocket',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_at ASC',
    );
    final balance = (await childBalance(childId)).toInt();
    return [for (final row in rows) _pocketFromRow(row, balance)];
  }

  Future<ChildPocket> createPocket({
    required String childId,
    required String name,
    String? description,
    String? image,
    int allocatedBalance = 0,
  }) async {
    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    final pocket = ChildPocket(
      pocketId: uuidV7(),
      childId: childId,
      pocketImage: image,
      pocketName: name.trim(),
      pocketDesc: _blankToNull(description),
      userBalance: (await childBalance(childId)).toInt(),
      allocatedBalance: allocatedBalance,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _ensureChild(db, childId);
    await db.insert('users_pocket', {
      'pocket_id': pocket.pocketId,
      'child_id': childId,
      'pocket_image': pocket.pocketImage,
      'pocket_name': pocket.pocketName,
      'pocket_desc': pocket.pocketDesc,
      'allocated_balance': allocatedBalance,
      'created_at': now,
      'updated_at': now,
    });
    await _queue('users_pocket', pocket.pocketId, 'upsert', _pocketPayload(pocket));
    return pocket;
  }

  Future<ChildPocket> updatePocket({
    required String pocketId,
    required String childId,
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  }) async {
    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'users_pocket',
      {
        'pocket_image': _blankToNull(image),
        'pocket_name': name.trim(),
        'pocket_desc': _blankToNull(description),
        'allocated_balance': allocatedBalance,
        'updated_at': now,
      },
      where: 'pocket_id = ?',
      whereArgs: [pocketId],
    );

    final pockets = await fetchPockets(childId);
    final pocket = pockets.firstWhere(
      (item) => item.pocketId == pocketId,
      orElse: () => pockets.first,
    );
    await _queue('users_pocket', pocketId, 'upsert', _pocketPayload(pocket));
    return pocket;
  }

  Future<void> deletePocket(String pocketId) async {
    final db = await _appDb.db;
    await db.delete(
      'users_pocket',
      where: 'pocket_id = ?',
      whereArgs: [pocketId],
    );
    await _queue('users_pocket', pocketId, 'delete', {'pocketId': pocketId});
  }

  // Replaces the phone pockets and goals with the backend rows.
  Future<void> replaceFromRemote(
    String childId, {
    required List<ChildPocket> pockets,
    required List<ChildGoal> goals,
  }) async {
    final db = await _appDb.db;
    await _ensureChild(db, childId);
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'users_pocket',
        where: 'child_id = ?',
        whereArgs: [childId],
      );
      await txn.delete(
        'users_goals',
        where: 'child_id = ?',
        whereArgs: [childId],
      );

      for (final pocket in pockets) {
        await txn.insert('users_pocket', {
          'pocket_id': pocket.pocketId,
          'child_id': childId,
          'pocket_image': pocket.pocketImage,
          'pocket_name': pocket.pocketName,
          'pocket_desc': pocket.pocketDesc,
          'allocated_balance': pocket.allocatedBalance,
          'created_at': pocket.createdAt?.toIso8601String() ?? now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final goal in goals) {
        await txn.insert('users_goals', {
          'goal_id': goal.goalId,
          'child_id': childId,
          'goals_name': goal.goalsName,
          'goals_desc': goal.goalsDesc,
          'allocated_balance': goal.allocatedBalance,
          'goal_price': goal.goalPrice,
          'created_at': goal.createdAt?.toIso8601String() ?? now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // Balance change from a logbook entry.
  Future<void> adjustBalance(String childId, int delta) async {
    if (delta == 0) return;
    final db = await _appDb.db;
    await _ensureChild(db, childId);
    await db.rawUpdate(
      'UPDATE users_children SET balance = balance + ? WHERE child_id = ?',
      [delta, childId],
    );
  }

  // Pocket change from a logbook entry; the new row is queued for sync.
  Future<void> adjustPocket(
    String childId,
    String pocketId,
    int delta,
  ) async {
    if (delta == 0) return;
    final db = await _appDb.db;
    final rows = await db.query(
      'users_pocket',
      where: 'pocket_id = ? AND child_id = ?',
      whereArgs: [pocketId, childId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final allocated =
        ((row['allocated_balance'] as num?)?.toInt() ?? 0) + delta;
    await db.update(
      'users_pocket',
      {
        'allocated_balance': allocated,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'pocket_id = ?',
      whereArgs: [pocketId],
    );
    await _queue('users_pocket', pocketId, 'upsert', {
      'pocketId': pocketId,
      'childId': childId,
      'pocketImage': row['pocket_image'],
      'pocketName': row['pocket_name'],
      'pocketDesc': row['pocket_desc'],
      'allocatedBalance': allocated,
    });
  }

  // Goals

  Future<List<ChildGoal>> fetchGoals(String childId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'users_goals',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'created_at ASC',
    );
    final balance = (await childBalance(childId)).toInt();
    return [for (final row in rows) _goalFromRow(row, balance)];
  }

  Future<ChildGoal> createGoal({
    required String childId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    final goal = ChildGoal(
      goalId: uuidV7(),
      childId: childId,
      goalsName: name.trim(),
      goalsDesc: _blankToNull(description),
      userBalance: (await childBalance(childId)).toInt(),
      allocatedBalance: allocatedBalance,
      goalPrice: goalPrice,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _ensureChild(db, childId);
    await db.insert('users_goals', {
      'goal_id': goal.goalId,
      'child_id': childId,
      'goals_name': goal.goalsName,
      'goals_desc': goal.goalsDesc,
      'allocated_balance': allocatedBalance,
      'goal_price': goalPrice,
      'created_at': now,
      'updated_at': now,
    });
    await _queue('users_goals', goal.goalId, 'upsert', _goalPayload(goal));
    return goal;
  }

  Future<ChildGoal> updateGoal({
    required String goalId,
    required String childId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'users_goals',
      {
        'goals_name': name.trim(),
        'goals_desc': _blankToNull(description),
        'allocated_balance': allocatedBalance,
        'goal_price': goalPrice,
        'updated_at': now,
      },
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

    final goals = await fetchGoals(childId);
    final goal = goals.firstWhere(
      (item) => item.goalId == goalId,
      orElse: () => goals.first,
    );
    await _queue('users_goals', goalId, 'upsert', _goalPayload(goal));
    return goal;
  }

  Future<void> deleteGoal(String goalId) async {
    final db = await _appDb.db;
    await db.delete('users_goals', where: 'goal_id = ?', whereArgs: [goalId]);
    await _queue('users_goals', goalId, 'delete', {'goalId': goalId});
  }

  // Seed import from the backend, used once when the tables are empty.

  Future<bool> isEmpty(String childId) async {
    final db = await _appDb.db;
    final pockets = await db.query(
      'users_pocket',
      columns: ['pocket_id'],
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    final goals = await db.query(
      'users_goals',
      columns: ['goal_id'],
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return pockets.isEmpty && goals.isEmpty;
  }

  Future<void> importRow({
    required String childId,
    ChildPocket? pocket,
    ChildGoal? goal,
  }) async {
    final db = await _appDb.db;
    final now = DateTime.now().toIso8601String();
    await _ensureChild(db, childId);

    if (pocket != null) {
      await db.insert('users_pocket', {
        'pocket_id': uuidV7(),
        'child_id': childId,
        'pocket_image': pocket.pocketImage,
        'pocket_name': pocket.pocketName,
        'pocket_desc': pocket.pocketDesc,
        'allocated_balance': pocket.allocatedBalance,
        'created_at': pocket.createdAt?.toIso8601String() ?? now,
        'updated_at': now,
      });
    }

    if (goal != null) {
      await db.insert('users_goals', {
        'goal_id': uuidV7(),
        'child_id': childId,
        'goals_name': goal.goalsName,
        'goals_desc': goal.goalsDesc,
        'allocated_balance': goal.allocatedBalance,
        'goal_price': goal.goalPrice,
        'created_at': goal.createdAt?.toIso8601String() ?? now,
        'updated_at': now,
      });
    }
  }

  // Helpers

  Future<void> _ensureChild(Database db, String childId) async {
    await db.insert('users', {
      'keycloak_id': childId,
      'user_type': 'CHILD',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users_children', {
      'child_id': childId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _queue(
    String entity,
    String entityId,
    String op,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _outbox.enqueue(
        entity: entity,
        entityId: entityId,
        op: op,
        payload: payload,
      );
    } catch (_) {
      // A failed queue write must not block the local save.
    }
  }

  Map<String, dynamic> _pocketPayload(ChildPocket pocket) => {
    'pocketId': pocket.pocketId,
    'childId': pocket.childId,
    'pocketImage': pocket.pocketImage,
    'pocketName': pocket.pocketName,
    'pocketDesc': pocket.pocketDesc,
    'allocatedBalance': pocket.allocatedBalance,
  };

  Map<String, dynamic> _goalPayload(ChildGoal goal) => {
    'goalId': goal.goalId,
    'childId': goal.childId,
    'goalsName': goal.goalsName,
    'goalsDesc': goal.goalsDesc,
    'allocatedBalance': goal.allocatedBalance,
    'goalPrice': goal.goalPrice,
  };

  ChildPocket _pocketFromRow(Map<String, Object?> row, int balance) {
    return ChildPocket(
      pocketId: row['pocket_id'] as String? ?? '',
      childId: row['child_id'] as String? ?? '',
      pocketImage: row['pocket_image'] as String?,
      pocketName: row['pocket_name'] as String? ?? '',
      pocketDesc: row['pocket_desc'] as String?,
      userBalance: balance,
      allocatedBalance: (row['allocated_balance'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    );
  }

  ChildGoal _goalFromRow(Map<String, Object?> row, int balance) {
    return ChildGoal(
      goalId: row['goal_id'] as String? ?? '',
      childId: row['child_id'] as String? ?? '',
      goalsName: row['goals_name'] as String? ?? '',
      goalsDesc: row['goals_desc'] as String?,
      userBalance: balance,
      allocatedBalance: (row['allocated_balance'] as num?)?.toInt() ?? 0,
      goalPrice: (row['goal_price'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    );
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
