import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

/// Atom **SectionHeader** (docs/sistem-komponen.md) — SATU-SATUNYA cara
/// memisahkan seksi: label mikro huruf besar berspasi. Tanpa garis
/// dekoratif, tanpa ikon judul.
class SectionHeader extends StatelessWidget {
  final String text;

  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(
        text.toUpperCase(),
        style: AppType.overline.copyWith(
          color: tokens.contentMuted,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}
