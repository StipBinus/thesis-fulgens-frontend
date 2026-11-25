// Pockets and goals now read from SQLite. The API classes stay for the one-time
// seed import and for the sync worker that lands later.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/session_manager.dart';
import '../../core/db/local_data.dart';
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
    String? note,
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
    String? image,
  });

  Future<ChildGoal> updateGoal({
    required String goalId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
    String? image,
    String? note,
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
    // Saved login first: works offline, still follows an account switch
    final saved = await SessionManager.instance.cachedUserId();
    if (saved != null && saved.isNotEmpty) {
      if (saved != _cached) {
        _cached = saved;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, saved);
      }
      return saved;
    }

    // Signed-in child first, so an account switch never reads the old child
    try {
      final live = await _api.childId();
      if (live != _cached) {
        _cached = live;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, live);
      }
      return live;
    } catch (_) {
      final cached = _cached;
      if (cached != null && cached.isNotEmpty) return cached;
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
    String? note,
  }) async {
    return _store.updatePocket(
      pocketId: pocketId,
      childId: await _identity.childId(),
      name: name,
      description: description,
      image: image,
      allocatedBalance: allocatedBalance,
      note: note,
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
    String? image,
  }) async {
    return _store.createGoal(
      childId: await _identity.childId(),
      name: name,
      description: description,
      allocatedBalance: allocatedBalance,
      goalPrice: goalPrice,
      image: image,
    );
  }

  @override
  Future<ChildGoal> updateGoal({
    required String goalId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
    String? image,
    String? note,
  }) async {
    return _store.updateGoal(
      goalId: goalId,
      childId: await _identity.childId(),
      name: name,
      description: description,
      allocatedBalance: allocatedBalance,
      goalPrice: goalPrice,
      image: image,
      note: note,
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

// Real pocket/goal history, refreshed on every local write
final moneyActivityProvider =
    FutureProvider.family<List<MoneyActivity>, String>((ref, targetId) {
      ref.watch(localDataProvider);
      return FinanceLocalStore().fetchActivity(targetId);
    });

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
