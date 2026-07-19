import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Palet warna Point Rescue
///
/// CATATAN Fase 1: kelas ini dalam proses pensiun. Sumber warna baru
/// adalah AppTokens (app_tokens.dart) yang kontrasnya dijaga uji WCAG.
/// Layar bermigrasi per-alur di Fase 2 (keputusan D-F3); AppColors
/// dihapus setelah layar terakhir yang memakainya dirombak.
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
    fontFamily: 'Inter', // sejak Fase 1-F2 benar-benar dimuat (bukan lagi fallback diam-diam)
    // Registrasi lapisan token (Fase 1-F1b). SENGAJA hanya ini yang
    // berubah: nilai ThemeData lama dipertahankan agar tampilan layar
    // yang belum dimigrasi tidak bergeser (D-F3 — migrasi per-alur di
    // Fase 2). Tema gelap & malam-merah dibangun di Fase 3 bersama
    // switch-nya.
    extensions: const [AppTokens.light],
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
