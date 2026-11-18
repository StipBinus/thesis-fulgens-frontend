import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thesis_fulgens_mobile/core/profile/child_profile_store.dart';
import 'package:thesis_fulgens_mobile/core/sync/backend_pull.dart';

import '../finance/finance_models.dart';
import '../finance/finance_repository.dart';
import '../logbook/logbook_money.dart';
import '../logbook/logbook_provider.dart';
import '../pocket/kids_order_store.dart';
import 'home_models.dart';

// Everything the home sheet shows, filled before the page opens.
class KidsHomeData {
  const KidsHomeData({
    this.profile,
    this.event = const EventData(eventName: 'No event', endsIn: '-'),
    this.missions = const <DailyMission>[],
    this.goals = const <UserGoal>[],
    this.pockets = const <ChildPocket>[],
    this.order = const <String>[],
  });

  final UserProfileData? profile;
  final EventData event;
  final List<DailyMission> missions;
  final List<UserGoal> goals;
  final List<ChildPocket> pockets;
  final List<String> order;

  // Ready once the profile has landed.
  bool get isReady => profile != null;

  KidsHomeData copyWith({List<String>? order}) {
    return KidsHomeData(
      profile: profile,
      event: event,
      missions: missions,
      goals: goals,
      pockets: pockets,
      order: order ?? this.order,
    );
  }
}

// Loads the home payload once, then serves it to every screen that asks.
class KidsHomeNotifier extends Notifier<KidsHomeData> {
  // Running load, shared by every caller.
  Future<void>? _inFlight;
  // Load already finished.
  bool _loaded = false;

  @override
  KidsHomeData build() => const KidsHomeData();

  // Loads only when nothing is loaded yet.
  Future<void> load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (_loaded) return Future<void>.value();
    return _start();
  }

  // Re-reads everything, keeping the old data on screen meanwhile.
  Future<void> refresh() {
    _loaded = false;
    final pending = _inFlight;
    if (pending == null) return _start();
    // A load from a previous child may still be running, queue behind it.
    return pending.then((_) => _start());
  }

  // Login: the backend copy replaces SQLite before the local reload.
  Future<void> reloadAfterLogin() {
    _loaded = false;
    final pending = _inFlight;
    if (pending == null) return _start(forcePull: true);
    return pending.then((_) => _start(forcePull: true));
  }

  // Card order from the savings page.
  void setOrder(List<String> order) {
    if (order.isEmpty || _sameOrder(order)) return;
    state = state.copyWith(order: order);
  }

  bool _sameOrder(List<String> order) {
    final current = state.order;
    if (current.length != order.length) return false;
    for (var i = 0; i < order.length; i++) {
      if (current[i] != order[i]) return false;
    }
    return true;
  }

  Future<void> _start({bool forcePull = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _run(forcePull: forcePull);
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<void> _run({bool forcePull = false}) async {
    try {
      // Local first, the backend copy lands underneath.
      await _loadLocal();
      final pulled = await BackendPull().run(force: forcePull);
      if (!pulled) return;
      ref.invalidate(logbookProvider);
      ref.invalidate(logbookMoneyProvider);
      await _loadLocal();
    } catch (_) {
      // Keep whatever the sheet already shows.
    }
  }

  Future<void> _loadLocal() async {
    final results = await Future.wait<Object?>([
      _fetchProfileSafe(),
      _fetchEvent(),
      _fetchMissions(),
      _fetchGoals(),
      _fetchPockets(),
      KidsOrderStore().load(),
    ]);

    state = KidsHomeData(
      profile: results[0] as UserProfileData?,
      event: results[1] as EventData,
      missions: results[2] as List<DailyMission>,
      goals: results[3] as List<UserGoal>,
      pockets: results[4] as List<ChildPocket>,
      order: results[5] as List<String>,
    );
    _loaded = true;
  }

  // Profile fetch that never throws, so an offline call does not blank the
  // rest of the sheet.
  Future<UserProfileData?> _fetchProfileSafe() async {
    try {
      final profile = await ChildProfileStore.instance.ensure();

      return UserProfileData(
        profilePicture: profile.profilePicture,
        name: profile.name,
        userCurrency: profile.userCurrency,
        parentCurrency: profile.parentCurrency,
        userBalance: profile.userBalance,
        userStreak: profile.userStreak,
      );
    } catch (_) {
      return null;
    }
  }

  Future<EventData> _fetchEvent() async {
    // Dummy data after urlComment.
    return const EventData(eventName: 'Spring Festival', endsIn: '2d 14h');
  }

  Future<List<DailyMission>> _fetchMissions() async {
    // Dummy data after urlComment.
    return const [
      DailyMission(
        title: 'Logging',
        completed: true,
        icon: Icons.edit_outlined,
      ),
      DailyMission(
        title: 'View History',
        completed: false,
        icon: Icons.history,
      ),
    ];
  }

  Future<List<UserGoal>> _fetchGoals() async {
    try {
      final goals = await ref.read(goalRepositoryProvider).fetchGoals();
      return goals
          .map(
            (goal) => UserGoal(
              id: goal.goalId,
              name: goal.goalsName,
              target: goal.goalPrice,
              saved: goal.allocatedBalance,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChildPocket>> _fetchPockets() async {
    try {
      return await ref.read(pocketRepositoryProvider).fetchPockets();
    } catch (_) {
      return const [];
    }
  }
}

final kidsHomeProvider = NotifierProvider<KidsHomeNotifier, KidsHomeData>(
  KidsHomeNotifier.new,
);
