import 'finance_api.dart';
import 'finance_models.dart';

/// CRUD for `/api/goals`.
class ChildGoalRepository {
  ChildGoalRepository({FinanceApi? api}) : _api = api ?? FinanceApi();

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

  Future<ChildGoal> createGoal({
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    final childId = await _api.childId();
    final payload = await _api.post('/api/goals', {
      'childId': childId,
      'goalsName': name.trim(),
      'goalsDesc': _blankToNull(description),
      'allocatedBalance': allocatedBalance,
      'goalPrice': goalPrice,
    });

    return ChildGoal.fromJson(_asMap(payload));
  }

  Future<ChildGoal> updateGoal({
    required int goalId,
    required String name,
    String? description,
    required int allocatedBalance,
    required int goalPrice,
  }) async {
    final payload = await _api.put('/api/goals/$goalId', {
      'goalsName': name.trim(),
      // An empty string clears the column on the backend.
      'goalsDesc': description?.trim() ?? '',
      'allocatedBalance': allocatedBalance,
      'goalPrice': goalPrice,
    });

    return ChildGoal.fromJson(_asMap(payload));
  }

  Future<void> deleteGoal(int goalId) async {
    await _api.delete('/api/goals/$goalId');
  }
}

/// CRUD for `/api/pocket`.
class ChildPocketRepository {
  ChildPocketRepository({FinanceApi? api}) : _api = api ?? FinanceApi();

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

  Future<ChildPocket> createPocket({
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  }) async {
    final childId = await _api.childId();
    final payload = await _api.post('/api/pocket', {
      'childId': childId,
      'pocketImage': _blankToNull(image),
      'pocketName': name.trim(),
      'pocketDesc': _blankToNull(description),
      'allocatedBalance': allocatedBalance,
    });

    return ChildPocket.fromJson(_asMap(payload));
  }

  Future<ChildPocket> updatePocket({
    required int pocketId,
    required String name,
    String? description,
    String? image,
    required int allocatedBalance,
  }) async {
    final payload = await _api.put('/api/pocket/$pocketId', {
      'pocketImage': image?.trim() ?? '',
      'pocketName': name.trim(),
      // An empty string clears the column on the backend.
      'pocketDesc': description?.trim() ?? '',
      'allocatedBalance': allocatedBalance,
    });

    return ChildPocket.fromJson(_asMap(payload));
  }

  Future<void> deletePocket(int pocketId) async {
    await _api.delete('/api/pocket/$pocketId');
  }
}

Map<String, dynamic> _asMap(dynamic payload) {
  if (payload is Map<String, dynamic>) return payload;
  throw const FinanceApiException('Unexpected response from the server.');
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
