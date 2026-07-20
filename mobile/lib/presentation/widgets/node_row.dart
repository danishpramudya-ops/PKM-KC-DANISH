import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import 'data_tone.dart';

/// Atom **NodeRow** (docs/sistem-komponen.md §3.3) — SATU-SATUNYA cara
/// menampilkan node dalam daftar: ubin peran + nama + meta mono + trailing
/// (StatusPill) + chevron bila bisa diketuk. Turunan `device-item` dashboard.
///
/// Urutan daftar selalu triase: SOS → online → offline (bukan urutan ID).
class NodeRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String meta;
  final DataTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  const NodeRow({
    super.key,
    required this.icon,
    required this.name,
    required this.meta,
    this.tone = DataTone.neutral,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, bg) = dataToneColors(tokens, tone);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTouch.minTarget),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppType.label.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.contentPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppType.data.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tokens.contentMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.sm),
            trailing!,
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_right, size: 20, color: tokens.contentMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: row,
      ),
    );
  }
}
