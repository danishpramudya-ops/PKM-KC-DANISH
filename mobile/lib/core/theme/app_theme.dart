import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_type.dart';

/// Palet warna lama Point Rescue.
///
/// PENSIUN: sumber warna adalah [AppTokens]. Kelas ini hanya tersisa untuk
/// layar yang belum dimigrasi (developer_mode); dihapus setelah layar
/// terakhir yang memakainya dirombak.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF153B7A);
  static const secondary = Color(0xFFF36C21);
  static const success = Color(0xFF36C275);
  static const offline = Color(0xFFEF4444);
  static const background = Color(0xFFF5F7FB);
  static const card = Colors.white;
  static const text = Color(0xFF0A1930);
}

/// Tema aplikasi, dibangun SEPENUHNYA dari [AppTokens] (Fase 2).
///
/// Default aplikasi = **gelap** (keputusan pasca Brand Identity Audit:
/// karakter brand dashboard menang atas argumen keterbacaan siang; mitigasi
/// = switch tema mudah dijangkau, docs/strategi-ux.md D4-revisi).
class AppTheme {
  AppTheme._();

  static final dark = _build(AppTokens.dark, Brightness.dark);
  static final light = _build(AppTokens.light, Brightness.light);
  static final nightRed = _build(AppTokens.nightRed, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      extensions: [t],
      scaffoldBackgroundColor: t.surfaceBase,
      canvasColor: t.surfaceBase,
      dividerColor: t.contentMuted.withValues(alpha: 0.25),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.accent,
        onPrimary: t.onAccent,
        secondary: t.accent,
        onSecondary: t.onAccent,
        error: t.statusCritical,
        onError: t.surfaceBase,
        surface: t.surfaceBase,
        onSurface: t.contentPrimary,
        surfaceContainerHighest: t.surfaceRaised,
        outline: t.contentMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surfaceBase,
        foregroundColor: t.contentPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: AppType.title.copyWith(color: t.contentPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accent.withValues(alpha: 0.18),
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          AppType.caption.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? t.accent
                : t.contentMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          minimumSize: const Size.fromHeight(AppTouch.minTarget),
          textStyle: AppType.label.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.contentSecondary,
          minimumSize: const Size.fromHeight(AppTouch.minTarget),
          side: BorderSide(color: t.contentMuted.withValues(alpha: 0.45)),
          textStyle: AppType.label.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.contentMuted,
          minimumSize: const Size.fromHeight(44),
          textStyle: AppType.label,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceOverlay,
        contentTextStyle: AppType.body.copyWith(
          fontSize: 14,
          color: t.contentPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      textTheme: TextTheme(
        displaySmall: AppType.display,
        titleLarge: AppType.title,
        bodyLarge: AppType.body,
        labelLarge: AppType.label,
        bodySmall: AppType.caption,
      ).apply(
        bodyColor: t.contentPrimary,
        displayColor: t.contentPrimary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
