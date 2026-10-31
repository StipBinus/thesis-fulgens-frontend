import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final apiConfig = ApiConfig();

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Returns a token that is still valid, refreshing it first when needed.
  Future<String?> getValidToken({
    Duration expirySkew = const Duration(seconds: 30),
  }) async {
    final token = await getToken();

    if (token != null &&
        token.isNotEmpty &&
        !_isTokenExpired(token, skew: expirySkew)) {
      return token;
    }

    return refreshAccessToken();
  }

  /// Exchanges the stored refresh token for a new access token.
  /// Returns null when there is no refresh token or the server rejects it.
  Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '${apiConfig.getKeycloakUrl()}/realms/fulgens/protocol/openid-connect/token',
        ),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': 'fulgens-mobile',
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        await logout();
        return null;
      }

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'];

      if (accessToken is! String || accessToken.isEmpty) {
        await logout();
        return null;
      }

      final newRefreshToken = data['refresh_token'];

      await saveSession(
        accessToken: accessToken,
        refreshToken: newRefreshToken is String ? newRefreshToken : null,
      );

      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasValidToken() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    return !_isTokenExpired(token);
  }

  bool _isTokenExpired(String token, {Duration skew = Duration.zero}) {
    try {
      final payload = _decodePayload(token);
      final expiration = payload['exp'];

      if (expiration is! int) {
        return true;
      }

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
      );

      return DateTime.now().isAfter(expirationDate.subtract(skew));
    } catch (_) {
      return true;
    }
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

  String? getUserRole(String token) {
    final decodedToken = JwtDecoder.decode(token);

    final realmAccess = decodedToken['realm_access'];

    if (realmAccess == null) {
      return null;
    }

    final roles = List<String>.from(realmAccess['roles']);

    if (roles.contains('PARENT')) {
      return 'PARENT';
    }

    if (roles.contains('USER')) {
      return 'USER';
    }

    return null;
  }

  String? getUserId(String token) {
    final decodedToken = JwtDecoder.decode(token);

    final subject = decodedToken['sub'];

    if (subject is! String || subject.isEmpty) {
      return null;
    }

    return subject;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
