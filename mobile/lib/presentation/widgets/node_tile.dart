import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/node_status.dart';
import 'premium_card.dart';

/// Satu baris node di daftar — status online/offline + last seen
class NodeTile extends StatelessWidget {
  final NodeStatus node;
  final VoidCallback? onTap;

  const NodeTile({super.key, required this.node, this.onTap});

  @override
  Widget build(BuildContext context) {
    final online = node.isOnline;
    final sos = node.isSos && online;
    final statusColor = sos ? AppColors.offline : (online ? AppColors.success : Colors.grey);

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sos ? Icons.emergency : Icons.sensors,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.deviceId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                    ),
                    if (sos) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.offline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.hasPosition
                      ? '${node.lat!.toStringAsFixed(4)}, ${node.lng!.toStringAsFixed(4)}'
                          '${node.gpsValid == false ? '  (no fix)' : ''}'
                      : 'Belum ada data lokasi',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatRelativeTime(node.lastSeen),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.text.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
