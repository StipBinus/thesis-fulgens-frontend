import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import 'child_task_models.dart';

/// Error raised when a parent task request fails.
class ChildTaskApiException implements Exception {
  const ChildTaskApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Backend calls used by the "set daily questions" step.
class ChildTaskApi {
  ChildTaskApi({ApiConfig? config}) : _config = config ?? ApiConfig();

  final ApiConfig _config;

  /// `GET /api/parent-task/preview?prompt=...`
  ///
  /// Requires the parent's access token: the endpoint only accepts the
  /// `PARENT` realm role.
  Future<TaskPreview> preview({
    required String prompt,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${_config.getBackendUrl()}/api/parent-task/preview',
    ).replace(queryParameters: {'prompt': prompt});

    final http.Response response;
    try {
      response = await http.get(uri, headers: _headers(token));
    } catch (_) {
      throw const ChildTaskApiException(
        'Could not reach the server. Check your connection.',
      );
    }

    if (response.statusCode != 200) {
      throw _exception(response, 'Could not generate the questions');
    }

    final payload = _decode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const ChildTaskApiException('The question preview was empty.');
    }

    return TaskPreview.fromJson(payload);
  }

  /// `POST /api/auth/parent/register-new-child`
  ///
  /// Called only after the parent approves the questions. Returns the new
  /// child's id.
  Future<String> registerChild({
    required ChildDraft draft,
    required String composedPrompt,
    required String token,
  }) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse(
          '${_config.getBackendUrl()}/api/auth/parent/register-new-child',
        ),
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode(draft.toRegisterJson(composedPrompt)),
      );
    } catch (_) {
      throw const ChildTaskApiException(
        'Could not reach the server. Check your connection.',
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _exception(response, 'Could not create the child');
    }

    final payload = _decode(response.body);
    final childId = payload is Map ? payload['childId'] : null;

    if (childId is! String || childId.isEmpty) {
      throw const ChildTaskApiException(
        'The child was created but the server did not return its id.',
      );
    }

    return childId;
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  ChildTaskApiException _exception(http.Response response, String fallback) {
    var message = '$fallback (${response.statusCode}).';
    final payload = _decode(response.body);

    if (payload is Map) {
      final detail = payload['message'] ?? payload['error'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail.trim();
      }
    }

    return ChildTaskApiException(message, statusCode: response.statusCode);
  }

  dynamic _decode(String body) {
    if (body.isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
