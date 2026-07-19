import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Keadaan kosong standar (Fase 1-F3a) — pengganti lima gaya empty state
/// berbeda hari ini.
///
/// Aturan bahasa (strategi-ux.md §3.2): teks berbicara bahasa relawan,
/// bukan bahasa mesin. "Belum ada anggota tim terdeteksi" — BUKAN
/// "Menunggu paket TRACKING/SOS pertama dari mesh". Istilah internal
/// (paket, heartbeat, seq) hanya boleh muncul di Developer Mode.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: tokens.contentMuted),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.contentSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: tokens.contentMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.xl),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppTouch.minTarget),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onAccent,
                    minimumSize:
                        const Size(AppTouch.minTarget * 2, AppTouch.minTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
