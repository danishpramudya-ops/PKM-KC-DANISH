// Uji kontras WCAG untuk lapisan token (Fase 1-F1a).
//
// Inilah "verifikasi, bukan kira-kira" dari strategi-ux.md §4.1: setiap
// pasangan warna wajib dihitung rasionya secara matematis. Nilai token yang
// gagal DIGESER sampai lolos — uji ini tidak pernah dilonggarkan tanpa
// keputusan terdokumentasi.
//
// Ambang per tema (keputusan D-F4, docs/fase-1-implementation-plan.md §10):
//  - terang & gelap: 4.5:1 (WCAG AA) untuk SEMUA pasangan
//  - malam-merah: 4.5:1 untuk jalur primer/kritikal/aksi,
//    3.0:1 (AA-Large) untuk sekunder/muted/status non-kritikal —
//    kompromi sadar: kontras penuh merusak adaptasi mata gelap yang
//    justru menjadi alasan keberadaan mode ini.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/core/theme/app_tokens.dart';

/// Rasio kontras WCAG 2.x — memakai Color.computeLuminance() bawaan
/// Flutter yang mengimplementasikan relative luminance persis per spec.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

class _Pair {
  final String name;
  final Color fg;
  final Color bg;
  final double minRatio;
  const _Pair(this.name, this.fg, this.bg, this.minRatio);
}

List<_Pair> _pairsFor(String theme, AppTokens t, {required bool nightRed}) {
  // Jalur primer/kritikal/aksi wajib AA penuh di SEMUA tema, termasuk
  // malam-merah. Yang boleh turun ke AA-Large di malam-merah hanya jalur
  // sekunder (D-F4).
  const aa = 4.5;
  final secondary = nightRed ? 3.0 : 4.5;

  final surfaces = {
    'surfaceBase': t.surfaceBase,
    'surfaceRaised': t.surfaceRaised,
    'surfaceOverlay': t.surfaceOverlay,
  };

  final pairs = <_Pair>[];
  surfaces.forEach((sName, s) {
    pairs.add(_Pair('$theme contentPrimary/$sName', t.contentPrimary, s, aa));
    pairs.add(
        _Pair('$theme contentSecondary/$sName', t.contentSecondary, s, secondary));
    pairs.add(_Pair('$theme contentMuted/$sName', t.contentMuted, s, secondary));
    pairs.add(_Pair('$theme statusCritical/$sName', t.statusCritical, s, aa));
    pairs.add(
        _Pair('$theme statusWarning/$sName', t.statusWarning, s, secondary));
    pairs.add(_Pair('$theme statusOk/$sName', t.statusOk, s, secondary));
    pairs.add(
        _Pair('$theme statusInactive/$sName', t.statusInactive, s, secondary));
  });

  // Pasangan pill: statusX di atas tint-nya sendiri.
  pairs.add(_Pair('$theme statusCritical/criticalSurface', t.statusCritical,
      t.statusCriticalSurface, aa));
  pairs.add(_Pair('$theme statusWarning/warningSurface', t.statusWarning,
      t.statusWarningSurface, secondary));
  pairs.add(
      _Pair('$theme statusOk/okSurface', t.statusOk, t.statusOkSurface, secondary));
  pairs.add(_Pair('$theme statusInactive/inactiveSurface', t.statusInactive,
      t.statusInactiveSurface, secondary));

  // Aksi utama selalu jalur AA penuh — tombol adalah alat kerja.
  pairs.add(_Pair('$theme onAccent/accent', t.onAccent, t.accent, aa));

  return pairs;
}

void main() {
  final allPairs = [
    ..._pairsFor('terang', AppTokens.light, nightRed: false),
    ..._pairsFor('gelap', AppTokens.dark, nightRed: false),
    ..._pairsFor('malam-merah', AppTokens.nightRed, nightRed: true),
  ];

  group('Kontras token WCAG', () {
    for (final p in allPairs) {
      test(p.name, () {
        final ratio = contrastRatio(p.fg, p.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(p.minRatio),
          reason: '${p.name}: rasio ${ratio.toStringAsFixed(2)} '
              '< ${p.minRatio} — geser nilai tokennya, jangan longgarkan uji.',
        );
      });
    }
  });

  group('Sanity helper', () {
    test('hitam/putih = 21:1', () {
      expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21.0, 0.01));
    });
    test('warna identik = 1:1', () {
      expect(contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
          closeTo(1.0, 0.001));
    });
  });
}
