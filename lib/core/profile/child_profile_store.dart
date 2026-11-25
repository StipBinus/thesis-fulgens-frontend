import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../auth/session_manager.dart';
import '../config/api_config.dart';
import '../db/app_db.dart';
import '../db/local_data.dart';
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

    final stored = await _fromDb();
    if (stored != null) {
      _profile = stored;
      return stored;
    }

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
    final stored = await _fromDb();
    if (stored != null) {
      _profile = stored;
      return stored;
    }

    final cached = _profile;
    if (cached != null) return cached;
    final restored = await restore();
    if (restored != null) return restored;
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

  // Stores a backend profile without another request.
  Future<void> store(ChildProfile profile) async {
    try {
      final token = await _session.getValidToken();
      if (token != null && token.isNotEmpty) {
        await _writeDb(token, profile);
      }
    } catch (_) {
      // The cache still works when SQLite is unavailable.
    }

    _profile = profile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(profile.toJson()));
  }

  // Overwrites the stored profile, balance included, at login.
  Future<void> storeRemote(ChildProfile profile) async {
    try {
      final token = await _session.getValidToken();
      if (token != null && token.isNotEmpty) {
        // Server balance: pull re-adds unsent entries on top, like pockets
        _profile = await _writeDb(token, profile, overwriteBalance: true);
      } else {
        _profile = profile;
      }
    } catch (_) {
      _profile = profile;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(_profile!.toJson()));
    LocalData.instance.bump();
  }

  // Picks up balance changes written straight to SQLite.
  Future<void> reload() async {
    final stored = await _fromDb();
    if (stored != null) _profile = stored;
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

    final fresh = await _writeDb(token, profile);

    _profile = fresh;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(fresh.toJson()));
    LocalData.instance.bump();

    return fresh;
  }

  // SQLite is the source the screens read; the network only refreshes it.
  Future<ChildProfile> _writeDb(
    String token,
    ChildProfile profile, {
    bool overwriteBalance = false,
  }) async {
    try {
      final childId = _session.getUserId(token);
      if (childId == null || childId.isEmpty) return profile;

      final db = await AppDb.instance.db;
      await db.insert('users', {
        'keycloak_id': childId,
        'user_type': 'CHILD',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final rows = await db.query(
        'users_children',
        columns: ['name'],
        where: 'child_id = ?',
        whereArgs: [childId],
        limit: 1,
      );
      final blankName = rows.isEmpty ||
          ((rows.first['name'] as String?) ?? '').isEmpty;

      await db.insert('users_children', {
        'child_id': childId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.update(
        'users_children',
        {
          'name': profile.name,
          'profile_picture': profile.profilePicture,
          'game_currency': profile.userCurrency,
          'parent_currency': profile.parentCurrency,
          'streak': profile.userStreak,
          if (overwriteBalance || blankName) 'balance': profile.userBalance,
        },
        where: 'child_id = ?',
        whereArgs: [childId],
      );

      return await _fromDb() ?? profile;
    } catch (_) {
      return profile;
    }
  }

  Future<ChildProfile?> _fromDb() async {
    try {
      // Saved login: reading the phone copy needs no network
      final childId = await _session.cachedUserId();
      if (childId == null || childId.isEmpty) return null;

      final db = await AppDb.instance.db;
      final rows = await db.query(
        'users_children',
        where: 'child_id = ?',
        whereArgs: [childId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final name = (row['name'] as String?) ?? '';
      if (name.isEmpty) return null;

      return ChildProfile(
        profilePicture: row['profile_picture'] as String?,
        name: name,
        userCurrency: (row['game_currency'] as num?)?.toInt() ?? 0,
        parentCurrency: (row['parent_currency'] as num?)?.toInt() ?? 0,
        userBalance: (row['balance'] as num?)?.toInt() ?? 0,
        userStreak: (row['streak'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
