import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Jenis status yang boleh disampaikan lewat warna — TIDAK ada nilai lain.
/// Ini penegakan aturan Tactical "warna hanya untuk status".
enum StatusKind { critical, warning, ok, inactive }

/// Badge status standar (Fase 1-F3a) — pengganti tunggal untuk empat gaya
/// badge berbeda hari ini (Online/Offline, SOS, izin, versi).
///
/// Warna SELALU pasangan token statusX + statusXSurface yang kontrasnya
/// dijaga uji otomatis — menggantikan pola `warna.withOpacity(0.1)` yang
/// tidak pernah diverifikasi.
class StatusPill extends StatelessWidget {
  final String label;
  final StatusKind kind;

  const StatusPill({super.key, required this.label, required this.kind});

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
          horizontal: AppSpace.md, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
