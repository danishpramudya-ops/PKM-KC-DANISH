import 'package:flutter/material.dart';

/// Lapisan token POINTRESCUE (Fase 1-F1a, docs/fase-1-implementation-plan.md §2).
///
/// SATU-SATUNYA sumber warna untuk seluruh UI. Aturan Tactical-Utilitarian:
/// warna hanya menyampaikan status — tidak ada warna dekoratif.
///
/// Tiga palet: terang (default lapangan siang), gelap, malam-merah
/// (menjaga adaptasi mata pada operasi malam). "Ikuti sistem" bukan palet —
/// ia mode yang memilih terang/gelap.
///
/// Setiap nilai DIJAGA oleh uji kontras WCAG otomatis
/// (test/core/theme/contrast_test.dart). Kalau mengubah nilai di sini,
/// jalankan uji itu — nilai yang gagal digeser sampai lolos, BUKAN ujinya
/// yang dilonggarkan. Ambang per tema (keputusan D-F4):
///  - terang & gelap: 4.5:1 untuk semua pasangan wajib
///  - malam-merah: 4.5:1 untuk contentPrimary/critical/accent,
///    3.0:1 untuk sekunder/muted/status non-kritikal (kompromi sadar
///    night-vision — konten sekunder memang sengaja diredupkan)
class AppTokens extends ThemeExtension<AppTokens> {
  // Permukaan — 3 tingkat, tidak lebih
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color surfaceOverlay;

  // Konten — 3 tingkat, tidak lebih
  final Color contentPrimary;
  final Color contentSecondary;
  final Color contentMuted;

  // Status: statusX = teks/ikon (wajib AA di atas semua surface),
  // statusXSurface = tint latar pill/badge (pasangan X-di-atas-XSurface
  // juga diuji). Ini menggantikan pola `warna.withOpacity(0.1)` yang
  // dipakai 36 kali tanpa pernah diverifikasi kontrasnya.
  final Color statusCritical;
  final Color statusCriticalSurface;
  final Color statusWarning;
  final Color statusWarningSurface;
  final Color statusOk;
  final Color statusOkSurface;
  final Color statusInactive;
  final Color statusInactiveSurface;

  // Aksi utama — satu saja
  final Color accent;
  final Color onAccent;

  const AppTokens({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.contentPrimary,
    required this.contentSecondary,
    required this.contentMuted,
    required this.statusCritical,
    required this.statusCriticalSurface,
    required this.statusWarning,
    required this.statusWarningSurface,
    required this.statusOk,
    required this.statusOkSurface,
    required this.statusInactive,
    required this.statusInactiveSurface,
    required this.accent,
    required this.onAccent,
  });

  /// Ambil token tema aktif; fallback ke terang bila extension belum
  /// terdaftar (mis. di test yang mem-pump widget telanjang).
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? light;

  /// Palet TERANG — default. Alat lapangan paling sering dipakai siang
  /// hari di bawah matahari; kontras tinggi di sini lebih penting daripada
  /// kesan "taktis gelap" (keputusan D4, strategi-ux.md).
  static const light = AppTokens(
    surfaceBase: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F4F8),
    surfaceOverlay: Color(0xFFE4E9F0),
    contentPrimary: Color(0xFF0B1220),
    contentSecondary: Color(0xFF3D4A5C),
    contentMuted: Color(0xFF54637A),
    statusCritical: Color(0xFFB91C1C),
    statusCriticalSurface: Color(0xFFFDE2E2),
    statusWarning: Color(0xFF8A5800),
    statusWarningSurface: Color(0xFFF7E9CE),
    statusOk: Color(0xFF166B3F),
    statusOkSurface: Color(0xFFDBF0E4),
    statusInactive: Color(0xFF566276),
    statusInactiveSurface: Color(0xFFE6EAF0),
    accent: Color(0xFF1A4E8A),
    onAccent: Color(0xFFFFFFFF),
  );

  /// Palet GELAP — posko malam, dalam tenda/kendaraan.
  static const dark = AppTokens(
    surfaceBase: Color(0xFF0C1118),
    surfaceRaised: Color(0xFF161D27),
    surfaceOverlay: Color(0xFF1F2937),
    contentPrimary: Color(0xFFE8EDF4),
    contentSecondary: Color(0xFFADBACB),
    contentMuted: Color(0xFF8494A7),
    statusCritical: Color(0xFFF87171),
    statusCriticalSurface: Color(0xFF3D1516),
    statusWarning: Color(0xFFFBBF24),
    statusWarningSurface: Color(0xFF3A2A05),
    statusOk: Color(0xFF4ADE80),
    statusOkSurface: Color(0xFF0F3320),
    statusInactive: Color(0xFF8797AA),
    statusInactiveSurface: Color(0xFF1F2834),
    accent: Color(0xFF7FB3E8),
    onAccent: Color(0xFF06121F),
  );

  /// Palet MALAM-MERAH — operasi malam, menjaga adaptasi mata gelap.
  ///
  /// Masalah desain yang diselesaikan di sini (rencana §2): di tema
  /// serba-merah, warna merah kehilangan makna "bahaya". Maka
  /// statusCritical memakai INVERSI BLOK — teks nyaris-putih di atas
  /// tint merah tua — satu-satunya elemen terang di layar adalah SOS,
  /// justru lebih menonjol daripada di tema lain. Inilah alasan D4
  /// melarang "filter merah di atas tema gelap".
  static const nightRed = AppTokens(
    surfaceBase: Color(0xFF000000),
    surfaceRaised: Color(0xFF160404),
    surfaceOverlay: Color(0xFF240808),
    contentPrimary: Color(0xFFFF6B5E),
    contentSecondary: Color(0xFFD6544A),
    contentMuted: Color(0xFFA84640),
    statusCritical: Color(0xFFFFE4E0),
    statusCriticalSurface: Color(0xFF7F1D1D),
    statusWarning: Color(0xFFFF9E80),
    statusWarningSurface: Color(0xFF331109),
    statusOk: Color(0xFFFFB4A8),
    statusOkSurface: Color(0xFF33120D),
    statusInactive: Color(0xFFAD4C45),
    statusInactiveSurface: Color(0xFF2B0F0C),
    accent: Color(0xFFFF8A80),
    onAccent: Color(0xFF2B0000),
  );

  @override
  AppTokens copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? contentPrimary,
    Color? contentSecondary,
    Color? contentMuted,
    Color? statusCritical,
    Color? statusCriticalSurface,
    Color? statusWarning,
    Color? statusWarningSurface,
    Color? statusOk,
    Color? statusOkSurface,
    Color? statusInactive,
    Color? statusInactiveSurface,
    Color? accent,
    Color? onAccent,
  }) {
    return AppTokens(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      contentPrimary: contentPrimary ?? this.contentPrimary,
      contentSecondary: contentSecondary ?? this.contentSecondary,
      contentMuted: contentMuted ?? this.contentMuted,
      statusCritical: statusCritical ?? this.statusCritical,
      statusCriticalSurface: statusCriticalSurface ?? this.statusCriticalSurface,
      statusWarning: statusWarning ?? this.statusWarning,
      statusWarningSurface: statusWarningSurface ?? this.statusWarningSurface,
      statusOk: statusOk ?? this.statusOk,
      statusOkSurface: statusOkSurface ?? this.statusOkSurface,
      statusInactive: statusInactive ?? this.statusInactive,
      statusInactiveSurface: statusInactiveSurface ?? this.statusInactiveSurface,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      contentPrimary: Color.lerp(contentPrimary, other.contentPrimary, t)!,
      contentSecondary: Color.lerp(contentSecondary, other.contentSecondary, t)!,
      contentMuted: Color.lerp(contentMuted, other.contentMuted, t)!,
      statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
      statusCriticalSurface:
          Color.lerp(statusCriticalSurface, other.statusCriticalSurface, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusWarningSurface:
          Color.lerp(statusWarningSurface, other.statusWarningSurface, t)!,
      statusOk: Color.lerp(statusOk, other.statusOk, t)!,
      statusOkSurface: Color.lerp(statusOkSurface, other.statusOkSurface, t)!,
      statusInactive: Color.lerp(statusInactive, other.statusInactive, t)!,
      statusInactiveSurface:
          Color.lerp(statusInactiveSurface, other.statusInactiveSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Skala jarak 4pt — satu-satunya nilai spacing yang boleh dipakai.
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radius — DUA nilai saja (strategi-ux.md §4.1). Enam radius liar hari
/// ini (4/8/12/16/20/24) adalah penyebab tunggal terbesar kesan prototipe.
class AppRadius {
  AppRadius._();
  static const double small = 8; // pill, badge, elemen kecil
  static const double card = 16; // kartu, sheet, dialog
}

/// Ukuran sentuh minimum — PERMANEN, bukan setting (keputusan ergonomi,
/// strategi-ux.md Lampiran A). Sarung tangan basah tidak membuka menu
/// pengaturan dulu.
class AppTouch {
  AppTouch._();
  static const double minTarget = 56;
}
