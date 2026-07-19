import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/connection_failure.dart';
import 'surface_card.dart';

/// Kartu kegagalan standar (Fase 1-F3a) — konsumen visual satu-satunya
/// untuk [ConnectionFailure] (kamus 0A-C2).
///
/// Kontrak prinsip "Gagal dengan terang": sebab dalam bahasa manusia +
/// SATU tombol aksi. technicalDetail TIDAK ditampilkan di sini —
/// tempatnya Live Log Viewer (Fase 6).
class FailureCard extends StatelessWidget {
  final ConnectionFailure failure;
  final VoidCallback onAction;

  const FailureCard({super.key, required this.failure, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: tokens.statusCritical, size: 24),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  failure.message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: tokens.contentPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                minimumSize: const Size.fromHeight(AppTouch.minTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              onPressed: onAction,
              child: Text(failure.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
