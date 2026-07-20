import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/node_status.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/data_tone.dart';
import '../widgets/detail_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/meter_bar.dart';
import '../widgets/node_row.dart';
import '../widgets/node_visuals.dart';
import '../widgets/section_header.dart';
import '../widgets/surface_card.dart';

/// Layar detail node — rumah bagi seluruh informasi & aksi satu node.
///
/// Layar ini SEBELUMNYA TIDAK ADA: kartu node memberi efek riak tapi tidak
/// melakukan apa pun (temuan audit). Tanpa layar ini, fitur Fase 5
/// (navigasi, klaim, sinyal, baterai) tidak punya tempat tinggal.
///
/// Menerima [nodeId], bukan objek NodeStatus, supaya isinya ikut hidup
/// saat paket baru datang — bukan potret beku saat layar dibuka.
class NodeDetailScreen extends StatelessWidget {
  final int nodeId;

  const NodeDetailScreen({super.key, required this.nodeId});

  @override
  Widget build(BuildContext context) {
    final nodeRepo = context.watch<NodeRepository>();
    NodeStatus? node;
    for (final n in nodeRepo.nodes) {
      if (n.id == nodeId) node = n;
    }

    if (node == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail node')),
        body: const EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Node tidak lagi dikenal',
          subtitle: 'Data node ini terhapus saat koneksi disetel ulang.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(node.deviceId)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
        children: [
          _header(context, node),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Posisi'),
          _positionCard(node),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Tautan LoRa'),
          _loraCard(context),
          const SizedBox(height: AppSpace.xl),
          _actions(context, node),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, NodeStatus node) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      child: NodeRow(
        icon: nodeIcon(node),
        name: node.deviceId,
        meta: '${_roleLabel(node.role)} · '
            '${formatRelativeTime(node.lastSeen)}',
        tone: nodeTone(node),
        trailing: nodeStatusPill(node),
      ),
    );
  }

  Widget _positionCard(NodeStatus node) {
    if (!node.hasPosition) {
      // GATEWAY (dan node yang belum dapat fix GPS) memang tidak membawa
      // lokasi — dinyatakan apa adanya, tidak disembunyikan (0B-B1).
      return const SurfaceCard(
        child: DetailRow(
          icon: Icons.location_off_rounded,
          label: 'Koordinat',
          value: 'Tidak tersedia',
          dimmed: true,
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.place_rounded,
            label: 'Koordinat',
            value: '${node.lat!.toStringAsFixed(6)}, '
                '${node.lng!.toStringAsFixed(6)}',
            tone: DataTone.accent,
          ),
          DetailRow(
            icon: Icons.satellite_alt_rounded,
            label: 'Satelit',
            value: node.sats == null
                ? '—'
                : '${node.sats}${node.gpsValid == true ? ' · fix valid' : ' · belum fix'}',
            tone: node.gpsValid == true ? DataTone.ok : DataTone.warning,
          ),
          DetailRow(
            icon: Icons.speed_rounded,
            label: 'Kecepatan',
            value: node.spd == null
                ? '—'
                : '${node.spd!.toStringAsFixed(1)} m/s',
          ),
          DetailRow(
            icon: Icons.terrain_rounded,
            label: 'Ketinggian',
            value: node.alt == null
                ? '—'
                : '${node.alt!.toStringAsFixed(0)} m',
          ),
        ],
      ),
    );
  }

  /// Panel LoRa Link — ide bagus dari prototipe Stitch, digambar ulang
  /// dengan atom kita. Datanya (RSSI/SNR/SF/baterai) BELUM dibawa protokol;
  /// dijadwalkan Fase 5 bersama perubahan firmware. Sampai itu ia tampil
  /// redup dengan nilai "—" — menampilkan angka contoh di alat SAR adalah
  /// risiko keselamatan, bukan sekadar kosmetik (prinsip #1).
  Widget _loraCard(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MeterBar(
            label: 'Kualitas link',
            valueText: '—',
            fraction: null,
          ),
          const SizedBox(height: AppSpace.md),
          const DetailRow(
            icon: Icons.network_check_rounded,
            label: 'RSSI · SNR',
            value: '—',
            dimmed: true,
          ),
          const DetailRow(
            icon: Icons.battery_std_rounded,
            label: 'Baterai node',
            value: '—',
            dimmed: true,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Data sinyal & baterai menyusul di Fase 5 bersama pembaruan '
            'firmware.',
            style: AppType.caption.copyWith(
              color: AppTokens.of(context).contentMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, NodeStatus node) {
    final canNavigate = node.hasPosition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canNavigate ? () => _soon(context, 'Navigasi kompas') : null,
          icon: const Icon(Icons.explore_rounded),
          label: const Text('Navigasi ke sini'),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(
          onPressed: () => _soon(context, 'Klaim "Saya tangani"'),
          child: const Text('Saya tangani'),
        ),
      ],
    );
  }

  void _soon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature dibangun di Fase 5.')),
    );
  }

  String _roleLabel(int role) => switch (role) {
        0 => 'Node gateway',
        1 => 'Node SAR',
        2 => 'Node korban',
        _ => 'Node tidak dikenal',
      };
}
