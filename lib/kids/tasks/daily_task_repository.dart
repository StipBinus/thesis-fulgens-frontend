import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_db.dart';
import '../../core/db/local_data.dart';
import '../../core/db/outbox_store.dart';
import '../../core/db/uuid_v7.dart';
import '../../core/sync/sync_scheduler.dart';
import '../finance/finance_api.dart';
import '../finance/finance_repository.dart';
import 'daily_task.dart';

/// Today's daily task (only REFLECTION for now), local-first.
///
/// - Screens read SQLite ([todayReflection]).
/// - [ensureToday] is the lazy generation: when SQLite has no reflection for
///   today and the phone is online, it calls `POST /api/daily-task/today`.
///   The backend returns today's task, generating and saving it to
///   `daily_task` only when none exists yet. The result is stored locally.
/// - [submitReflection] saves the answer locally and queues a
///   `daily_task_answer` upsert in the outbox for `/api/sync`.
class DailyTaskRepository {
  DailyTaskRepository({
    FinanceApi? api,
    AppDb? db,
    OutboxStore? outbox,
    ChildIdentity? identity,
  }) : _api = api ?? FinanceApi(),
       _appDb = db ?? AppDb.instance,
       _outbox = outbox ?? OutboxStore(),
       _identity = identity ?? ChildIdentity();

  static const String reflection = 'REFLECTION';
  static const String answerEntity = 'daily_task_answer';

  // A failed generation (AI down, server error) waits before trying again,
  // so every screen open does not hit the AI.
  static const Duration _retryGap = Duration(minutes: 2);

  static Future<DailyTask?>? _inFlight;
  static DateTime? _lastFailure;

  final FinanceApi _api;
  final AppDb _appDb;
  final OutboxStore _outbox;
  final ChildIdentity _identity;

  /// Today's reflection from SQLite, or null when there is none yet.
  Future<DailyTask?> todayReflection() async {
    final childId = await _childIdOrNull();
    if (childId == null) return null;
    return _localToday(childId);
  }

  /// The answer already given for [taskId] on this phone, if any.
  Future<String?> answerFor(int taskId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'daily_task_answer',
      columns: ['asnwer'],
      where: 'task_id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['asnwer'] as String?;
  }

  /// Lazy generation; safe to call on every home/tasks page open.
  Future<DailyTask?> ensureToday() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _ensure();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<DailyTask?> _ensure() async {
    final childId = await _childIdOrNull();
    if (childId == null) return null;

    final local = await _localToday(childId);
    if (local != null) return local;

    if (!await _online()) return null;
    final failed = _lastFailure;
    if (failed != null && DateTime.now().difference(failed) < _retryGap) {
      return null;
    }

    try {
      final payload = await _api
          .post('/api/daily-task/today', const <String, dynamic>{})
          .timeout(const Duration(seconds: 45));
      if (payload is! Map<String, dynamic>) return null;

      final task = DailyTask.fromJson(payload);
      if (task.taskId == 0 || task.question.isEmpty) return null;

      final db = await _appDb.db;
      await db.transaction((txn) => storeTasks(txn, childId, [payload]));
      _lastFailure = null;
      LocalData.instance.bump();
      return await _localToday(childId);
    } catch (_) {
      _lastFailure = DateTime.now();
      return null;
    }
  }

  /// Asks the backend for this child's tasks so a parent's approval
  /// (WAITING -> COMPLETED) reaches the phone. `GET /api/daily-task/me`:
  /// the server reads the child id from the Bearer token, nothing is sent.
  /// Offline or on error the local copy is kept.
  Future<void> refreshStatuses() async {
    final childId = await _childIdOrNull();
    if (childId == null || !await _online()) return;
    try {
      final payload = await _api
          .get('/api/daily-task/me')
          .timeout(const Duration(seconds: 10));
      if (payload is! List) return;
      final tasks = payload.whereType<Map<String, dynamic>>().toList();
      if (tasks.isEmpty) return;
      final db = await _appDb.db;
      await db.transaction((txn) => storeTasks(txn, childId, tasks));
      LocalData.instance.bump();
    } catch (_) {
      // Keep the phone copy.
    }
  }

  /// Saves the child's reflection answer and queues it for `/api/sync`.
  Future<void> submitReflection(DailyTask task, String text) async {
    final answer = text.trim();
    if (answer.isEmpty) return;

    final childId = await _childIdOrNull();
    final db = await _appDb.db;
    final clientId = uuidV7();
    final submittedAt = DateTime.now().toIso8601String();
    var inserted = false;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'daily_task_answer',
        columns: ['answer_id'],
        where: 'task_id = ?',
        whereArgs: [task.taskId],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      await txn.insert('daily_task_answer', {
        'task_id': task.taskId,
        'asnwer': answer,
        // Reflections have no options, so nothing is selected.
        'selected_answer': null,
        'submitted_at': submittedAt,
        'client_id': clientId,
      });
      await txn.update(
        'daily_task',
        // Answered; the parent still has to approve it.
        {'status': 'WAITING', 'updated_at': submittedAt},
        where: 'task_id = ?',
        whereArgs: [task.taskId],
      );
      inserted = true;
    });

    if (!inserted) return;

    await _outbox.enqueue(
      entity: answerEntity,
      entityId: clientId,
      op: 'upsert',
      childId: childId,
      payload: {
        'client_id': clientId,
        'task_id': task.taskId,
        'answer': answer,
        'selected_answer': null,
        'submitted_at': submittedAt,
      },
    );
    LocalData.instance.bump();
    unawaited(SyncScheduler.instance.request());
  }

  /// Upserts backend daily tasks (DailyTaskResponse JSON) into SQLite.
  ///
  /// The server status wins (so a parent's approval shows up as COMPLETED),
  /// except that a task this phone already answered never goes back to
  /// PENDING while the server has not received the answer yet: it stays
  /// WAITING.
  static Future<void> storeTasks(
    DatabaseExecutor txn,
    String childId,
    List<Map<String, dynamic>> tasks,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final raw in tasks) {
      final task = DailyTask.fromJson(raw);
      if (task.taskId == 0) continue;

      final answered = await txn.query(
        'daily_task_answer',
        columns: ['answer_id'],
        where: 'task_id = ?',
        whereArgs: [task.taskId],
        limit: 1,
      );

      final row = {
        'child_id': childId,
        'task_date': _dateKey(task.taskDate),
        'question_type': task.questionType,
        'question': task.question,
        'reward': task.reward,
        'status': answered.isNotEmpty && task.status == 'PENDING'
            ? 'WAITING'
            : task.status,
        'updated_at': now,
        'pop_quiz_options': task.options.isEmpty ? null : task.options.join('\n'),
      };

      final updated = await txn.update(
        'daily_task',
        row,
        where: 'task_id = ?',
        whereArgs: [task.taskId],
      );
      if (updated == 0) {
        await txn.insert('daily_task', {
          'task_id': task.taskId,
          ...row,
          'created_at': now,
        });
      }
    }
  }

  Future<DailyTask?> _localToday(String childId) async {
    final db = await _appDb.db;
    final rows = await db.query(
      'daily_task',
      where: 'child_id = ? AND task_date = ? AND question_type = ?',
      whereArgs: [childId, _dateKey(DateTime.now()), reflection],
      orderBy: 'task_id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DailyTask(
      taskId: row['task_id'] as int? ?? 0,
      childId: row['child_id'] as String? ?? childId,
      taskDate: DateTime.tryParse('${row['task_date']}') ?? DateTime.now(),
      questionType: row['question_type'] as String? ?? reflection,
      question: row['question'] as String? ?? '',
      options: const <String>[],
      reward: (row['reward'] as num?)?.toInt() ?? 0,
      status: row['status'] as String? ?? 'PENDING',
    );
  }

  Future<String?> _childIdOrNull() async {
    try {
      final id = await _identity.childId();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _online() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
