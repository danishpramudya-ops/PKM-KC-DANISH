import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/node_status.dart';
import '../../data/repositories/node_repository.dart';

/// Peta sederhana menampilkan posisi node ber-GPS — OSM tanpa API key,
/// konsisten dengan dashboard web (dashboard/index.html pakai Leaflet+OSM).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _defaultCenter = LatLng(-7.953850, 112.614955);

  @override
  Widget build(BuildContext context) {
    final nodeRepo = context.watch<NodeRepository>();
    final positioned = nodeRepo.positionedNodes;

    final center = positioned.isNotEmpty
        ? LatLng(positioned.first.lat!, positioned.first.lng!)
        : _defaultCenter;

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 16),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pointrescue.app',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(markers: positioned.map(_buildMarker).toList()),
        if (positioned.isEmpty)
          const Align(
            alignment: Alignment.center,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Belum ada node dengan data lokasi'),
              ),
            ),
          ),
      ],
    );
  }

  Marker _buildMarker(NodeStatus node) {
    final online = node.isOnline;
    final sos = node.isSos && online;
    final color = sos ? AppColors.offline : (online ? AppColors.primary : Colors.grey);

    return Marker(
      point: LatLng(node.lat!, node.lng!),
      width: 42,
      height: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sos ? Icons.emergency : Icons.location_on, color: color, size: 32),
        ],
      ),
    );
  }
}
