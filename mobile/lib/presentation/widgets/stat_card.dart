import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import 'data_tone.dart';

/// Atom **StatCard** (docs/sistem-komponen.md §3.2) — ikon + angka mono
/// besar + label mikro. Hanya untuk hitungan sekilas ("5 Node · 4 Online ·
/// 1 SOS"). Maksimum 3 berdampingan di layar HP. Turunan `stat-card`
/// sidebar dashboard.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final DataTone tone;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.tone = DataTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, bg) = dataToneColors(tokens, tone);

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.md, horizontal: AppSpace.sm),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: tokens.contentMuted.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, size: 14, color: fg),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            value,
            style: AppType.data.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tokens.contentPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            label.toUpperCase(),
            style: AppType.overline.copyWith(color: tokens.contentMuted),
          ),
        ],
      ),
    );
  }
}
