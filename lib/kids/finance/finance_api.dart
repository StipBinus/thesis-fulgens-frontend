import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/auth/session_manager.dart';
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';

/// Error raised when a finance request fails.
class FinanceApiException implements Exception {
  const FinanceApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin HTTP layer shared by the goal and pocket repositories.
///
/// The logged-in child id is the JWT `sub` claim, which is also what the
/// backend uses for `/api/home/profile/child`.
class FinanceApi {
  FinanceApi({ApiConfig? config}) : _config = config ?? ApiConfig();

  final ApiConfig _config;

  Future<String> childId() async {
    final token = await _token();
    final id = SessionManager.instance.getUserId(token);

    if (id == null || id.isEmpty) {
      throw const FinanceApiException(
        'Could not find your child profile. Please sign in again.',
      );
    }

    return id;
  }

  Future<dynamic> get(String path) async {
    final token = await _token();
    final response = await http.get(_uri(path), headers: _headers(token));
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final token = await _token();
    final response = await http.post(
      _uri(path),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final token = await _token();
    final response = await http.put(
      _uri(path),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final token = await _token();
    final response = await http.delete(_uri(path), headers: _headers(token));
    return _decode(response);
  }

  Future<String> _token() async {
    final token = await SessionManager.instance.getValidToken();

    if (token == null || token.isEmpty) {
      throw const FinanceApiException(
        'Your session has expired. Please sign in again.',
      );
    }

    return token;
  }

  Uri _uri(String path) => Uri.parse('${_config.getBackendUrl()}$path');

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  dynamic _decode(http.Response response) {
    final dynamic payload =
        response.body.isEmpty ? null : _tryDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    throw FinanceApiException(
      _errorMessage(payload, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _errorMessage(dynamic payload, int statusCode) {
    if (payload is Map<String, dynamic>) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) return message;

      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) return error;
    }

    return 'Request failed ($statusCode)';
  }
}
