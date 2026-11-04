import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Error raised when the token endpoint rejects a sign-in attempt.
class SessionException implements Exception {
  const SessionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Owns the access/refresh token lifecycle for the whole app.
///
/// Tokens are kept in memory for fast reads and mirrored into secure storage so
/// the session survives app restarts. Every API caller should ask this manager
/// for a token through [getValidToken]; the manager refreshes an expired token
/// before returning it.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const String _clientId = 'fulgens-mobile';
  static const String _accessKey = 'session_access_token';
  static const String _refreshKey = 'session_refresh_token';
  static const String _expiresKey = 'session_expires_at';

  // Keys used by the old AuthService. Removed once at startup.
  static const String _legacyAccessKey = 'access_token';
  static const String _legacyRefreshKey = 'refresh_token';

  final ApiConfig _apiConfig = ApiConfig();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  int? _expiresAtMs;
  bool _restored = false;
  Future<void>? _restoreFuture;
  Future<String?>? _refreshFuture;

  bool get hasSession => _accessToken != null || _refreshToken != null;

  /// Restores a previous session from secure storage. Safe to call repeatedly.
  Future<void> restore() {
    if (_restored) return Future.value();

    final running = _restoreFuture;
    if (running != null) return running;

    final future = _restore();
    _restoreFuture = future;
    return future.whenComplete(() => _restoreFuture = null);
  }

  Future<void> _restore() async {
    try {
      final access = await _secureStorage.read(key: _accessKey);
      final refresh = await _secureStorage.read(key: _refreshKey);
      final expires = await _secureStorage.read(key: _expiresKey);

      _accessToken = _nonEmpty(access);
      _refreshToken = _nonEmpty(refresh);
      _expiresAtMs =
          int.tryParse(expires ?? '') ?? _expiryFromToken(_accessToken);
    } catch (_) {
      // Secure storage is unavailable; continue as a guest.
    } finally {
      _restored = true;
    }
  }

  /// Returns an access token that is still valid, refreshing it first when
  /// needed. Returns `null` when there is no session or the refresh fails.
  Future<String?> getValidToken({
    Duration expirySkew = const Duration(seconds: 30),
  }) async {
    await _ensureRestored();

    final token = _accessToken;
    if (token != null &&
        token.isNotEmpty &&
        !_isExpired(token, skew: expirySkew)) {
      return token;
    }

    return refreshAccessToken();
  }

  /// Exchanges the stored refresh token for a new access token.
  Future<String?> refreshAccessToken() {
    final running = _refreshFuture;
    if (running != null) return running;

    final future = _refresh();
    _refreshFuture = future;
    return future.whenComplete(() => _refreshFuture = null);
  }

  Future<String?> _refresh() async {
    await _ensureRestored();

    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await clear();
      return null;
    }

    try {
      final response = await http.post(
        _tokenUri,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        await clear();
        return null;
      }

      final data = _decode(response.body);
      if (data == null) {
        await clear();
        return null;
      }

      final accessToken = await _saveResponse(
        data,
        fallbackRefreshToken: refreshToken,
      );

      if (accessToken == null) {
        await clear();
      }

      return accessToken;
    } catch (_) {
      // Keep the tokens for a later retry when the network is down.
      return null;
    }
  }

  /// Password grant against the Keycloak token endpoint.
  ///
  /// Saves the returned access/refresh tokens before returning the access token.
  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    await _ensureRestored();

    final response = await http.post(
      _tokenUri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'username': username,
        'password': password,
        'grant_type': 'password',
      },
    );

    print(response.statusCode);

    if (response.statusCode != 200) {
      throw const SessionException(
        'Username or password did not match. Try again.',
      );
    }

    final data = _decode(response.body);
    if (data == null) {
      throw const SessionException('The server returned an invalid response.');
    }

    final accessToken = await _saveResponse(data);
    if (accessToken == null) {
      throw const SessionException('No user found.');
    }

    return accessToken;
  }

  /// Clears both the in-memory session and the secure storage copy.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAtMs = null;
    _restored = true;

    try {
      await Future.wait([
        _secureStorage.delete(key: _accessKey),
        _secureStorage.delete(key: _refreshKey),
        _secureStorage.delete(key: _expiresKey),
      ]);
    } catch (_) {
      // Nothing else we can do; the in-memory session is already gone.
    }
  }

  Future<void> logout() => clear();

  /// Removes tokens written by the old SharedPreferences-based AuthService.
  Future<void> clearLegacyStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyAccessKey);
      await prefs.remove(_legacyRefreshKey);
    } catch (_) {
      // SharedPreferences is optional for this cleanup.
    }
  }

  String? getUserRole(String token) {
    try {
      final decoded = _decodePayload(token);
      final realmAccess = decoded['realm_access'];

      if (realmAccess is! Map) return null;

      final roles = List<String>.from(
        realmAccess['roles'] as List? ?? const [],
      );

      if (roles.contains('PARENT')) return 'PARENT';
      if (roles.contains('USER')) return 'USER';
      return null;
    } catch (_) {
      return null;
    }
  }

  String? getUserId(String token) {
    try {
      final subject = _decodePayload(token)['sub'];
      if (subject is! String || subject.isEmpty) return null;
      return subject;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureRestored() async {
    if (!_restored) await restore();
  }

  Future<String?> _saveResponse(
    Map<String, dynamic> data, {
    String? fallbackRefreshToken,
  }) async {
    final access = data['access_token'];
    if (access is! String || access.isEmpty) return null;

    final refresh = data['refresh_token'];
    final expiresIn = data['expires_in'];

    _accessToken = access;
    _refreshToken =
        refresh is String && refresh.isNotEmpty
            ? refresh
            : (fallbackRefreshToken == null || fallbackRefreshToken.isEmpty
                ? null
                : fallbackRefreshToken);

    _expiresAtMs =
        expiresIn is num
            ? DateTime.now().millisecondsSinceEpoch + expiresIn.toInt() * 1000
            : _expiryFromToken(access);
    _restored = true;

    await _persist();
    return access;
  }

  Future<void> _persist() async {
    try {
      await _writeOrDelete(_accessKey, _accessToken);
      await _writeOrDelete(_refreshKey, _refreshToken);
      await _writeOrDelete(_expiresKey, _expiresAtMs?.toString());
    } catch (_) {
      // The in-memory session still works even if persistence fails.
    }
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value == null || value.isEmpty) {
      return _secureStorage.delete(key: key);
    }
    return _secureStorage.write(key: key, value: value);
  }

  bool _isExpired(String token, {required Duration skew}) {
    final expiresAt = _expiresAtMs ?? _expiryFromToken(token);
    if (expiresAt == null) return true;

    return DateTime.now().millisecondsSinceEpoch >=
        expiresAt - skew.inMilliseconds;
  }

  int? _expiryFromToken(String? token) {
    if (token == null || token.isEmpty) return null;

    try {
      final expiration = _decodePayload(token)['exp'];
      if (expiration is num) return expiration.toInt() * 1000;
    } catch (_) {
      // Fall through to an unknown expiration.
    }

    return null;
  }

  Map<String, dynamic> _decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT');
    }

    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Invalid JSON.
    }

    return null;
  }

  String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Uri get _tokenUri => Uri.parse(
    '${_apiConfig.getKeycloakUrl()}/realms/fulgens/protocol/openid-connect/token',
  );
}
