import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Kartu standar POINTRESCUE (Fase 1-F3a) — pengganti tunggal untuk enam
/// gaya kartu liar hari ini (radius 4/8/12/16/20/24, elevation campur,
/// bayangan hardcoded) yang jadi penyebab terbesar kesan prototipe.
///
/// Kontrak (direvisi v4 "panel tegas", docs/sistem-komponen.md):
///  - radius SELALU AppRadius.card, permukaan SELALU token surfaceRaised
///  - border 1px halus (contentMuted 25%) — panel tegas ala dashboard,
///    bukan kaca; kedalaman dari perbedaan permukaan + border, BUKAN
///    bayangan hitam hardcoded (tak terlihat di tema gelap)
///  - bila interaktif (onTap != null), tinggi minimum AppTouch.minTarget —
///    sarung tangan adalah baseline, bukan mode
///
/// PremiumCard lama TIDAK dihapus dulu — layar bermigrasi per-alur di
/// Fase 2 (keputusan D-F3), lalu PremiumCard dipensiunkan.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final radius = BorderRadius.circular(AppRadius.card);

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpace.lg),
      child: child,
    );

    if (onTap != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTouch.minTarget),
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: radius,
        border: Border.all(
          color: tokens.contentMuted.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
