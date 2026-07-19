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
    final reconnecting = connection.status == ConnectionStatus.reconnecting;
    final color = connected ? AppColors.success : AppColors.offline;
    // Status `reconnecting` diberi teks sendiri agar bar ini berkata jujur:
    // "sedang berusaha pulih (percobaan ke-N)", bukan sekadar "tidak
    // terhubung" (0A-C7). Warna & ikon tetap merah/putus — memang belum
    // tersambung, dan Fase 0 dilarang mengubah visual.
    final label = connected
        ? 'Terhubung ke node SAR-${connection.myNodeId ?? '?'}'
        : reconnecting
            ? 'Menyambungkan ulang… (percobaan ${connection.reconnectAttempt})'
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
