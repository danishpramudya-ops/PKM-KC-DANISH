import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/node_status.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/data_tone.dart';
import '../widgets/detail_row.dart';
import '../widgets/node_row.dart';
import '../widgets/node_visuals.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/surface_card.dart';
import 'node_detail_screen.dart';

/// Bottom sheet daftar node di atas peta (keputusan D2).
///
/// Tiga posisi: ringkas (ringkasan hitungan) → separuh (daftar node) →
/// penuh (+ kesehatan sistem & aktivitas). SYARAT WAJIB D2: setiap posisi
/// bisa dicapai lewat **ketukan** pada gagang, bukan hanya gestur tarik —
/// sarung tangan basah membuat gestur tarik tidak bisa diandalkan.
class NodeSheet extends StatefulWidget {
  final void Function(NodeStatus node) onFocusNode;

  const NodeSheet({super.key, required this.onFocusNode});

  @override
  State<NodeSheet> createState() => _NodeSheetState();
}

class _NodeSheetState extends State<NodeSheet> {
  final _controller = DraggableScrollableController();

  static const _snaps = [0.16, 0.48, 0.92];

  /// Filter peran — turunan dari segmented TEAMS/VICTIMS/RESOURCES di
  /// prototipe, diubah ke peran yang benar-benar ada di protokol.
  int? _roleFilter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleSnap() {
    final current = _controller.size;
    final next = _snaps.firstWhere(
      (s) => s > current + 0.02,
      orElse: () => _snaps.first,
    );
    _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final nodeRepo = context.watch<NodeRepository>();
    final all = _sortedForTriage(nodeRepo.nodes);
    final shown =
        _roleFilter == null ? all : all.where((n) => n.role == _roleFilter).toList();

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: _snaps[0],
      minChildSize: _snaps[0],
      maxChildSize: _snaps[2],
      snap: true,
      snapSizes: const [_snapMid],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surfaceRaised,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            border: Border(
              top: BorderSide(
                color: tokens.contentMuted.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _handle(tokens)),
              SliverToBoxAdapter(child: _summary(all)),
              if (all.isNotEmpty)
                SliverToBoxAdapter(child: _filterRow(tokens, all)),
              _nodeList(shown),
              SliverToBoxAdapter(child: _systemHealth(context, nodeRepo)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
            ],
          ),
        );
      },
    );
  }

  static const _snapMid = 0.48;

  /// Gagang: area ketuk 56dp penuh lebar — inilah pemenuhan syarat D2.
  Widget _handle(AppTokens tokens) {
    return Semantics(
      button: true,
      label: 'Ubah tinggi panel daftar node',
      child: InkWell(
        onTap: _cycleSnap,
        child: SizedBox(
          height: AppTouch.minTarget - 20,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.contentMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(List<NodeStatus> nodes) {
    final sar = nodes.where((n) => n.role == 1).length;
    final victims = nodes.where((n) => n.role == 2).length;
    final gateways = nodes.where((n) => n.role == 0).length;
    final sos = nodes.where((n) => n.isSos && n.isOnline).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.hiking_rounded,
              value: '$sar',
              label: 'SAR',
              tone: DataTone.accent,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: StatCard(
              icon: Icons.person_pin_circle_rounded,
              value: '$victims',
              label: 'Korban',
              tone: sos > 0 ? DataTone.critical : DataTone.neutral,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: StatCard(
              icon: Icons.cell_tower_rounded,
              value: '$gateways',
              label: 'Gateway',
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(AppTokens tokens, List<NodeStatus> all) {
    Widget chip(String label, int? role) {
      final selected = _roleFilter == role;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _roleFilter = role),
          showCheckmark: false,
          labelStyle: AppType.label.copyWith(
            color: selected ? tokens.onAccent : tokens.contentSecondary,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: tokens.surfaceOverlay,
          selectedColor: tokens.accent,
          side: BorderSide(
            color: selected
                ? tokens.accent
                : tokens.contentMuted.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Semua (${all.length})', null),
            chip('SAR', 1),
            chip('Korban', 2),
            chip('Gateway', 0),
          ],
        ),
      ),
    );
  }

  Widget _nodeList(List<NodeStatus> nodes) {
    if (nodes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.xl),
          child: Text('Tidak ada node pada filter ini.'),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      sliver: SliverList.separated(
        itemCount: nodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (context, i) {
          final node = nodes[i];
          return SurfaceCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.xs),
            onTap: () {
              widget.onFocusNode(node);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NodeDetailScreen(nodeId: node.id),
              ));
            },
            child: NodeRow(
              icon: nodeIcon(node),
              name: node.deviceId,
              meta: nodeMetaLine(node),
              tone: nodeTone(node),
              trailing: nodeStatusPill(node),
              onTap: () {
                widget.onFocusNode(node);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NodeDetailScreen(nodeId: node.id),
                ));
              },
            ),
          );
        },
      ),
    );
  }

  /// Panel "System Health" — diambil utuh dari prototipe Stitch, tapi hanya
  /// berisi data yang benar-benar kita punya (docs/sistem-komponen.md §6).
  Widget _systemHealth(BuildContext context, NodeRepository nodeRepo) {
    final connection = context.watch<ConnectionRepository>();
    final nodes = nodeRepo.nodes;

    final lastPacket = nodes.isEmpty
        ? null
        : nodes
            .map((n) => n.lastSeen)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    final bleOk = connection.status == ConnectionStatus.connected;
    final meshOk = lastPacket != null &&
        DateTime.now().difference(lastPacket).inSeconds < 30;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xl, AppSpace.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Kesehatan sistem'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Column(
              children: [
                DetailRow(
                  icon: Icons.bluetooth_connected_rounded,
                  label: 'Tautan BLE',
                  value: bleOk ? 'Aktif · MTU 247' : 'Terputus',
                  tone: bleOk ? DataTone.ok : DataTone.critical,
                  trailing: StatusPill(
                    label: bleOk ? 'OK' : 'Putus',
                    kind: bleOk ? StatusKind.ok : StatusKind.critical,
                  ),
                ),
                DetailRow(
                  icon: Icons.hub_rounded,
                  label: 'Mesh LoRa',
                  value: lastPacket == null
                      ? 'Belum ada paket'
                      : 'Paket terakhir ${formatRelativeTime(lastPacket)}',
                  tone: meshOk ? DataTone.ok : DataTone.warning,
                  trailing: StatusPill(
                    label: meshOk ? 'OK' : 'Sepi',
                    kind: meshOk ? StatusKind.ok : StatusKind.warning,
                  ),
                ),
                // GPS perangkat sendiri belum dibaca aplikasi (paket
                // geolokasi menyusul) — digambar redup, bukan dikarang.
                const DetailRow(
                  icon: Icons.my_location_rounded,
                  label: 'GPS saya',
                  value: '—',
                  dimmed: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Urutan triase: SOS aktif dulu, lalu online, lalu offline. Di dalam
  /// tiap kelompok, yang paling baru terdengar di atas.
  List<NodeStatus> _sortedForTriage(List<NodeStatus> nodes) {
    final list = [...nodes];
    int rank(NodeStatus n) {
      if (n.isSos && n.isOnline) return 0;
      if (n.isOnline) return 1;
      return 2;
    }

    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    return list;
  }
}
