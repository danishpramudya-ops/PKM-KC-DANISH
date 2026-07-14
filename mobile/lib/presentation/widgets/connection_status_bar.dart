import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/connection_repository.dart';

/// Bar tipis penanda status koneksi BLE, dipakai di atas tiap layar utama.
class ConnectionStatusBar extends StatelessWidget {
  final ConnectionRepository connection;

  const ConnectionStatusBar({super.key, required this.connection});

  @override
  Widget build(BuildContext context) {
    final connected = connection.status == ConnectionStatus.connected;
    final color = connected ? AppColors.success : AppColors.offline;
    final label = connected
        ? 'Terhubung ke node SAR-${connection.myNodeId ?? '?'}'
        : 'Tidak terhubung';

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
