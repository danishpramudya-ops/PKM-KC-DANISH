import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/data_tone.dart';
import '../widgets/detail_row.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/surface_card.dart';

/// Mode pengembang — diagnostik BLE & mesh.
///
/// Sebelumnya layar ini berisi **12 tool yang semuanya memunculkan
/// "not implemented yet"**. Menu penuh jalan buntu terasa lebih murah
/// daripada tidak ada menu sama sekali (temuan audit awal), dan Design
/// Decision Document menetapkan hanya 4 tool yang benar-benar akan
/// dibangun (Fase 6).
///
/// Sampai Fase 6, layar ini menampilkan **diagnostik nyata yang sudah
/// bisa dibaca hari ini** — bukan tombol palsu — plus daftar tool yang
/// direncanakan dalam keadaan redup berlabel. Tidak ada yang berpura-pura
/// bisa diketuk.
class DeveloperModeScreen extends StatelessWidget {
  const DeveloperModeScreen({super.key});

  /// Empat tool yang disetujui untuk dibangun di Fase 6. Sisanya (8 tool
  /// di versi lama) dibuang, bukan disimpan sebagai placeholder.
  static const _plannedTools = [
    (Icons.article_outlined, 'Live Log Viewer', 'Log bergulir + filter'),
    (Icons.data_object_rounded, 'Raw Packet Inspector', 'JSON mentah tiap paket'),
    (Icons.science_outlined, 'Mock Data Generator', 'Uji UI tanpa perangkat'),
    (Icons.bluetooth_searching_rounded, 'BLE & Link Diagnostics', 'MTU, UUID, riwayat'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final connection = context.watch<ConnectionRepository>();
    final nodeRepo = context.watch<NodeRepository>();
    final connected = connection.status == ConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Mode pengembang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxl),
        children: [
          _warningCard(tokens),
          const SizedBox(height: AppSpace.xl),

          const SectionHeader('Status koneksi'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Column(
              children: [
                DetailRow(
                  icon: Icons.bluetooth_rounded,
                  label: 'Status BLE',
                  value: connection.status.name,
                  tone: connected ? DataTone.ok : DataTone.warning,
                  trailing: StatusPill(
                    label: connected ? 'Aktif' : 'Tidak aktif',
                    kind: connected ? StatusKind.ok : StatusKind.inactive,
                  ),
                ),
                DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Node ID saya',
                  value: connection.myNodeId?.toString() ?? '—',
                  dimmed: connection.myNodeId == null,
                ),
                DetailRow(
                  icon: Icons.replay_rounded,
                  label: 'Percobaan sambung ulang',
                  value: '${connection.reconnectAttempt}',
                ),
                if (connection.failure != null)
                  DetailRow(
                    icon: Icons.error_outline_rounded,
                    label: 'Kegagalan terakhir',
                    value: connection.failure!.kind.name,
                    tone: DataTone.critical,
                  ),
              ],
            ),
          ),

          if (connection.failure?.technicalDetail.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpace.xl),
            const SectionHeader('Detail teknis kegagalan'),
            SurfaceCard(
              child: SelectableText(
                connection.failure!.technicalDetail,
                style: AppType.data.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: tokens.contentSecondary,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Protokol'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Column(
              children: [
                const DetailRow(
                  icon: Icons.lan_rounded,
                  label: 'NET ID',
                  value: BleConstants.netId,
                ),
                const DetailRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'MTU diminta',
                  value: '${BleConstants.requestedMtu} byte',
                ),
                const DetailRow(
                  icon: Icons.short_text_rounded,
                  label: 'Batas pesan chat',
                  value: '${BleConstants.chatMaxBytes} byte',
                ),
                DetailRow(
                  icon: Icons.hub_rounded,
                  label: 'Node diketahui',
                  value: '${nodeRepo.nodes.length}',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Tool diagnostik · Fase 6'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Column(
              children: [
                for (final (icon, name, desc) in _plannedTools)
                  DetailRow(
                    icon: icon,
                    label: name,
                    value: desc,
                    dimmed: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Keempat tool di atas dibangun di Fase 6. Ditampilkan redup '
            'karena belum bisa dipakai — bukan tombol yang berpura-pura '
            'aktif.',
            style: AppType.caption.copyWith(color: tokens.contentMuted),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(AppTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: tokens.statusWarningSurface,
        border: Border.all(color: tokens.statusWarning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: tokens.statusWarning, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'Layar ini untuk mendiagnosis perangkat keras dan protokol '
              'POINTRESCUE. Bukan untuk dipakai saat operasi berlangsung.',
              style: AppType.caption.copyWith(
                color: tokens.statusWarning,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
