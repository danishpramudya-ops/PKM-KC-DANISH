import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

/// Header aplikasi — pin brand + wordmark POINTRESCUE, mengikuti
/// "Header - TopAppBar" di Figma (tinggi 48dp, garis bawah tipis,
/// wordmark ExtraBold rapat).
///
/// Wordmark di sini dirender sebagai TEKS, bukan aset gambar — sama
/// seperti di Figma. Aturan audit brand §2 (wordmark hanya sebagai
/// gambar) berlaku untuk momen identitas besar (splash/About); di
/// header operasional 48dp, aset bitmap justru pecah. Begitu berkas
/// wordmark transparan tersedia, header boleh memakainya.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Chip status opsional di kanan (mis. hitungan node, status koneksi).
  final Widget? trailing;

  const AppHeader({super.key, this.trailing});

  static const double _height = 48;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    // Wordmark memakai tint terang dari accent — persis peran #FFB695 di
    // Figma: lebih lembut dari oranye penuh, tetap terbaca kuat di gelap.
    final wordmarkColor = Color.lerp(tokens.accent, Colors.white, 0.45)!;

    return Container(
      height: _height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: tokens.surfaceBase,
        border: Border(
          bottom: BorderSide(
            color: tokens.contentMuted.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpace.lg),
          Image.asset('assets/logo.png', width: 22, height: 24),
          const SizedBox(width: AppSpace.sm),
          Text(
            'POINTRESCUE',
            style: AppType.display.copyWith(
              fontSize: 22,
              letterSpacing: -1.1,
              color: wordmarkColor,
            ),
          ),
          const Spacer(),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: AppSpace.lg),
          ],
        ],
      ),
    );
  }
}
