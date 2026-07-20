import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../data/models/node_status.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/data_tone.dart';
import '../widgets/empty_state.dart';
import '../widgets/node_visuals.dart';
import '../widgets/status_pill.dart';
import 'node_sheet.dart';

/// Layar rumah aplikasi: peta memenuhi layar, daftar node hidup sebagai
/// bottom sheet di atasnya (keputusan D1 + D2, docs/strategi-ux.md).
///
/// Elemen mengambang dibatasi DUA kelompok — chip status koneksi dan
/// tumpukan tombol peta (docs/sistem-komponen.md). Tidak ada tombol SOS
/// mengambang: aplikasi ini MENERIMA SOS, pemicunya tombol fisik di node
/// KORBAN (CLAUDE.md).
class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final _mapController = MapController();

  /// Pusat awal saat belum ada node berposisi: Malang, area uji proyek.
  static const _fallbackCenter = LatLng(-7.9539, 112.6148);

  bool _hasAutoCentered = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerOnNodes(List<NodeStatus> positioned) {
    if (positioned.isEmpty) return;
    if (positioned.length == 1) {
      final n = positioned.first;
      _mapController.move(LatLng(n.lat!, n.lng!), 16);
      return;
    }
    var minLat = positioned.first.lat!, maxLat = minLat;
    var minLng = positioned.first.lng!, maxLng = minLng;
    for (final n in positioned) {
      minLat = n.lat! < minLat ? n.lat! : minLat;
      maxLat = n.lat! > maxLat ? n.lat! : maxLat;
      minLng = n.lng! < minLng ? n.lng! : minLng;
      maxLng = n.lng! > maxLng ? n.lng! : maxLng;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.fromLTRB(48, 96, 48, 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final nodeRepo = context.watch<NodeRepository>();
    final positioned = nodeRepo.positionedNodes;

    // Sekali saja, saat node berposisi pertama muncul — setelah itu kendali
    // peta sepenuhnya milik relawan (tidak merebut pan/zoom-nya).
    if (!_hasAutoCentered && positioned.isNotEmpty) {
      _hasAutoCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOnNodes(positioned);
      });
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _fallbackCenter,
            initialZoom: 15,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pointrescue.mobile',
              // Peta offline (pre-download) dijadwalkan Fase 4 — sampai itu,
              // tanpa internet tile gagal dan hanya latar polos yang tampil.
              // Marker & sheet TETAP berfungsi penuh.
              tileBuilder: (context, tileWidget, tile) => tileWidget,
            ),
            MarkerLayer(markers: [for (final n in positioned) _marker(n)]),
          ],
        ),
        if (positioned.isEmpty) _emptyOverlay(tokens),
        _connectionChip(context),
        _mapButtons(tokens, positioned),
        NodeSheet(onFocusNode: (n) {
          if (n.hasPosition) _mapController.move(LatLng(n.lat!, n.lng!), 17);
        }),
      ],
    );
  }

  Marker _marker(NodeStatus node) {
    return Marker(
      point: LatLng(node.lat!, node.lng!),
      width: 132,
      height: 62,
      alignment: Alignment.topCenter,
      child: _NodeMarker(node: node),
    );
  }

  Widget _emptyOverlay(AppTokens tokens) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: tokens.surfaceBase.withValues(alpha: 0.82),
          child: const EmptyState(
            icon: Icons.travel_explore_rounded,
            title: 'Belum ada anggota tim terdeteksi',
            subtitle: 'Pastikan node lain sudah menyala dan berada '
                'dalam jangkauan mesh.',
          ),
        ),
      ),
    );
  }

  Widget _connectionChip(BuildContext context) {
    final connection = context.watch<ConnectionRepository>();
    final (label, kind) = switch (connection.status) {
      ConnectionStatus.connected => (
          'Terhubung · SAR-${connection.myNodeId ?? '?'}',
          StatusKind.ok,
        ),
      ConnectionStatus.reconnecting => (
          'Menyambungkan ulang… (percobaan ${connection.reconnectAttempt})',
          StatusKind.critical,
        ),
      _ => ('Tidak terhubung', StatusKind.critical),
    };

    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpace.sm,
      left: AppSpace.md,
      child: StatusPill(label: label, kind: kind),
    );
  }

  Widget _mapButtons(AppTokens tokens, List<NodeStatus> positioned) {
    Widget btn(IconData icon, VoidCallback onTap, String tooltip) => Tooltip(
          message: tooltip,
          child: Material(
            color: tokens.surfaceRaised.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: SizedBox(
                width: AppTouch.minTarget,
                height: AppTouch.minTarget,
                child: Icon(icon, color: tokens.contentSecondary, size: 22),
              ),
            ),
          ),
        );

    return Positioned(
      right: AppSpace.md,
      top: MediaQuery.of(context).padding.top + 56,
      child: Column(
        children: [
          btn(Icons.add_rounded, () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom + 1);
          }, 'Perbesar'),
          const SizedBox(height: AppSpace.sm),
          btn(Icons.remove_rounded, () {
            _mapController.move(
                _mapController.camera.center, _mapController.camera.zoom - 1);
          }, 'Perkecil'),
          const SizedBox(height: AppSpace.sm),
          btn(Icons.center_focus_strong_rounded,
              () => _centerOnNodes(positioned), 'Pusatkan ke semua node'),
        ],
      ),
    );
  }
}

/// Marker peta: satu bentuk induk, peran dibedakan warna token. SOS
/// berdenyut — satu-satunya animasi berulang yang diizinkan aturan gerak,
/// karena gerakan di situ menyandikan urgensi (docs/strategi-ux.md §4.4).
class _NodeMarker extends StatelessWidget {
  final NodeStatus node;

  const _NodeMarker({required this.node});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, _) = dataToneColors(tokens, nodeTone(node));
    final isSos = node.isSos && node.isOnline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isSos) _SosPulse(color: fg),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.surfaceBase.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.surfaceRaised.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tokens.contentMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            node.deviceId,
            style: AppType.overline.copyWith(color: tokens.contentPrimary),
          ),
        ),
      ],
    );
  }
}

class _SosPulse extends StatefulWidget {
  final Color color;
  const _SosPulse({required this.color});

  @override
  State<_SosPulse> createState() => _SosPulseState();
}

class _SosPulseState extends State<_SosPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hormati pengaturan aksesibilitas sistem: tanpa gerak, denyut diganti
    // cincin statis — urgensi tetap tersampaikan lewat warna & bentuk.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color, width: 2),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0) * 0.7,
          child: Container(
            width: 16 + 18 * t,
            height: 16 + 18 * t,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 2),
            ),
          ),
        );
      },
    );
  }
}
