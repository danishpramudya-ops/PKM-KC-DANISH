// Uji skala tipe (Fase 1-F2), khususnya jaminan F-AC4: gaya `data`
// benar-benar tabular — digit tidak bergoyang saat angka berubah.
//
// PENTING: flutter_test secara default merender dengan font Ahem yang
// SEMUA glyph-nya selebar sama — uji tabular akan lolos kosong. Maka font
// Inter asli dimuat eksplisit lewat FontLoader supaya pengukuran nyata.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/core/theme/app_type.dart';

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Muat Inter asli dari aset (jalur relatif ke root proyek mobile/).
    final loader = FontLoader('Inter');
    for (final f in [
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
    ]) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  group('AppType.data — tabular figures', () {
    test('semua digit selebar sama (1111 vs 9999 vs 0000)', () {
      final w1 = _textWidth('1111', AppType.data);
      final w9 = _textWidth('9999', AppType.data);
      final w0 = _textWidth('0000', AppType.data);
      expect(w1, closeTo(w9, 0.01),
          reason: 'digit 1 vs 9 beda lebar — tabular tidak aktif');
      expect(w0, closeTo(w9, 0.01));
    });

    test('string angka sama panjang = lebar sama (jarak/koordinat stabil)',
        () {
      final a = _textWidth('123.456789', AppType.data);
      final b = _textWidth('987.654321', AppType.data);
      expect(a, closeTo(b, 0.01));
    });
  });

  group('Skala tipe', () {
    test('enam tingkat, ukuran sesuai spesifikasi rencana §3', () {
      expect(AppType.display.fontSize, 28);
      expect(AppType.title.fontSize, 20);
      expect(AppType.body.fontSize, 16);
      expect(AppType.label.fontSize, 13);
      expect(AppType.caption.fontSize, 11);
      expect(AppType.data.fontSize, 15);
    });

    test('semua tingkat memakai Inter yang kini benar-benar terdaftar', () {
      for (final s in [
        AppType.display,
        AppType.title,
        AppType.body,
        AppType.label,
        AppType.caption,
        AppType.data,
      ]) {
        expect(s.fontFamily, 'Inter');
      }
    });
  });
}
