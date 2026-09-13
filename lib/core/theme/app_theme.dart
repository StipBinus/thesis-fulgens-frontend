import 'package:flutter/material.dart';

/// Central theme for Fulgens app.
/// Keeps MaterialApp clean and allows reuse across app + game.
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFFFF7A45);
  static const Color primary = Color(0xFFFF7A45);
  static const Color scaffoldBg = Color(0xFFF9F7F3);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: scaffoldBg,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          primary: primary,
          surface: scaffoldBg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: scaffoldBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
      );
}
