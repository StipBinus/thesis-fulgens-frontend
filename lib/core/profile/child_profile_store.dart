import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/session_manager.dart';
import '../config/api_config.dart';
import 'child_profile.dart';

/// Reads the child profile once per login/session and keeps it on the device.
///
/// Screens can call [ensure] to get the cached profile instantly; the HTTP call
/// only happens when nothing has been cached yet.
class ChildProfileStore {
  ChildProfileStore._();

  static final ChildProfileStore instance = ChildProfileStore._();

  static const String _cacheKey = 'child_profile_v1';

  final SessionManager _session = SessionManager.instance;
  final ApiConfig _apiConfig = ApiConfig();

  ChildProfile? _profile;
  Future<ChildProfile>? _inFlight;

  ChildProfile? get profile => _profile;

  bool get hasProfile => _profile != null;

  /// Reads the last profile stored on the device.
  Future<ChildProfile?> restore() async {
    final cached = _profile;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final profile = ChildProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _profile = profile;
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached profile, fetching it once when the cache is empty.
  Future<ChildProfile> ensure() async {
    final cached = _profile ?? await restore();
    if (cached != null) return cached;
    return refresh();
  }

  /// Fetches a fresh profile and stores it. Concurrent calls share one request.
  Future<ChildProfile> refresh() {
    final running = _inFlight;
    if (running != null) return running;

    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  /// Refreshes silently when a session already exists (app restart).
  Future<void> refreshIfSignedIn() async {
    try {
      final token = await _session.getValidToken();
      if (token == null || token.isEmpty) return;
      if (_session.getUserRole(token) != 'USER') return;
      await refresh();
    } catch (_) {
      // Keep the cached copy when the network is unavailable.
    }
  }

  Future<void> clear() async {
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  Future<ChildProfile> _fetch() async {
    final token = await _session.getValidToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final response = await http.get(
      Uri.parse('${_apiConfig.getBackendUrl()}/api/home/profile/child'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load profile (${response.statusCode})');
    }

    final profile = ChildProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    _profile = profile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(profile.toJson()));

    return profile;
  }
}
