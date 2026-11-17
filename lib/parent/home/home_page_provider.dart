import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/session_manager.dart';
import '../../core/config/api_config.dart';
import '../../model/ChildAccount.dart';
import 'home_models.dart';
import 'selected_child_provider.dart';

/// Error raised when a parent home request fails.
class HomeApiException implements Exception {
  const HomeApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// All backend calls used by the parent home page.
///
/// Keeping the HTTP work here means the widgets only deal with state from
/// Riverpod, and every endpoint lives in one place.
class HomeApi {
  HomeApi({ApiConfig? config}) : _config = config ?? ApiConfig();

  final ApiConfig _config;

  /// `GET /api/auth/get/children/{parentId}`.
  ///
  /// The parent id is the JWT `sub` claim inside the stored access token, so it
  /// is read from the session rather than a separate storage key.
  Future<List<ChildAccount>> fetchChildren() async {
    final token = await _token();
    final parentId = SessionManager.instance.getUserId(token);

    if (parentId == null || parentId.isEmpty) {
      throw const HomeApiException('Could not find your parent profile.');
    }

    final payload = await _get(
      '/api/auth/get/children/$parentId',
      failure: 'Could not load children',
    );

    if (payload is! List) return const [];

    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChildAccount.fromJson)
        .toList();
  }

  /// `GET /api/transaction-logs/monthly?childId=&year=&month=`.
  ///
  /// Returns `dateKey (2026-11-05) -> summary` for one calendar month.
  Future<Map<String, String>> fetchLogMonth({
    required String childId,
    required int year,
    required int month,
  }) async {
    final payload = await _get(
      '/api/transaction-logs/monthly',
      query: {'childId': childId, 'year': '$year', 'month': '$month'},
      failure: 'Could not load the logbook',
    );

    if (payload is! Map<String, dynamic>) return const {};

    final logs = payload['logs'];
    if (logs is! List) return const {};

    final days = <String, String>{};
    for (final raw in logs.whereType<Map<String, dynamic>>()) {
      final dateKey = raw['logDate'] as String?;
      if (dateKey == null || dateKey.isEmpty) continue;
      days[dateKey] = (raw['summary'] as String? ?? '').trim();
    }

    return days;
  }

  /// `GET /api/transaction-logs/child/{childId}/profile-finance-chart`.
  Future<SpendingChartData> fetchSpendingChart({
    required String childId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final payload = await _get(
      '/api/transaction-logs/child/$childId/profile-finance-chart',
      query: {'startDate': _isoDate(startDate), 'endDate': _isoDate(endDate)},
      failure: 'Could not load the spending chart',
    );

    if (payload is! Map<String, dynamic>) {
      return SpendingChartData(
        childId: childId,
        startDate: startDate,
        endDate: endDate,
        slices: const [],
      );
    }

    return SpendingChartData.fromJson(
      payload,
      childId: childId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<String> _token() async {
    final token = await SessionManager.instance.getValidToken();

    if (token == null || token.isEmpty) {
      throw const HomeApiException(
        'Your session has expired. Please sign in again.',
      );
    }

    return token;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? query,
    required String failure,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${_config.getBackendUrl()}$path',
    ).replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw HomeApiException(
        '$failure (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) return null;

    return jsonDecode(response.body);
  }
}

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

// ======================================================================
// Providers
// ======================================================================

/// Key for [childLogMonthProvider]: one child, one calendar month.
typedef ChildLogMonthKey = ({String childId, int year, int month});

/// Key for [spendingChartProvider]: one child, one date range.
typedef SpendingChartKey =
    ({String childId, DateTime startDate, DateTime endDate});

final homeApiProvider = Provider<HomeApi>((ref) => HomeApi());

/// Children linked to the signed-in parent.
///
/// Auto-disposed so coming back from `/child-register` asks the API again and
/// the new child appears without a manual refresh.
final childAccountsProvider = FutureProvider.autoDispose<List<ChildAccount>>((
  ref,
) {
  return ref.watch(homeApiProvider).fetchChildren();
});

/// Log summaries for the calendar, keyed by child + month.
///
/// Paging back to a month already opened is served from Riverpod's cache.
final childLogMonthProvider =
    FutureProvider.family<Map<String, String>, ChildLogMonthKey>((ref, key) {
      return ref
          .watch(homeApiProvider)
          .fetchLogMonth(
            childId: key.childId,
            year: key.year,
            month: key.month,
          );
    });

/// Category totals for the spending donut, keyed by child + date range.
final spendingChartProvider = FutureProvider.autoDispose
    .family<SpendingChartData, SpendingChartKey>((ref, key) {
      return ref
          .watch(homeApiProvider)
          .fetchSpendingChart(
            childId: key.childId,
            startDate: key.startDate,
            endDate: key.endDate,
          );
    });

/// The child every home section should show.
///
/// Falls back to the first child when nothing is selected yet, or when the
/// selected child disappeared, so the calendar and chart never go stale.
final selectedChildProvider = Provider.autoDispose<ChildAccount?>((ref) {
  final children =
      ref.watch(childAccountsProvider).asData?.value ?? const <ChildAccount>[];
  if (children.isEmpty) return null;

  final selectedId = ref.watch(selectedChildIdProvider);
  for (final child in children) {
    if (child.childId == selectedId) return child;
  }

  return children.first;
});
