import 'package:flutter/material.dart';

abstract final class Brand {
  static const navy = Color(0xFF0B3158);
  static const teal = Color(0xFF008E89);
  static const background = Color(0xFFF3F7F9);
  static const muted = Color(0xFF5F7485);
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.navy,
      primary: Brand.navy,
      secondary: Brand.teal,
      surface: Colors.white,
      onSurface: const Color(0xFF18334B),
    ),
    scaffoldBackgroundColor: Brand.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.background,
      foregroundColor: Brand.navy,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFE0F2EF),
    ),
  );
}
