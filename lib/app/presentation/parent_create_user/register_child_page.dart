import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../auth_service/auth_service.dart';

class RegisterChildPage extends StatefulWidget {
  const RegisterChildPage({super.key});

  @override
  State<RegisterChildPage> createState() => _RegisterChildPage();
}

class RegisterChildHandler {
  final apiConfig = ApiConfig();

  Map<String, String> validate({
    required String username,
    required String password,
    required DateTime? birthDate,
    required String grade,
  }) {
    // TODO: implement validate
    Map<String, String> errResult = {};

    if (username.trim().isEmpty) {
      errResult['username'] = 'Username is required';
    }

    if (password.trim().isEmpty) {
      errResult['password'] = 'Password is required';
    }

    if (birthDate == null) {
      errResult['birthDate'] = 'Birth Date is required';
    }

    if (grade.trim().isEmpty) {
      errResult['grade'] = 'Grade is required';
    }

    return errResult;
  }

  Future<String?> register({
    required String username,
    required String password,
    required DateTime? birthDate,
    required String grade,
    required String parentUserId,
    required String token,
  }) async {
    final validationErrors = validate(
      username: username,
      password: password,
      birthDate: birthDate,
      grade: grade,
    );

    if (validationErrors.isNotEmpty) {
      return validationErrors.values.first;
    }

    final request = {
      'username': username.trim(),
      'password': password,
      'birthDate': birthDate!.toIso8601String().split('T').first,
      'grade': grade.trim(),
      'parentId': parentUserId,
    };

    try {
      print('Token exists: ${token.isNotEmpty}');
      print('Token length: ${token.length}');
      final response = await http.post(
        Uri.parse(
          '${apiConfig.getBackendUrl()}/api/auth/parent/register-new-child',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request),
      );

      print(
        'Register child response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      return _errorMessageFrom(response.body);
    } catch (_) {
      return 'Could not reach the server. Check your connection.';
    }
  }

  String _errorMessageFrom(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map) {
        final message = data['message'] ?? data['error'];

        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Non JSON error body, fall through to the generic message.
    }

    return 'Child registration failed. Try again.';
  }
}

class _RegisterChildPage extends State<RegisterChildPage> {
  final authService = AuthService();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final gradeController = TextEditingController();

  DateTime? birthDate;

  Map<String, String> errors = {};

  bool submitting = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    gradeController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (submitting) return;

    final handler = RegisterChildHandler();

    final validationErrors = handler.validate(
      username: usernameController.text,
      password: passwordController.text,
      birthDate: birthDate,
      grade: gradeController.text,
    );

    if (validationErrors.isNotEmpty) {
      setState(() => errors = validationErrors);
      return;
    }

    setState(() {
      submitting = true;
      errors.remove('submit');
      errors.remove('session');
    });

    // Read (and refresh when needed) the token right before the request,
    // so a token that expired while the form was being filled is still valid.
    final authToken = await authService.getValidToken();
    final parentUserId = authToken == null
        ? null
        : authService.getUserId(authToken);

    if (!mounted) return;

    if (authToken == null || parentUserId == null) {
      setState(() {
        submitting = false;
        errors['session'] = 'Session expired. Please log in again.';
      });
      return;
    }

    final errorMessage = await handler.register(
      username: usernameController.text,
      password: passwordController.text,
      birthDate: birthDate,
      grade: gradeController.text,
      parentUserId: parentUserId,
      token: authToken,
    );

    if (!mounted) return;

    if (errorMessage != null) {
      setState(() {
        submitting = false;
        errors['submit'] = errorMessage;
      });
      return;
    }

    setState(() {
      submitting = false;
      errors = {};
      usernameController.clear();
      passwordController.clear();
      gradeController.clear();
      birthDate = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Child registered successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Register Child')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: errors['username'],
                  ),
                ),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: errors['password'],
                  ),
                ),
                TextField(
                  controller: gradeController,
                  decoration: InputDecoration(
                    labelText: 'Grade',
                    errorText: errors['grade'],
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  birthDate == null
                      ? 'No birth date selected'
                      : 'Birth date: ${birthDate!.toIso8601String().split('T').first}',
                ),
                if (errors.containsKey('birthDate'))
                  Text(
                    errors['birthDate']!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2015),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );

                    if (selectedDate == null) return;

                    setState(() {
                      birthDate = selectedDate;
                      errors.remove('birthDate');
                    });
                  },
                  child: const Text('Select Birth Date'),
                ),
                const SizedBox(height: 16),
                if (errors['session'] != null && errors['session']!.isNotEmpty)
                  Text(
                    errors['session']!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (errors['submit'] != null)
                  Text(
                    errors['submit']!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ElevatedButton(
                  onPressed: submitting ? null : register,
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
