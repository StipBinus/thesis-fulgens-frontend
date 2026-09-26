import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:thesis_fulgens_mobile/core/config/api_config.dart';
import '../app//presentation/auth_service/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final authService = AuthService();
    final ApiConfig apiConfig = ApiConfig();

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFFFA500)),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), // Top-left corner radius
                  topRight: Radius.circular(20), // Top-right corner radius
                ),
                border: Border.all(color: Colors.white, width: 2),
              ),

              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Login to continue to Fulgens',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),

                      const SizedBox(height: 40),

                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            final username = usernameController.text;
                            final password = passwordController.text;

                            final response = await http.post(
                              Uri.parse(
                                '${apiConfig.getKeycloakUrl()}/realms/fulgens/protocol/openid-connect/token', //pake local 8080 kalo ga pake emulator
                              ),
                              headers: {
                                'Content-Type':
                                    'application/x-www-form-urlencoded',
                              },
                              body: {
                                'client_id': 'fulgens-mobile',
                                'username': username,
                                'password': password,
                                'grant_type': 'password',
                              },
                            );

                            if (response.statusCode != 200) {
                              //Ini Tambahin Stip Kalo Dia Gagal Login Gimana UI nya
                              return;
                            }

                            final responseData = jsonDecode(response.body);
                            print(responseData);
                            final accessToken = responseData['access_token'];

                            await authService.saveToken(accessToken);

                            final role = authService.getUserRole(accessToken);

                            if (!context.mounted) {
                              return;
                            }

                            if (role == 'PARENT') {
                              print('Navigating to /parent');
                              context.go('/parent');
                              return;
                            }

                            if (role == 'USER') {
                              print('Navigating to /');
                              context.go('/');
                              return;
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to register
                              if (!context.mounted) {
                                return;
                              }

                              context.go('/Register');
                            },
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
