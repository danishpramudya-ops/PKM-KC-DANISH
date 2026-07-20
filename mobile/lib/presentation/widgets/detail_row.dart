import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import 'data_tone.dart';

/// Atom **DataRow** (docs/sistem-komponen.md §3.1) — atom terpenting.
///
/// Ubin ikon + label mikro huruf besar + nilai MONO. Semua data numerik di
/// seluruh aplikasi memakai baris ini — koordinat, kecepatan, RSSI, baterai,
/// versi. Tanpa pengecualian. Turunan langsung `detail-item` dashboard
/// (panel kanannya adalah baris ini diulang enam kali — itulah "solid").
///
/// Dinamai `DetailRow` di kode karena Flutter Material sudah punya kelas
/// `DataRow` (bagian DataTable) — memakai nama sama memaksa setiap layar
/// menulis `hide DataRow` saat mengimpor material. Nama ini justru mengikuti
/// asal-usulnya: `detail-item`.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final DataTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Untuk data yang BELUM tersedia di protokol (mis. sinyal/baterai
  /// menunggu Fase 5): baris digambar redup dengan nilai "—". Prinsip #1 —
  /// jangan pernah menampilkan angka yang tidak bisa dibuktikan.
  final bool dimmed;

  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = DataTone.neutral,
    this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, bg) = dataToneColors(tokens, tone);

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTouch.minTarget),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppType.overline.copyWith(color: tokens.contentMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppType.data.copyWith(color: tokens.contentPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (dimmed) {
      row = Opacity(opacity: 0.5, child: row);
    }

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
