// SQLite mirror of the Neon logbook tables + prefs for UI-only state.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_db.dart';
import '../../core/db/uuid_v7.dart';
import 'logbook_models.dart';

class LogbookLocalStore {
  LogbookLocalStore({AppDb? db}) : _appDb = db ?? AppDb.instance;

  static const String _legacyKey = 'logbook_v3';
  static const String _legacyFallbackKey = 'logbook_v2';
  static const String _uiKey = 'logbook_ui_v1';
  static const String _migratedKey = 'logbook_migrated';
  static const String _childKey = 'logbook_child_id';

  final AppDb _appDb;

  // Cached so a write works before the first online load finishes.
  String? _childId;

  Future<void> bindChild(String childId) async {
    if (childId.isEmpty || childId == _childId) return;
    _childId = childId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_childKey, childId);
    } catch (_) {
      // A failed cache write only costs one extra lookup later.
    }
  }

  Future<LogbookState?> load() async {
    final db = await _appDb.db;
    final logRows = await db.query(
      'daily_transaction_logs',
      orderBy: 'log_date ASC',
    );
    final entryRows = await db.query(
      'transaction_entries',
      orderBy: 'created_at ASC',
    );
    final ui = await _loadUi();
    if (logRows.isEmpty && ui.isEmpty) return null;

    final entriesByLog = <String, List<LogbookEntry>>{};
    for (final row in entryRows) {
      final logClientId = row['log_client_id'] as String? ?? '';
      if (logClientId.isEmpty) continue;
      entriesByLog
          .putIfAbsent(logClientId, () => [])
          .add(_entryFromRow(row, ui['entries']));
    }

    final dayFlags = ui['days'] as Map<String, dynamic>? ?? const {};
    final days = <String, LogbookDay>{};
    for (final row in logRows) {
      final key = row['log_date'] as String? ?? '';
      final clientId = row['client_id'] as String? ?? '';
      if (key.isEmpty || clientId.isEmpty) continue;
      final flag = dayFlags[key] as Map<String, dynamic>? ?? const {};
      days[key] = LogbookDay(
        clientId: clientId,
        entries: entriesByLog[clientId] ?? const [],
        note: row['summary'] as String? ?? '',
        zeroSpend: flag['zeroSpend'] as bool? ?? false,
        completedAt: DateTime.tryParse(flag['completedAt'] as String? ?? ''),
        rewardClaimed: flag['rewardClaimed'] as bool? ?? false,
      );
    }

    return LogbookState(
      days: days,
      berries: (ui['berries'] as num?)?.toInt() ?? 0,
      coinsEarned: (ui['coinsEarned'] as num?)?.toInt() ?? 0,
      lastClaimKey: ui['lastClaimKey'] as String?,
      lastClaimCoins: (ui['lastClaimCoins'] as num?)?.toInt() ?? 0,
      lastClaimBerries: (ui['lastClaimBerries'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> save(LogbookState state) async {
    final db = await _appDb.db;
    final childId = await _childIdValue();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // The child row must exist before the mirror rows can reference it.
      await txn.insert('users', {
        'keycloak_id': childId,
        'user_type': 'CHILD',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('users_children', {
        'child_id': childId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // Keep the original timestamps and keys: a rewrite must not restamp them.
      final previousLogs = await txn.query(
        'daily_transaction_logs',
        columns: ['client_id', 'log_date', 'created_at'],
      );
      final logByDate = <String, Map<String, Object?>>{};
      for (final row in previousLogs) {
        final date = row['log_date'] as String?;
        if (date != null) logByDate[date] = row;
      }

      final previousEntries = await txn.query(
        'transaction_entries',
        columns: ['client_id', 'created_at'],
      );
      final entryByClient = <String, Map<String, Object?>>{};
      for (final row in previousEntries) {
        final client = row['client_id'] as String?;
        if (client != null && client.isNotEmpty) entryByClient[client] = row;
      }

      // Full rewrite keeps the mirror identical to the in-memory state.
      await txn.delete('transaction_entries');
      await txn.delete('daily_transaction_logs');

      for (final item in state.days.entries) {
        final day = item.value;
        final previous = logByDate[item.key];
        final logClientId =
            day.clientId.isNotEmpty
                ? day.clientId
                : (previous?['client_id'] as String? ?? uuidV7());
        final logCreated =
            previous?['created_at'] as String? ??
            day.completedAt?.toIso8601String() ??
            now;

        await txn.insert('daily_transaction_logs', {
          'client_id': logClientId,
          'child_id': childId,
          'log_date': item.key,
          'summary': day.note,
          'created_at': logCreated,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        for (final entry in day.entries) {
          final previousEntry =
              entry.id.isEmpty ? null : entryByClient[entry.id];
          final entryClientId =
              previousEntry?['client_id'] as String? ??
              (entry.id.isNotEmpty ? entry.id : uuidV7());
          final entryCreated = previousEntry?['created_at'] as String? ?? now;

          await txn.insert('transaction_entries', {
            'client_id': entryClientId,
            'log_client_id': logClientId,
            'transaction_type': logbookEntryTypeApiName(entry.type),
            'name':
                entry.title.trim().isEmpty ? entry.category.label : entry.title,
            'amount': entry.amount,
            'created_at': entryCreated,
            'category': logbookCategoryApiName(entry.category),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    await _saveUi(state);
  }

  Future<void> migrateFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_migratedKey) == '1') return;

    try {
      final raw =
          prefs.getString(_legacyKey) ?? prefs.getString(_legacyFallbackKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          await save(LogbookState.fromJson(decoded));
        }
      }
      await prefs.remove(_legacyFallbackKey);
    } catch (_) {
      // A broken legacy copy should not block a fresh logbook.
    }

    await prefs.setString(_migratedKey, '1');
  }

  Future<String> _childIdValue() async {
    final cached = _childId;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_childKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (_) {
      // Fall through to the placeholder below.
    }
    return 'local';
  }

  Future<Map<String, dynamic>> _loadUi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_uiKey);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _saveUi(LogbookState state) async {
    // Everything Neon has no column for lives here, so the tables stay 1:1.
    final ui = <String, dynamic>{
      'berries': state.berries,
      'coinsEarned': state.coinsEarned,
      'lastClaimKey': state.lastClaimKey,
      'lastClaimCoins': state.lastClaimCoins,
      'lastClaimBerries': state.lastClaimBerries,
      'days': {
        for (final item in state.days.entries)
          item.key: {
            'zeroSpend': item.value.zeroSpend,
            'rewardClaimed': item.value.rewardClaimed,
            'completedAt': item.value.completedAt?.toIso8601String(),
          },
      },
      'entries': {
        for (final item in state.days.entries)
          for (final entry in item.value.entries)
            if (entry.id.isNotEmpty && entry.pocketId != null)
              entry.id: {
                'pocketId': entry.pocketId,
                'pocketName': entry.pocketName,
              },
      },
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_uiKey, jsonEncode(ui));
    } catch (_) {
      // Local caching is a fallback; a failed write must not break logging.
    }
  }

  LogbookEntry _entryFromRow(
    Map<String, Object?> row,
    Map<String, dynamic>? pockets,
  ) {
    final clientId = row['client_id'] as String? ?? '';
    final pocket = clientId.isEmpty ? null : pockets?[clientId];
    final pocketMeta = pocket is Map<String, dynamic> ? pocket : null;

    return LogbookEntry(
      id: clientId,
      type: logbookEntryTypeFromApi(row['transaction_type']),
      amount: row['amount'] as int? ?? 0,
      category: logbookCategoryFromApi(row['category']),
      pocketId: (pocketMeta?['pocketId'] as num?)?.toInt(),
      pocketName: pocketMeta?['pocketName'] as String? ?? '',
      title: row['name'] as String? ?? '',
    );
  }
}
