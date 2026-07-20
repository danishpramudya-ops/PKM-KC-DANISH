import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Nada warna ubin ikon untuk atom data (docs/sistem-komponen.md).
///
/// Aturan Tactical tetap berlaku: warna hanya menyampaikan status.
/// `neutral` untuk data biasa, `accent` untuk identitas/aksi utama,
/// sisanya memakai pasangan token status yang kontrasnya dijaga uji WCAG.
enum DataTone { neutral, ok, warning, critical, accent }

/// Pasangan (warna ikon, warna latar ubin) untuk sebuah [DataTone].
///
/// Latar `accent` diturunkan dari token accent dengan alpha 15% — pola yang
/// sama dengan tint dashboard (--orange-light). Ini latar ubin ikon
/// (non-teks), jadi tidak termasuk pasangan wajib uji kontras 4.5:1.
(Color, Color) dataToneColors(AppTokens tokens, DataTone tone) {
  return switch (tone) {
    DataTone.neutral => (tokens.contentMuted, tokens.surfaceOverlay),
    DataTone.ok => (tokens.statusOk, tokens.statusOkSurface),
    DataTone.warning => (tokens.statusWarning, tokens.statusWarningSurface),
    DataTone.critical => (tokens.statusCritical, tokens.statusCriticalSurface),
    DataTone.accent => (tokens.accent, tokens.accent.withValues(alpha: 0.15)),
  };
}
