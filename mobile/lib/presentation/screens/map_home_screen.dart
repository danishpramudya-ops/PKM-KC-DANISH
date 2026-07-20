import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../data/models/node_status.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/app_header.dart';
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
        _topBar(context, nodeRepo),
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

  /// Header brand + banner peringatan — mengikuti susunan Figma:
  /// TopAppBar 48dp, lalu banner kritis menempel tepat di bawahnya.
  Widget _topBar(BuildContext context, NodeRepository nodeRepo) {
    final connection = context.watch<ConnectionRepository>();
    final (label, kind) = switch (connection.status) {
      ConnectionStatus.connected => (
          'SAR-${connection.myNodeId ?? '?'}',
          StatusKind.ok,
        ),
      ConnectionStatus.reconnecting => (
          'Sambung ulang ${connection.reconnectAttempt}',
          StatusKind.critical,
        ),
      _ => ('Terputus', StatusKind.critical),
    };

    final sosNodes =
        nodeRepo.nodes.where((n) => n.isSos && n.isOnline).toList();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          AppHeader(trailing: StatusPill(label: label, kind: kind)),
          if (sosNodes.isNotEmpty) _alertBanner(context, sosNodes),
        ],
      ),
    );
  }

  /// Banner peringatan kritis — hanya muncul saat ADA SOS aktif. Diambil
  /// dari "Critical Alert Banner" Figma, tapi isinya kejadian nyata, bukan
  /// teks contoh.
  Widget _alertBanner(BuildContext context, List<NodeStatus> sosNodes) {
    final tokens = AppTokens.of(context);
    final text = sosNodes.length == 1
        ? 'SOS AKTIF: ${sosNodes.first.deviceId}'
        : 'SOS AKTIF: ${sosNodes.length} korban';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: tokens.statusCriticalSurface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: tokens.statusCritical, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: tokens.statusCritical),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              text,
              style: AppType.data.copyWith(
                fontSize: 12,
                color: tokens.statusCritical,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
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
      top: MediaQuery.of(context).padding.top + 96,
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

/// Marker peta berbentuk **pin** (32×40, atas membulat penuh, bawah radius
/// kecil) — bentuk yang sama dipakai semua peran, dibedakan warna token.
/// Mengikuti anatomi marker di Figma: pin berisi ikon, chip nama di
/// bawahnya, dan chip status di atasnya bila ada yang perlu diberitahukan.
///
/// SOS berdenyut — satu-satunya animasi berulang yang diizinkan aturan
/// gerak, karena gerakan di situ menyandikan urgensi.
class _NodeMarker extends StatelessWidget {
  final NodeStatus node;

  const _NodeMarker({required this.node});

  static const _pinShape = BorderRadius.only(
    topLeft: Radius.circular(999),
    topRight: Radius.circular(999),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(6),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (fg, _) = dataToneColors(tokens, nodeTone(node));
    final isSos = node.isSos && node.isOnline;
    final offline = !node.isOnline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 42,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (isSos)
                const Positioned(top: 1, child: _SosPulse(size: 38)),
              Container(
                width: 32,
                height: 40,
                decoration: BoxDecoration(
                  color: offline ? tokens.surfaceOverlay : fg,
                  borderRadius: _pinShape,
                  border: offline ? Border.all(color: fg, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(
                    nodeIcon(node),
                    size: 15,
                    color: offline ? fg : tokens.surfaceBase,
                  ),
                ),
              ),
            ],
          ),
        ),
        _chip(
          tokens,
          node.deviceId,
          borderColor: isSos || offline
              ? fg.withValues(alpha: 0.8)
              : tokens.contentMuted.withValues(alpha: 0.35),
          textColor: isSos ? fg : tokens.contentPrimary,
        ),
      ],
    );
  }

  Widget _chip(
    AppTokens tokens,
    String text, {
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: AppType.overline.copyWith(color: textColor, letterSpacing: 1.1),
      ),
    );
  }
}

class _SosPulse extends StatefulWidget {
  final double size;
  const _SosPulse({required this.size});

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
    final color = AppTokens.of(context).statusCritical;

    // Hormati pengaturan aksesibilitas sistem: tanpa gerak, denyut diganti
    // cincin statis — urgensi tetap tersampaikan lewat warna & bentuk.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
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
            width: widget.size * (0.55 + 0.45 * t),
            height: widget.size * (0.55 + 0.45 * t),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        );
      },
    );
  }
}
