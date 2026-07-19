import 'package:flutter/material.dart';

/// Skala tipografi POINTRESCUE (Fase 1-F2) — ENAM tingkat, tidak lebih.
/// Menggantikan 9 ukuran liar hari ini (10..32).
///
/// Nama fungsional, bukan ukuran — layar memilih berdasarkan peran teks.
/// Warna TIDAK diset di sini; ambil dari AppTokens saat dipakai.
class AppType {
  AppType._();

  static const String _family = 'Inter';

  /// Judul besar layar (mis. nama produk di Connect).
  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  /// Judul bagian/kartu.
  static const title = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Teks utama.
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Label tombol, header kolom, chip.
  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
  );

  /// Metadata kecil (waktu relatif, keterangan).
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Angka status: jarak, koordinat, RSSI, hitungan mundur.
  /// JetBrains Mono — mengikuti dashboard (keputusan pasca Brand Identity
  /// Audit), sehingga bentuk angka identik di kedua permukaan. Monospace
  /// inheren tabular: digit tidak bergoyang saat berubah cepat.
  /// tabularFigures dipertahankan sebagai jaring pengaman bila sistem
  /// jatuh ke font fallback proporsional. Dijaga uji lebar digit di
  /// test/core/theme/type_test.dart.
  static const data = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
