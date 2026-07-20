import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import 'data_tone.dart';

/// Atom **MeterBar** (docs/sistem-komponen.md §3.4) — SATU bahasa untuk
/// semua kuantitas: sinyal, baterai, progres. Menggantikan tiga bahasa bar
/// berbeda di prototipe (92% ▮▮▮▮ vs bar vs diagram batang).
///
/// Warna isian mengikuti [tone] — ambang statusnya diputuskan pemanggil
/// (mis. baterai <20% = critical), bukan di sini.
class MeterBar extends StatelessWidget {
  final String label;

  /// Teks nilai di kanan (mono), mis. "78%" atau "—" saat tidak diketahui.
  final String valueText;

  /// 0..1. Null = tidak diketahui → track kosong (prinsip #1: jangan
  /// mengarang isi bar untuk data yang tidak ada).
  final double? fraction;

  final DataTone tone;

  const MeterBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.fraction,
    this.tone = DataTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, _) = dataToneColors(tokens, tone);
    final captionStyle = AppType.data.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: tokens.contentMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: captionStyle),
            Text(valueText, style: captionStyle),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          // Radius = setengah tinggi track (kapsul), bukan nilai radius baru.
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: tokens.surfaceOverlay,
            child: fraction == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction!.clamp(0.0, 1.0),
                      child: Container(color: fg),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
