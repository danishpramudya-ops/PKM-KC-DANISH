import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/node_repository.dart';
import '../widgets/node_tile.dart';

/// Daftar semua node mesh yang diketahui node SAR yang terhubung — setara
/// dengan sidebar "Active Devices" di dashboard web.
class NodeListScreen extends StatelessWidget {
  const NodeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nodeRepo = context.watch<NodeRepository>();
    final nodes = nodeRepo.nodes;

    if (nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.router, size: 64, color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                'Belum ada node terlihat.\nMenunggu paket TRACKING/SOS pertama dari mesh...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nodes.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NodeTile(node: nodes[index]),
      ),
    );
  }
}
