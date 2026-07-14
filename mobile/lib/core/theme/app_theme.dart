import 'package:flutter/material.dart';

/// Palet warna Point Rescue
class AppColors {
  AppColors._();

  static const primary = Color(0xFF153B7A);
  static const secondary = Color(0xFFF36C21);
  static const success = Color(0xFF36C275);
  static const offline = Color(0xFFEF4444);
  static const background = Color(0xFFF5F7FB);
  static const card = Colors.white;
  static const text = Color(0xFF0A1930); // Dark Navy
}

class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter', // Or fallback to default sans-serif
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: AppColors.background,
      surface: AppColors.card,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
