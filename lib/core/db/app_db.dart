// Local mirror of the Neon tables. Rows are keyed by device UUIDs, so no
// server identity is stored here; the outbox carries pending writes instead.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'uuid_v7.dart';

class AppDb {
  AppDb._();

  static final AppDb instance = AppDb._();

  static const int schemaVersion = 9;
  static const String fileName = 'fulgens.db';

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      p.join(directory, fileName),
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) => _createSchema(db);

  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      // Phase 1 dev reset: rebuild the mirror from the source tables.
      for (final table in _dropOrder) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
      await _createSchema(db);
      return;
    }

    if (from < 3) {
      // v1 leftovers; the mirror tables already match Neon.
      for (final table in _legacyTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
    }

    if (from < 4) {
      await _upgradeLogbookToUuid(db);
    }

    if (from < 5) {
      await _upgradeDropSyncColumns(db);
    }

    if (from < 6) {
      await _upgradeFinanceToUuid(db);
    }

    if (from < 7) {
      await _upgradeSyncToV7(db);
    }

    // v8: phone-only goal icons
    if (from < 8) {
      await db.execute(_createGoalIconTable);
    }

    // v9: phone-only pocket/goal history
    if (from < 9) {
      await db.execute(_createActivityTable);
      await db.execute(_createActivityIndex);
    }
  }

  // Pocket/goal money history, never synced
  static const String _createActivityTable = '''
    CREATE TABLE IF NOT EXISTS money_activity (
      id TEXT PRIMARY KEY,
      child_id TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      label TEXT NOT NULL,
      amount INTEGER NOT NULL,
      incoming INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  static const String _createActivityIndex =
      'CREATE INDEX IF NOT EXISTS idx_activity_target '
      'ON money_activity(target_id, created_at)';

  // Goal icons: own table so backend sync never wipes them
  static const String _createGoalIconTable = '''
    CREATE TABLE IF NOT EXISTS goal_icons (
      goal_id TEXT PRIMARY KEY,
      image TEXT NOT NULL
    )
  ''';

  // Pulled rows keep the Neon id; the outbox learns which child it belongs to.
  Future<void> _upgradeSyncToV7(Database db) async {
    await _addColumnIfMissing(db, 'daily_transaction_logs', 'server_id', 'INTEGER');
    await _addColumnIfMissing(db, 'outbox', 'child_id', 'TEXT');
    await db.execute(_createSyncStateTable);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outbox_child ON outbox(child_id, status)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  // Pockets and goals move onto device UUIDs, matching the logbook tables.
  Future<void> _upgradeFinanceToUuid(Database db) async {
    final oldPockets = await db.query('users_pocket');
    final oldGoals = await db.query('users_goals');

    await db.execute('DROP TABLE IF EXISTS users_pocket');
    await db.execute('DROP TABLE IF EXISTS users_goals');
    await db.execute(_createPocketTable);
    await db.execute(_createGoalTable);
    await _createIndexes(db);

    for (final row in oldPockets) {
      await db.insert('users_pocket', {
        'pocket_id': _uuidFrom(row['pocket_id']),
        'child_id': row['child_id'],
        'pocket_image': row['pocket_image'],
        'pocket_name': row['pocket_name'],
        'pocket_desc': row['pocket_desc'],
        'allocated_balance': row['allocated_balance'] ?? 0,
        'created_at': row['created_at'] ?? '',
        'updated_at': row['updated_at'] ?? '',
      });
    }

    for (final row in oldGoals) {
      await db.insert('users_goals', {
        'goal_id': _uuidFrom(row['goal_id']),
        'child_id': row['child_id'],
        'goals_name': row['goals_name'],
        'goals_desc': row['goals_desc'],
        'allocated_balance': row['allocated_balance'] ?? 0,
        'goal_price': row['goal_price'] ?? 0,
        'created_at': row['created_at'] ?? '',
        'updated_at': row['updated_at'] ?? '',
      });
    }
  }

  String _uuidFrom(Object? value) {
    final text = value is String ? value : '';
    return text.length >= 32 ? text : uuidV7();
  }

  // Rows move from the server's bigint key to a device-generated UUID.
  Future<void> _upgradeLogbookToUuid(Database db) async {
    final oldLogs = await db.query('daily_transaction_logs');
    final oldEntries = await db.query('transaction_entries');

    await db.execute(
      'ALTER TABLE transaction_entries RENAME TO transaction_entries_v3',
    );
    await db.execute(
      'ALTER TABLE daily_transaction_logs RENAME TO daily_transaction_logs_v3',
    );
    await db.execute(_createLogsTableV4);
    await db.execute(_createEntriesTableV4);

    final logKeys = <int, String>{};
    for (final row in oldLogs) {
      final oldId = row['id'] as int?;
      final clientId = _text(row['client_id']) ?? uuidV7();
      if (oldId != null) logKeys[oldId] = clientId;
      await db.insert('daily_transaction_logs', {
        'client_id': clientId,
        'server_id': oldId != null && oldId > 0 ? oldId : null,
        'child_id': row['child_id'],
        'log_date': row['log_date'],
        'summary': row['summary'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
        'original_text': row['original_text'],
        'ai_input_process': row['ai_input_process'],
        'deleted_at': row['deleted_at'],
        'dirty': row['dirty'] ?? 0,
      });
    }

    for (final row in oldEntries) {
      final clientId = _text(row['client_id']) ?? uuidV7();
      final oldId = row['id'] as int?;
      final logClientId = logKeys[row['log_id']];
      if (logClientId == null) continue;
      await db.insert('transaction_entries', {
        'client_id': clientId,
        // Microsecond ids were never server ids; only keep small ones.
        'server_id':
            oldId != null && oldId > 0 && oldId < 1000000000000 ? oldId : null,
        'log_client_id': logClientId,
        'transaction_type': row['transaction_type'],
        'name': row['name'],
        'amount': row['amount'],
        'created_at': row['created_at'],
        'category': row['category'],
        'deleted_at': row['deleted_at'],
        'dirty': row['dirty'] ?? 0,
      });
    }

    await db.execute('DROP TABLE transaction_entries_v3');
    await db.execute('DROP TABLE daily_transaction_logs_v3');
  }

  // The UUID is the only identity now; pending work lives in the outbox.
  Future<void> _upgradeDropSyncColumns(Database db) async {
    await db.execute('PRAGMA legacy_alter_table = ON');

    await _rebuildTable(db, 'transaction_entries', _createEntriesTable);
    await _rebuildTable(db, 'daily_transaction_logs', _createLogsTable);
    await _rebuildTable(db, 'users_children', _createChildrenTable);
    await _rebuildTable(db, 'daily_task_answer', _createTaskAnswerTable);
    await _rebuildTable(db, 'daily_task', _createTaskTable);
    await _rebuildTable(db, 'child_task', _createChildTaskTable);
    await _rebuildTable(db, 'parent_task_plan', _createTaskPlanTable);
    await _rebuildTable(db, 'users_pocket', _createPocketTableLegacy);
    await _rebuildTable(db, 'users_goals', _createGoalTableLegacy);

    await _createIndexes(db);
    await db.execute('PRAGMA legacy_alter_table = OFF');
  }

  // Rebuild keeps the indexes' names, so they are recreated afterwards.
  Future<void> _rebuildTable(
    Database db,
    String table,
    String createSql,
  ) async {
    final temp = '${table}_v4';
    await db.execute('ALTER TABLE $table RENAME TO $temp');
    await db.execute(createSql);

    final oldColumns =
        (await db.rawQuery(
          'PRAGMA table_info($temp)',
        )).map((row) => row['name'] as String).toSet();
    final newColumns =
        (await db.rawQuery(
          'PRAGMA table_info($table)',
        )).map((row) => row['name'] as String).toList();
    final shared = newColumns.where(oldColumns.contains).join(', ');

    await db.execute('INSERT INTO $table ($shared) SELECT $shared FROM $temp');
    await db.execute('DROP TABLE $temp');
  }

  String? _text(Object? value) {
    final text = value as String?;
    return text == null || text.isEmpty ? null : text;
  }

  // One row per child once the first download has happened.
  static const String _createSyncStateTable = '''
    CREATE TABLE IF NOT EXISTS sync_state (
      child_id TEXT PRIMARY KEY,
      hydrated_at TEXT NOT NULL
    )
  ''';

  static const String _createLogsTable = '''
    CREATE TABLE daily_transaction_logs (
      client_id TEXT PRIMARY KEY,
      server_id INTEGER,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      log_date TEXT NOT NULL,
      summary TEXT,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      original_text TEXT,
      ai_input_process TEXT
    )
  ''';

  static const String _createEntriesTable = '''
    CREATE TABLE transaction_entries (
      client_id TEXT PRIMARY KEY,
      log_client_id TEXT NOT NULL REFERENCES daily_transaction_logs(client_id),
      transaction_type TEXT NOT NULL,
      name TEXT NOT NULL,
      amount INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT '',
      category TEXT
    )
  ''';

  // The v4 shape, kept only so the v3 -> v4 step can run before v5 trims it.
  static const String _createLogsTableV4 = '''
    CREATE TABLE daily_transaction_logs (
      client_id TEXT PRIMARY KEY,
      server_id INTEGER UNIQUE,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      log_date TEXT NOT NULL,
      summary TEXT,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      original_text TEXT,
      ai_input_process TEXT,
      deleted_at TEXT,
      dirty INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createEntriesTableV4 = '''
    CREATE TABLE transaction_entries (
      client_id TEXT PRIMARY KEY,
      server_id INTEGER UNIQUE,
      log_client_id TEXT NOT NULL REFERENCES daily_transaction_logs(client_id),
      transaction_type TEXT NOT NULL,
      name TEXT NOT NULL,
      amount INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT '',
      category TEXT,
      deleted_at TEXT,
      dirty INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createChildrenTable = '''
    CREATE TABLE users_children (
      child_id TEXT PRIMARY KEY REFERENCES users(keycloak_id),
      game_currency INTEGER NOT NULL DEFAULT 0,
      grade TEXT NOT NULL DEFAULT '',
      balance INTEGER NOT NULL DEFAULT 0,
      parent_currency INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 1,
      xp INTEGER NOT NULL DEFAULT 0,
      streak INTEGER NOT NULL DEFAULT 0,
      longest_streak INTEGER NOT NULL DEFAULT 0,
      birth_date TEXT,
      profile_picture TEXT,
      name TEXT,
      client_id TEXT UNIQUE
    )
  ''';

  // Device-generated ids: the same value is used locally and later on the server.
  static const String _createPocketTable = '''
    CREATE TABLE users_pocket (
      pocket_id TEXT PRIMARY KEY,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      pocket_image TEXT,
      pocket_name TEXT NOT NULL,
      pocket_desc TEXT,
      allocated_balance INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const String _createGoalTable = '''
    CREATE TABLE users_goals (
      goal_id TEXT PRIMARY KEY,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      goals_name TEXT NOT NULL,
      goals_desc TEXT,
      allocated_balance INTEGER NOT NULL DEFAULT 0,
      goal_price INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT ''
    )
  ''';

  // The v5 shape, kept only so the v4 -> v5 step can run before v6 swaps ids.
  static const String _createPocketTableLegacy = '''
    CREATE TABLE users_pocket (
      pocket_id INTEGER PRIMARY KEY,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      pocket_image TEXT,
      pocket_name TEXT NOT NULL,
      pocket_desc TEXT,
      allocated_balance INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      client_id TEXT UNIQUE
    )
  ''';

  static const String _createGoalTableLegacy = '''
    CREATE TABLE users_goals (
      goal_id INTEGER PRIMARY KEY,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      goals_name TEXT NOT NULL,
      goals_desc TEXT,
      allocated_balance INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      goal_price INTEGER NOT NULL DEFAULT 0,
      client_id TEXT UNIQUE
    )
  ''';

  static const String _createTaskTable = '''
    CREATE TABLE daily_task (
      task_id INTEGER PRIMARY KEY,
      child_id TEXT NOT NULL REFERENCES users_children(child_id),
      task_date TEXT NOT NULL,
      question_type TEXT NOT NULL,
      question TEXT NOT NULL,
      reward INTEGER,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      pop_quiz_options TEXT,
      client_id TEXT UNIQUE
    )
  ''';

  static const String _createTaskAnswerTable = '''
    CREATE TABLE daily_task_answer (
      answer_id INTEGER PRIMARY KEY,
      task_id INTEGER NOT NULL REFERENCES daily_task(task_id),
      asnwer TEXT,
      selected_answer TEXT,
      submitted_at TEXT NOT NULL DEFAULT '',
      client_id TEXT UNIQUE
    )
  ''';

  static const String _createTaskPlanTable = '''
    CREATE TABLE parent_task_plan (
      plan_id INTEGER PRIMARY KEY,
      parent_id TEXT NOT NULL,
      child_id TEXT NOT NULL,
      goal TEXT NOT NULL,
      focus_area TEXT NOT NULL,
      report_start_date TEXT,
      report_end_date TEXT,
      status TEXT,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      client_id TEXT UNIQUE
    )
  ''';

  static const String _createChildTaskTable = '''
    CREATE TABLE child_task (
      task_id INTEGER PRIMARY KEY,
      plan_id INTEGER NOT NULL REFERENCES parent_task_plan(plan_id),
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      reward INTEGER,
      due_date TEXT,
      status TEXT NOT NULL,
      submitted_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      client_id TEXT UNIQUE
    )
  ''';

  static const List<String> _legacyTables = [
    'days',
    'entries',
    'profile',
    'pockets',
    'goals',
    'meta',
  ];

  static const List<String> _dropOrder = [
    ..._legacyTables,
    'transaction_entries',
    'daily_transaction_logs',
    'users_goals',
    'users_pocket',
    'user_children_mascot_wardrobe',
    'mascot_wardrobe',
    'daily_task_answer',
    'daily_task',
    'child_task',
    'parent_task_plan',
    'parent_child',
    'users_children',
    'users_parent',
    'users',
    'outbox',
    'goal_icons',
    'money_activity',
  ];

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_logs_child '
      'ON daily_transaction_logs(child_id, log_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_log '
      'ON transaction_entries(log_client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pockets_child ON users_pocket(child_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goals_child ON users_goals(child_id)',
    );
  }

  Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE outbox (
        id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        child_id TEXT,
        op TEXT NOT NULL,
        payload TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_try_at INTEGER,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        sent_at INTEGER
      )
    ''');

    batch.execute(_createSyncStateTable);
    batch.execute(_createGoalIconTable);
    batch.execute(_createActivityTable);
    batch.execute(_createActivityIndex);

    batch.execute('''
      CREATE TABLE users (
        keycloak_id TEXT PRIMARY KEY,
        user_type TEXT NOT NULL,
        username TEXT,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        birth_date TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE users_parent (
        parent_id TEXT PRIMARY KEY REFERENCES users(keycloak_id),
        username TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ''');

    batch.execute(_createChildrenTable);

    batch.execute('''
      CREATE TABLE parent_child (
        parent_id TEXT NOT NULL REFERENCES users_parent(parent_id),
        child_id TEXT NOT NULL REFERENCES users_children(child_id),
        PRIMARY KEY (parent_id, child_id)
      )
    ''');

    batch.execute(_createTaskPlanTable);

    batch.execute(_createChildTaskTable);

    batch.execute(_createTaskTable);

    batch.execute(_createTaskAnswerTable);

    batch.execute(_createLogsTable);

    batch.execute(_createEntriesTable);

    batch.execute(_createPocketTable);

    batch.execute(_createGoalTable);

    batch.execute('''
      CREATE TABLE mascot_wardrobe (
        wardrobe_id TEXT PRIMARY KEY,
        wardrobe_content TEXT NOT NULL,
        wardrobe_price INTEGER NOT NULL,
        wardrobe_rarity TEXT NOT NULL,
        wardrobe_name TEXT NOT NULL,
        wardrobe_type TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE user_children_mascot_wardrobe (
        child_id TEXT NOT NULL REFERENCES users_children(child_id),
        wardrobe_id TEXT NOT NULL REFERENCES mascot_wardrobe(wardrobe_id),
        PRIMARY KEY (child_id, wardrobe_id)
      )
    ''');

    await batch.commit(noResult: true);

    await _createIndexes(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outbox_queue ON outbox(status, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outbox_child ON outbox(child_id, status)',
    );
  }
}
