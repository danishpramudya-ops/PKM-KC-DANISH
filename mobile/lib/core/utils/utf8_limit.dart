import 'dart:convert';

import 'package:flutter/services.dart';

/// Pembatas panjang pesan dalam BYTE UTF-8, bukan karakter (Fase 0C-C2).
///
/// Kenapa byte: firmware membatasi chat ke CHAT_MSG_MAX_LEN *byte*
/// (String.length() Arduino) dan MEMOTONG pada batas byte mentah
/// (originateChat di point_rescue_SAR.ino) — pemotongan itu bisa membelah
/// satu karakter multi-byte (aksen 2 byte, emoji 4 byte) dan menghasilkan
/// UTF-8 rusak yang tampil sebagai karakter pengganti di layar. Dengan
/// menegakkan batas byte di sisi aplikasi, firmware tidak pernah lagi
/// perlu memotong.

/// Panjang [text] dalam byte UTF-8.
int utf8ByteLength(String text) => utf8.encode(text).length;

/// Potong [text] supaya muat dalam [maxBytes] byte UTF-8, TANPA PERNAH
/// membelah satu code point (rune) di tengah. Fungsi murni — diuji di
/// test/core/utils/utf8_limit_test.dart.
String truncateUtf8(String text, int maxBytes) {
  if (utf8ByteLength(text) <= maxBytes) return text;

  var usedBytes = 0;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final runeBytes = _utf8BytesForRune(rune);
    if (usedBytes + runeBytes > maxBytes) break;
    buffer.writeCharCode(rune);
    usedBytes += runeBytes;
  }
  return buffer.toString();
}

/// Lebar UTF-8 satu code point — tabel standar RFC 3629.
int _utf8BytesForRune(int rune) {
  if (rune < 0x80) return 1;
  if (rune < 0x800) return 2;
  if (rune < 0x10000) return 3;
  return 4;
}

/// TextInputFormatter yang menegakkan batas byte UTF-8 pada TextField.
///
/// Teks yang sedang dalam komposisi IME dibiarkan lewat (memotong di
/// tengah komposisi merusak input method); penegakan terjadi begitu
/// komposisi selesai, plus lapis kedua di ChatRepository.send().
class Utf8LengthLimitingFormatter extends TextInputFormatter {
  final int maxBytes;

  const Utf8LengthLimitingFormatter(this.maxBytes);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid) return newValue;
    if (utf8ByteLength(newValue.text) <= maxBytes) return newValue;

    final truncated = truncateUtf8(newValue.text, maxBytes);
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}
