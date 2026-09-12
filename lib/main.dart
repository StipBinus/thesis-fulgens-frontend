import 'package:flutter/material.dart';

void main() {
  runApp(const FulgensApp());
}

class FulgensApp extends StatelessWidget {
  const FulgensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fulgens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F7F3),
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A45),
          primary: const Color(0xFFFF7A45),
          surface: const Color(0xFFF9F7F3),
        ),
      ),
      home: const FulgensHomePage(),
    );
  }
}

class FulgensHomePage extends StatelessWidget {
  const FulgensHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('ready'),
      ),
    );
  }
}
