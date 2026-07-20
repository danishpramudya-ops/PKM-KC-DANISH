import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

/// Keadaan memuat standar (Design Decision Document §12).
///
/// Aturan: **tidak ada spinner tanpa keterangan.** Setiap penantian harus
/// mengatakan apa yang sedang ditunggu — "Mencari node…", "Menyambungkan…".
/// Spinner telanjang memberi tahu bahwa sesuatu sedang terjadi tapi bukan
/// APA; di alat lapangan, relawan perlu tahu apakah menunggu itu masuk akal
/// atau ada yang salah.
class LoadingState extends StatelessWidget {
  final String label;
  final String? subtitle;

  const LoadingState({super.key, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.contentSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: tokens.contentMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Indikator memuat sebaris — untuk di dalam tombol atau baris, tempat
/// keterangannya sudah ada di sebelahnya.
class InlineSpinner extends StatelessWidget {
  final Color? color;
  final double size;

  const InlineSpinner({super.key, this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: color ?? AppTokens.of(context).accent,
      ),
    );
  }
}
