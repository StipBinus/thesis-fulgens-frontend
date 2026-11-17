// Pockets and goals now read from SQLite. The API classes stay for the one-time
// seed import and for the sync worker that lands later.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'finance_api.dart';
import 'finance_local_store.dart';
import 'finance_models.dart';

abstract class PocketRepository {
  Future<List<ChildPocket>> fetchPockets();

  Future<ChildPocket> createPocket({
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  });

  Future<ChildPocket> updatePocket({
    required String pocketId,
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  });

  Future<void> deletePocket(String pocketId);
}

abstract class GoalRepository {
  Future<List<ChildGoal>> fetchGoals();

  Future<ChildGoal> createGoal({
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  });

  Future<ChildGoal> updateGoal({
    required String goalId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  });

  Future<void> deleteGoal(String goalId);
}

/// Child id from the cached login, so money screens work without a token.
class ChildIdentity {
  ChildIdentity({FinanceApi? api}) : _api = api ?? FinanceApi();

  static const String _key = 'finance_child_id';

  final FinanceApi _api;
  String? _cached;

  Future<String> childId() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final live = await _api.childId();
      _cached = live;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, live);
      return live;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored != null && stored.isNotEmpty) {
        _cached = stored;
        return stored;
      }
      rethrow;
    }
  }

  Future<void> forget() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final childIdentityProvider = Provider<ChildIdentity>((ref) => ChildIdentity());

class LocalPocketRepository implements PocketRepository {
  LocalPocketRepository({FinanceLocalStore? store, ChildIdentity? identity})
    : _store = store ?? FinanceLocalStore(),
      _identity = identity ?? ChildIdentity();

  final FinanceLocalStore _store;
  final ChildIdentity _identity;

  @override
  Future<List<ChildPocket>> fetchPockets() async {
    return _store.fetchPockets(await _identity.childId());
  }

  @override
  Future<ChildPocket> createPocket({
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  }) async {
    return _store.createPocket(
      childId: await _identity.childId(),
      name: name,
      description: description,
      image: image,
      allocatedBalance: allocatedBalance,
    );
  }

  @override
  Future<ChildPocket> updatePocket({
    required String pocketId,
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  }) async {
    return _store.updatePocket(
      pocketId: pocketId,
      childId: await _identity.childId(),
      name: name,
      description: description,
      image: image,
      allocatedBalance: allocatedBalance,
    );
  }

  @override
  Future<void> deletePocket(String pocketId) {
    return _store.deletePocket(pocketId);
  }
}

class LocalGoalRepository implements GoalRepository {
  LocalGoalRepository({FinanceLocalStore? store, ChildIdentity? identity})
    : _store = store ?? FinanceLocalStore(),
      _identity = identity ?? ChildIdentity();

  final FinanceLocalStore _store;
  final ChildIdentity _identity;

  @override
  Future<List<ChildGoal>> fetchGoals() async {
    return _store.fetchGoals(await _identity.childId());
  }

  @override
  Future<ChildGoal> createGoal({
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    return _store.createGoal(
      childId: await _identity.childId(),
      name: name,
      description: description,
      allocatedBalance: allocatedBalance,
      goalPrice: goalPrice,
    );
  }

  @override
  Future<ChildGoal> updateGoal({
    required String goalId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    return _store.updateGoal(
      goalId: goalId,
      childId: await _identity.childId(),
      name: name,
      description: description,
      allocatedBalance: allocatedBalance,
      goalPrice: goalPrice,
    );
  }

  @override
  Future<void> deleteGoal(String goalId) {
    return _store.deleteGoal(goalId);
  }
}

final pocketRepositoryProvider = Provider<PocketRepository>(
  (ref) => LocalPocketRepository(),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => LocalGoalRepository(),
);

// Remote reads, used once to seed the local tables and later by sync.
class ApiPocketRepository {
  ApiPocketRepository({FinanceApi? api}) : _api = api ?? FinanceApi();

  final FinanceApi _api;

  Future<List<ChildPocket>> fetchPockets() async {
    final childId = await _api.childId();
    final payload = await _api.get('/api/pocket/child/$childId');

    if (payload is! List) return const [];

    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChildPocket.fromJson)
        .toList();
  }
}

class ApiGoalRepository {
  ApiGoalRepository({FinanceApi? api}) : _api = api ?? FinanceApi();

  final FinanceApi _api;

  Future<List<ChildGoal>> fetchGoals() async {
    final childId = await _api.childId();
    final payload = await _api.get('/api/goals/child/$childId');

    if (payload is! List) return const [];

    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChildGoal.fromJson)
        .toList();
  }
}

/// Copies the backend rows into SQLite the first time the tables are empty.
class FinanceSeed {
  FinanceSeed({
    FinanceLocalStore? store,
    ChildIdentity? identity,
    ApiPocketRepository? pockets,
    ApiGoalRepository? goals,
  }) : _store = store ?? FinanceLocalStore(),
       _identity = identity ?? ChildIdentity(),
       _pockets = pockets ?? ApiPocketRepository(),
       _goals = goals ?? ApiGoalRepository();

  static const String _doneKey = 'finance_seed_v1';

  final FinanceLocalStore _store;
  final ChildIdentity _identity;
  final ApiPocketRepository _pockets;
  final ApiGoalRepository _goals;

  Future<void> importIfEmpty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) ?? false) return;

      final childId = await _identity.childId();
      if (!await _store.isEmpty(childId)) {
        await prefs.setBool(_doneKey, true);
        return;
      }

      final remotePockets = await _pockets.fetchPockets();
      final remoteGoals = await _goals.fetchGoals();

      for (final pocket in remotePockets) {
        await _store.importRow(childId: childId, pocket: pocket);
      }
      for (final goal in remoteGoals) {
        await _store.importRow(childId: childId, goal: goal);
      }

      final balance = remotePockets.isNotEmpty
          ? remotePockets.first.userBalance
          : remoteGoals.isNotEmpty
          ? remoteGoals.first.userBalance
          : 0;
      if (balance > 0) await _store.saveBalance(childId, balance);

      await prefs.setBool(_doneKey, true);
    } catch (_) {
      // Offline first run: the next launch retries the seed.
    }
  }
}
