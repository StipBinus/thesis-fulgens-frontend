// Local mirror of the Neon tables. Rows are keyed by device UUIDs, so no
// server identity is stored here; the outbox carries pending writes instead.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'uuid_v7.dart';

class AppDb {
  AppDb._();

  static final AppDb instance = AppDb._();

  static const int schemaVersion = 5;
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
    await _rebuildTable(db, 'users_pocket', _createPocketTable);
    await _rebuildTable(db, 'users_goals', _createGoalTable);

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

  static const String _createLogsTable = '''
    CREATE TABLE daily_transaction_logs (
      client_id TEXT PRIMARY KEY,
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

  static const String _createPocketTable = '''
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

  static const String _createGoalTable = '''
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
  }
}
