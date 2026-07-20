import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

/// Jenis status yang boleh disampaikan lewat warna — TIDAK ada nilai lain.
/// Ini penegakan aturan Tactical "warna hanya untuk status".
enum StatusKind { critical, warning, ok, inactive }

/// Badge status standar — pengganti tunggal untuk empat gaya badge berbeda
/// (Online/Offline, SOS, izin, versi).
///
/// **Setiap status membawa IKON, bukan hanya warna** (Design Decision
/// Document §6 A5): 8% pria mengalami buta warna merah-hijau, dan di alat
/// SAR perbedaan "aman" vs "darurat" tidak boleh bergantung pada satu
/// kanal persepsi. Bentuk ikon berbeda per status, bukan sekadar warna
/// ikon yang berbeda.
///
/// Warna SELALU pasangan token statusX + statusXSurface yang kontrasnya
/// dijaga uji otomatis.
class StatusPill extends StatelessWidget {
  final String label;
  final StatusKind kind;

  /// Ganti ikon bawaan bila konteksnya menuntut (mis. ikon denyut untuk
  /// koneksi hidup). Bentuknya tetap harus membedakan status, bukan hiasan.
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
  });

  /// Ikon baku per status — dipilih agar SILUETNYA berbeda jelas:
  /// centang (ok) · seru (peringatan) · segitiga (kritikal) · strip (mati).
  static IconData defaultIconFor(StatusKind kind) => switch (kind) {
        StatusKind.ok => Icons.check_rounded,
        StatusKind.warning => Icons.priority_high_rounded,
        StatusKind.critical => Icons.warning_rounded,
        StatusKind.inactive => Icons.remove_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, bg) = switch (kind) {
      StatusKind.critical => (tokens.statusCritical, tokens.statusCriticalSurface),
      StatusKind.warning => (tokens.statusWarning, tokens.statusWarningSurface),
      StatusKind.ok => (tokens.statusOk, tokens.statusOkSurface),
      StatusKind.inactive =>
        (tokens.statusInactive, tokens.statusInactiveSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIconFor(kind), size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppType.overline.copyWith(color: fg, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}
