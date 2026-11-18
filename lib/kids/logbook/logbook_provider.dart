import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile/child_profile_store.dart';
import '../../core/sync/backend_pull.dart';
import '../../core/sync/sync_engine.dart';
import '../finance/finance_repository.dart';
import 'logbook_models.dart';
import 'logbook_money.dart';
import 'logbook_repository.dart';

class LogbookNotifier extends Notifier<LogbookState> {
  late LogbookRepository _repository;
  bool _disposed = false;

  // A user action that happens while the first load is still running wins:
  // the in-flight load must not overwrite it with an older snapshot.
  bool _mutated = false;

  // API writes run one at a time so a quick add/edit/delete cannot race the
  // same daily log.
  Future<void> _queue = Future.value();
  Timer? _closeTimer;

  @override
  LogbookState build() {
    _repository = ref.watch(logbookRepositoryProvider);
    _disposed = false;
    _mutated = false;
    _queue = Future.value();
    _closeTimer?.cancel();
    _closeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoClose(),
    );
    ref.onDispose(() {
      _disposed = true;
      _closeTimer?.cancel();
    });
    unawaited(_restore());
    return LogbookState.seeded();
  }

  Future<void> _restore() async {
    // Same bootstrap as the home page; skips when this launch already pulled.
    try {
      await BackendPull().run();
    } catch (_) {
      // Offline: the local mirror stays as it is.
    }

    final restored = await _repository.load();
    if (_disposed) return;

    unawaited(_drainOutbox());

    if (_mutated) {
      // Keep the optimistic state the user just produced.
      state = state.copyWith(loaded: true);
      return;
    }

    if (restored == null) {
      state = state.copyWith(loaded: true);
      unawaited(_repository.save(state));
      return;
    }

    state = restored.copyWith(loaded: true);
    _closePastDays();
  }

  // Catch-up close for days that passed 6pm while the app was closed.
  void _closePastDays() {
    final late = <String, LogbookDay>{};
    for (final entry in state.days.entries) {
      final day = entry.value;
      if (day.completedAt != null || !day.qualifies) continue;
      if (!_pastSix(entry.key)) continue;
      late[entry.key] = day.copyWith(completedAt: DateTime.now());
    }
    if (late.isEmpty) return;
    state = state.copyWith(days: {...state.days, ...late});
    _mutated = true;
    unawaited(_repository.save(state));
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  int _signed(LogbookEntry entry) {
    return entry.isExpense ? -entry.amount : entry.amount;
  }

  Future<void> _moveMoney({
    required int balanceDelta,
    String? pocketId,
    required int pocketDelta,
  }) async {
    if (balanceDelta == 0 && pocketDelta == 0) return;
    try {
      await _repository.moveMoney(
        balanceDelta: balanceDelta,
        pocketId: pocketId,
        pocketDelta: pocketDelta,
      );
    } catch (_) {
      // The logbook row is saved; money can be corrected on the next edit.
    }
  }

  Future<void> _drainOutbox() async {
    try {
      await SyncEngine().syncNow();
    } catch (_) {
      // Offline; the next open retries.
    }
  }

  // Goal ids ride on the entry's pocket id
  String? _goalIdOf(LogbookEntry entry) {
    final id = entry.pocketId;
    if (id == null || !id.startsWith('goal:')) return null;
    return id.substring(5);
  }

  Future<void> _allocateGoal(String goalId, int delta) async {
    if (delta == 0) return;
    try {
      final repo = ref.read(goalRepositoryProvider);
      final goals = await repo.fetchGoals();
      for (final goal in goals) {
        if (goal.goalId != goalId) continue;
        final next = (goal.allocatedBalance + delta).clamp(0, 1 << 31).toInt();
        await repo.updateGoal(
          goalId: goal.goalId,
          name: goal.goalsName,
          description: goal.goalsDesc,
          allocatedBalance: next,
          goalPrice: goal.goalPrice,
        );
        return;
      }
    } catch (_) {
      // The logbook row is saved; the goal can be corrected on the next edit.
    }
  }

  // One entry's money move; goals take the allocation instead of a pocket.
  Future<void> _moveForEntry(
    LogbookEntry entry, {
    required int balanceDelta,
    required int amountDelta,
  }) async {
    final goalId = _goalIdOf(entry);
    if (goalId == null) {
      await _moveMoney(
        balanceDelta: balanceDelta,
        pocketId: entry.pocketId,
        pocketDelta: amountDelta,
      );
      return;
    }
    await _moveMoney(
      balanceDelta: balanceDelta,
      pocketId: null,
      pocketDelta: 0,
    );
    await _allocateGoal(goalId, amountDelta);
  }

  void _commit(LogbookState next, String dateKey) {
    _mutated = true;
    state = _settle(next, dateKey);
    unawaited(_repository.save(state));
  }

  // Auto-close only after 6pm, and only for a day with an entry and a note.
  LogbookState _settle(LogbookState current, String dateKey) {
    final day = current.dayFor(dateKey);
    if (day.rewardClaimed || !day.qualifies || day.completedAt != null) {
      return current;
    }
    if (!_pastSix(dateKey)) return current;

    final ready = day.copyWith(completedAt: DateTime.now());
    return current.copyWith(days: {...current.days, dateKey: ready});
  }

  bool _pastSix(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    final closeAt = DateTime(year, month, day, 18);
    return !DateTime.now().isBefore(closeAt);
  }

  // Manual close from the check button
  Future<void> markClosed(String dateKey) {
    return _enqueue(() async {
      final day = state.dayFor(dateKey);
      if (day.completedAt != null) return;
      if (day.entries.isEmpty && day.note.trim().isEmpty) return;
      _commit(
        state.copyWith(
          days: {
            ...state.days,
            dateKey: day.copyWith(completedAt: DateTime.now()),
          },
        ),
        dateKey,
      );
    });
  }

  void _autoClose() {
    if (!state.loaded || _disposed) return;
    final key = logbookDateKey(DateTime.now());
    final day = state.dayFor(key);
    if (day.completedAt != null || !day.qualifies) return;
    if (!_pastSix(key)) return;
    _commit(
      state.copyWith(
        days: {
          ...state.days,
          key: day.copyWith(completedAt: DateTime.now()),
        },
      ),
      key,
    );
  }

  // Pays the coins and berries showing on the row.
  int claimReward(String dateKey, {required int coins, required int berries}) {
    final day = state.dayFor(dateKey);
    if (!day.qualifies) return 0;

    final claimed = day.copyWith(
      completedAt: day.completedAt ?? DateTime.now(),
      rewardClaimed: true,
    );

    _mutated = true;
    state = state.copyWith(
      days: {...state.days, dateKey: claimed},
      berries: state.berries + berries,
      coinsEarned: state.coinsEarned + coins,
      lastClaimKey: dateKey,
      lastClaimCoins: coins,
      lastClaimBerries: berries,
    );
    unawaited(_repository.save(state));
    return coins;
  }

  Future<bool> addEntry(String dateKey, LogbookEntry entry) {
    return _enqueue(() async {
      final previous = state.dayFor(dateKey);
      final entries = [...previous.entries, entry];

      _commit(
        state.copyWith(
          days: {
            ...state.days,
            dateKey: previous.copyWith(entries: entries, zeroSpend: false),
          },
        ),
        dateKey,
      );

      try {
        final saved = await _repository.upsertDay(
          dateKey: dateKey,
          note: state.dayFor(dateKey).note,
          entries: entries,
          logId: previous.logId,
          clientId: previous.clientId,
        );
        _applySavedDay(dateKey, saved, entries);
        final signed = _signed(entry);
        await _moveForEntry(
          entry,
          balanceDelta: signed,
          amountDelta: signed,
        );
        unawaited(_refreshBalance());
        return true;
      } catch (_) {
        _restoreDay(dateKey, previous);
        return false;
      }
    });
  }

  Future<bool> updateEntry(String dateKey, LogbookEntry updated) {
    return _enqueue(() async {
      final previous = state.dayFor(dateKey);
      final index = previous.entries.indexWhere(
        (entry) => entry.id == updated.id,
      );
      if (index < 0) return false;

      final entries = [...previous.entries]..[index] = updated;

      _commit(
        state.copyWith(
          days: {
            ...state.days,
            dateKey: previous.copyWith(entries: entries, zeroSpend: false),
          },
        ),
        dateKey,
      );

      try {
        final saved = await _repository.upsertDay(
          dateKey: dateKey,
          note: state.dayFor(dateKey).note,
          entries: entries,
          logId: previous.logId,
          clientId: previous.clientId,
        );
        _applySavedDay(dateKey, saved, entries);
        final before = previous.entries[index];
        final beforeSigned = _signed(before);
        final afterSigned = _signed(updated);
        if (before.pocketId == updated.pocketId) {
          await _moveForEntry(
            updated,
            balanceDelta: afterSigned - beforeSigned,
            amountDelta: afterSigned - beforeSigned,
          );
        } else {
          await _moveForEntry(
            updated,
            balanceDelta: afterSigned - beforeSigned,
            amountDelta: afterSigned,
          );
          await _moveForEntry(
            before,
            balanceDelta: 0,
            amountDelta: -beforeSigned,
          );
        }
        unawaited(_refreshBalance());
        return true;
      } catch (_) {
        _restoreDay(dateKey, previous);
        return false;
      }
    });
  }

  Future<LogbookEntry?> deleteEntry(String dateKey, String entryId) {
    return _enqueue(() async {
      final previous = state.dayFor(dateKey);
      final index = previous.entries.indexWhere((entry) => entry.id == entryId);
      if (index < 0) return null;

      final removed = previous.entries[index];
      final entries = [...previous.entries]..removeAt(index);

      _commit(
        state.copyWith(
          days: {
            ...state.days,
            dateKey: previous.copyWith(entries: entries, zeroSpend: false),
          },
        ),
        dateKey,
      );

      try {
        if (previous.logId == null && !_repository.localOnly) {
          // Never reached the backend, so there is nothing to delete remotely.
          return removed;
        }

        if (entries.isEmpty && previous.note.trim().isEmpty) {
          await _repository.deleteLog(
            logId: previous.logId,
            dateKey: dateKey,
            clientId: previous.clientId,
          );
          _clearLogId(dateKey);
        } else {
          final saved = await _repository.upsertDay(
            dateKey: dateKey,
            note: previous.note,
            entries: entries,
            logId: previous.logId,
          );
          _applySavedDay(dateKey, saved, entries);
        }

        final signed = _signed(removed);
        await _moveForEntry(
          removed,
          balanceDelta: -signed,
          amountDelta: -signed,
        );
        unawaited(_refreshBalance());
        return removed;
      } catch (_) {
        _restoreDay(dateKey, previous);
        return null;
      }
    });
  }

  Future<void> setNote(String dateKey, String note) {
    return _enqueue(() async {
      final previous = state.dayFor(dateKey);
      if (previous.note == note) return;

      _commit(
        state.copyWith(
          days: {...state.days, dateKey: previous.copyWith(note: note)},
        ),
        dateKey,
      );

      // A note on a day without a log creates one, so the diary survives a
      // reload. Empty notes on a day that never reached the backend stay local.
      if (previous.logId == null &&
          note.trim().isEmpty &&
          !_repository.localOnly) {
        return;
      }

      try {
        final saved = await _repository.upsertDay(
          dateKey: dateKey,
          note: note,
          entries: previous.entries,
          logId: previous.logId,
          clientId: previous.clientId,
        );
        _applySavedDay(dateKey, saved, previous.entries);
      } catch (_) {
        // Notes are best-effort: keep the typed text and retry on next edit.
      }
    });
  }

  bool toggleZeroSpend(String dateKey) {
    final day = state.dayFor(dateKey);
    final nextValue = !day.zeroSpend;

    final next = state.copyWith(
      days: {...state.days, dateKey: day.copyWith(zeroSpend: nextValue)},
    );
    _commit(next, dateKey);
    return nextValue;
  }

  void _applySavedDay(
    String dateKey,
    LogbookDay saved,
    List<LogbookEntry> localEntries,
  ) {
    if (_disposed) return;

    final current = state.dayFor(dateKey);
    state = state.copyWith(
      days: {
        ...state.days,
        dateKey: current.copyWith(
          clientId: saved.clientId.isEmpty ? current.clientId : saved.clientId,
          logId: saved.logId,
          clearLogId: saved.logId == null,
          entries: _mergeSavedEntries(saved.entries, localEntries),
          note: saved.note,
        ),
      },
    );
    unawaited(_repository.save(state));
  }

  void _clearLogId(String dateKey) {
    if (_disposed) return;

    final current = state.dayFor(dateKey);
    state = state.copyWith(
      days: {...state.days, dateKey: current.copyWith(clearLogId: true)},
    );
    unawaited(_repository.save(state));
  }

  void _restoreDay(String dateKey, LogbookDay previous) {
    if (_disposed) return;

    // Restore the whole day, not just the entries: the optimistic commit may
    // also have cleared zeroSpend or marked the reward as ready.
    state = state.copyWith(days: {...state.days, dateKey: previous});
    unawaited(_repository.save(state));
  }

  List<LogbookEntry> _mergeSavedEntries(
    List<LogbookEntry> saved,
    List<LogbookEntry> local,
  ) {
    if (saved.isEmpty) return saved;

    return [
      for (var i = 0; i < saved.length; i++)
        i < local.length
            ? saved[i].copyWith(
              pocketId: local[i].pocketId,
              pocketName: local[i].pocketName,
              note: local[i].note,
            )
            : saved[i],
    ];
  }

  Future<void> _refreshBalance() async {
    if (_repository.localOnly) {
      if (!_disposed) ref.invalidate(logbookMoneyProvider);
      return;
    }

    try {
      await ChildProfileStore.instance.refresh();
    } catch (_) {
      // Keep the cached balance when the refresh fails.
    }

    if (!_disposed) ref.invalidate(logbookMoneyProvider);
  }
}

final logbookProvider = NotifierProvider<LogbookNotifier, LogbookState>(
  LogbookNotifier.new,
);
