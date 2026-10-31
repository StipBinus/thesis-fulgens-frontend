import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logbook_models.dart';
import 'logbook_repository.dart';

const int logbookCoinsPerDay = 10;
const int logbookBerriesPerDay = 1;
const int logbookMilestoneBonus = 5;
const int logbookMilestoneDays = 7;

class LogbookNotifier extends Notifier<LogbookState> {
  late final LogbookRepository _repository;
  bool _disposed = false;

  @override
  LogbookState build() {
    _repository = ref.watch(logbookRepositoryProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_restore());
    return LogbookState.seeded();
  }

  Future<void> _restore() async {
    final restored = await _repository.load();
    if (_disposed) return;

    if (restored == null) {
      state = state.copyWith(loaded: true);
      unawaited(_repository.save(state));
      return;
    }

    state = restored.copyWith(loaded: true);
  }

  void _commit(LogbookState next, String dateKey) {
    state = _settle(next, dateKey);
    unawaited(_repository.save(state));
  }

  // A qualifying day is only marked ready here; the reward waits to be taken.
  LogbookState _settle(LogbookState current, String dateKey) {
    final day = current.dayFor(dateKey);
    if (day.rewardClaimed || !day.qualifies || day.completedAt != null) {
      return current;
    }

    final ready = day.copyWith(completedAt: DateTime.now());
    return current.copyWith(days: {...current.days, dateKey: ready});
  }

  // Takes the day's reward once, returns the coins paid out.
  int claimReward(String dateKey, {int bonusCoins = 0}) {
    final day = state.dayFor(dateKey);
    if (day.rewardClaimed || !day.qualifies) return 0;

    final claimed = day.copyWith(
      completedAt: day.completedAt ?? DateTime.now(),
      rewardClaimed: true,
    );
    final probe = state.copyWith(
      days: {...state.days, dateKey: claimed},
    );
    var coins = logbookCoinsPerDay + (bonusCoins < 0 ? 0 : bonusCoins);
    final streak = probe.streakOn(dateKey);
    if (streak > 0 && streak % logbookMilestoneDays == 0) {
      coins += logbookMilestoneBonus;
    }

    state = probe.copyWith(
      berries: probe.berries + logbookBerriesPerDay,
      coinsEarned: probe.coinsEarned + coins,
      lastClaimKey: dateKey,
    );
    unawaited(_repository.save(state));
    return coins;
  }

  PocketWallet? _applyEntry(
    PocketWallet wallet,
    LogbookEntry entry, {
    required bool reverse,
  }) {
    final delta = entry.isExpense ? -entry.amount : entry.amount;
    final signed = reverse ? -delta : delta;
    final current = wallet.of(entry.pocket);
    final next = current + signed;

    if (next < 0) {
      if (!reverse) return null;
      return wallet.withAmount(entry.pocket, 0);
    }
    return wallet.withAmount(entry.pocket, next);
  }

  bool addEntry(String dateKey, LogbookEntry entry) {
    final wallet = _applyEntry(state.pockets, entry, reverse: false);
    if (wallet == null) return false;

    final day = state.dayFor(dateKey);
    final next = state.copyWith(
      days: {
        ...state.days,
        dateKey: day.copyWith(
          entries: [...day.entries, entry],
          zeroSpend: false,
        ),
      },
      pockets: wallet,
    );
    _commit(next, dateKey);
    return true;
  }

  bool updateEntry(String dateKey, LogbookEntry updated) {
    final day = state.dayFor(dateKey);
    final index = day.entries.indexWhere((entry) => entry.id == updated.id);
    if (index < 0) return false;

    final previous = day.entries[index];
    final reverted = _applyEntry(state.pockets, previous, reverse: true);
    if (reverted == null) return false;

    final wallet = _applyEntry(reverted, updated, reverse: false);
    if (wallet == null) return false;

    final entries = [...day.entries]..[index] = updated;
    final next = state.copyWith(
      days: {
        ...state.days,
        dateKey: day.copyWith(entries: entries, zeroSpend: false),
      },
      pockets: wallet,
    );
    _commit(next, dateKey);
    return true;
  }

  LogbookEntry? deleteEntry(String dateKey, String entryId) {
    final day = state.dayFor(dateKey);
    final index = day.entries.indexWhere((entry) => entry.id == entryId);
    if (index < 0) return null;

    final removed = day.entries[index];
    final wallet = _applyEntry(state.pockets, removed, reverse: true);
    if (wallet == null) return null;

    final entries = [...day.entries]..removeAt(index);
    final next = state.copyWith(
      days: {
        ...state.days,
        dateKey: day.copyWith(entries: entries, zeroSpend: false),
      },
      pockets: wallet,
    );
    _commit(next, dateKey);
    return removed;
  }

  void setNote(String dateKey, String note) {
    final day = state.dayFor(dateKey);
    if (day.note == note) return;

    final next = state.copyWith(
      days: {...state.days, dateKey: day.copyWith(note: note)},
    );
    _commit(next, dateKey);
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

  bool transfer(PocketSlot from, PocketSlot to, int amount) {
    if (from == to || amount <= 0) return false;
    if (state.pockets.of(from) < amount) return false;

    final wallet = state.pockets
        .withAmount(from, state.pockets.of(from) - amount)
        .withAmount(to, state.pockets.of(to) + amount);
    state = state.copyWith(pockets: wallet);
    unawaited(_repository.save(state));
    return true;
  }

  int availableFor(String dateKey, PocketSlot slot, {LogbookEntry? editing}) {
    var available = state.pockets.of(slot);
    if (editing != null && editing.pocket == slot && editing.isExpense) {
      available += editing.amount;
    }
    return math.max(0, available);
  }
}

final logbookProvider = NotifierProvider<LogbookNotifier, LogbookState>(
  LogbookNotifier.new,
);
