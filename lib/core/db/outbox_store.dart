// Queue of writes that still need to reach the backend.

import 'dart:convert';
import 'dart:math';

import 'app_db.dart';

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.attempts,
    required this.createdAt,
  });

  final String id;
  final String entity;
  final String entityId;
  final String op;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime createdAt;
}

class OutboxStore {
  OutboxStore({AppDb? db}) : _appDb = db ?? AppDb.instance;

  static const int _maxAttempts = 5;
  static const List<int> _backoffMinutes = [1, 5, 15, 60, 180];

  final AppDb _appDb;
  final Random _random = Random();

  /// Records a write before it is sent. Returns the queue row id.
  Future<String> enqueue({
    required String entity,
    required String entityId,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _appDb.db;
    final id = _newId();
    await db.insert('outbox', {
      'id': id,
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> markSent(String id) async {
    final db = await _appDb.db;
    await db.update(
      'outbox',
      {
        'status': 'sent',
        'sent_at': DateTime.now().millisecondsSinceEpoch,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Keeps the row pending with a growing delay, or marks it failed.
  Future<void> markFailed(
    String id,
    Object error, {
    Map<String, dynamic>? payload,
  }) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'outbox',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final attempts =
        ((rows.isEmpty ? 0 : rows.first['attempts'] as int? ?? 0) + 1);
    final delayIndex = (attempts - 1).clamp(0, _backoffMinutes.length - 1);
    final retryAt =
        DateTime.now()
            .add(Duration(minutes: _backoffMinutes[delayIndex]))
            .millisecondsSinceEpoch;

    await db.update(
      'outbox',
      {
        'status': attempts >= _maxAttempts ? 'failed' : 'pending',
        'attempts': attempts,
        'next_try_at': retryAt,
        'last_error': error.toString(),
        if (payload != null) 'payload': jsonEncode(payload),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<OutboxItem>> pending({int limit = 50}) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'outbox',
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> pendingCount() async {
    final db = await _appDb.db;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM outbox WHERE status = 'pending'",
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  OutboxItem _fromRow(Map<String, Object?> row) {
    final raw = row['payload'] as String?;
    Map<String, dynamic> payload = const {};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) payload = decoded;
    }
    final created = row['created_at'] as int? ?? 0;

    return OutboxItem(
      id: row['id'] as String? ?? '',
      entity: row['entity'] as String? ?? '',
      entityId: row['entity_id'] as String? ?? '',
      op: row['op'] as String? ?? '',
      payload: payload,
      attempts: row['attempts'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created),
    );
  }

  String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(1 << 32).toRadixString(36);
    return '$stamp-$salt';
  }
}
