// Uji pembatas byte UTF-8 (Fase 0C-C2) — fungsi murni sesuai keputusan Q2.
//
// Jaminan terpenting: pemotongan TIDAK PERNAH membelah satu code point,
// sehingga hasilnya selalu UTF-8 valid dan firmware tidak pernah perlu
// memotong sendiri (pemotongan firmware pada batas byte mentah bisa
// menghasilkan karakter rusak).

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/core/utils/utf8_limit.dart';

void main() {
  group('utf8ByteLength', () {
    test('ASCII: 1 byte per karakter', () {
      expect(utf8ByteLength('abc'), 3);
    });

    test('aksen 2 byte, emoji 4 byte', () {
      expect(utf8ByteLength('é'), 2);
      expect(utf8ByteLength('😀'), 4);
    });
  });

  group('truncateUtf8', () {
    test('di bawah batas: identitas (tidak diubah)', () {
      final text = 'a' * 100;
      expect(truncateUtf8(text, 100), same(text));
    });

    test('ASCII 101 → dipotong ke 100 byte', () {
      final out = truncateUtf8('a' * 101, 100);
      expect(out.length, 100);
      expect(utf8ByteLength(out), 100);
    });

    test('aksen: 51 é (102 byte) → 50 é (100 byte), tanpa belah rune', () {
      final out = truncateUtf8('é' * 51, 100);
      expect(out, 'é' * 50);
      expect(utf8ByteLength(out), 100);
    });

    test('emoji: 26 😀 (104 byte) → 25 😀 (100 byte)', () {
      final out = truncateUtf8('😀' * 26, 100);
      expect(out, '😀' * 25);
      expect(utf8ByteLength(out), 100);
    });

    test('campuran: emoji tidak muat → ditolak UTUH, bukan dibelah', () {
      // 99 byte ASCII + emoji 4 byte = 103 → emoji harus hilang seluruhnya.
      final out = truncateUtf8('${'a' * 99}😀', 100);
      expect(out, 'a' * 99);
      expect(utf8ByteLength(out), 99); // bukan 100 — rune tak boleh dibelah
    });

    test('hasil selalu UTF-8 valid (round-trip decode ketat)', () {
      for (final sample in ['é' * 51, '😀' * 26, '${'a' * 98}é😀', 'halo']) {
        final out = truncateUtf8(sample, 100);
        // utf8.decode tanpa allowMalformed melempar bila byte rusak.
        expect(utf8.decode(utf8.encode(out)), out);
      }
    });
  });

  group('Utf8LengthLimitingFormatter', () {
    const formatter = Utf8LengthLimitingFormatter(10);

    test('di bawah batas: nilai lolos apa adanya', () {
      const v = TextEditingValue(text: 'halo');
      expect(formatter.formatEditUpdate(TextEditingValue.empty, v), same(v));
    });

    test('tempel melewati batas: dipotong pada batas rune', () {
      const v = TextEditingValue(text: 'ééééééééé'); // 9 é = 18 byte
      final out = formatter.formatEditUpdate(TextEditingValue.empty, v);
      expect(out.text, 'ééééé'); // 5 é = 10 byte
      expect(out.selection.baseOffset, out.text.length);
    });

    test('teks dalam komposisi IME dibiarkan lewat', () {
      const v = TextEditingValue(
        text: 'ééééééééé',
        composing: TextRange(start: 0, end: 9),
      );
      expect(formatter.formatEditUpdate(TextEditingValue.empty, v), same(v));
    });
  });
}
