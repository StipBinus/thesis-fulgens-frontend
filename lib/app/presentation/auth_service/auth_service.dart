import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<bool> hasValidToken() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    return !_isTokenExpired(token);
  }

  bool _isTokenExpired(String token) {
    try {
      final payload = _decodePayload(token);
      final expiration = payload['exp'];

      if (expiration is! int) {
        return true;
      }

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(
        expiration * 1000,
      );

      return DateTime.now().isAfter(expirationDate);
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
  }
}
