import 'package:flutter/material.dart';

import '../../core/utils/time_format.dart';
import '../../data/models/node_status.dart';
import 'data_tone.dart';
import 'status_pill.dart';

/// Bahasa visual bersama untuk node — dipakai peta, bottom sheet, dan layar
/// detail. Dipusatkan di sini supaya satu node tampil identik di mana pun
/// ia muncul (docs/sistem-komponen.md: satu bentuk induk, peran dibedakan
/// warna token).

/// Ikon peran. GATEWAY = tiang/relay, SAR = penolong, KORBAN = orang butuh
/// bantuan.
IconData nodeIcon(NodeStatus node) {
  if (node.isSos) return Icons.sos_rounded;
  return switch (node.role) {
    0 => Icons.cell_tower_rounded,
    1 => Icons.hiking_rounded,
    _ => Icons.person_pin_circle_rounded,
  };
}

/// Nada status: SOS aktif > offline > online.
DataTone nodeTone(NodeStatus node) {
  if (node.isSos && node.isOnline) return DataTone.critical;
  if (!node.isOnline) return DataTone.neutral;
  return node.role == 1 ? DataTone.accent : DataTone.ok;
}

/// Pill status — teks yang jujur, bukan hiasan.
StatusPill nodeStatusPill(NodeStatus node) {
  if (node.isSos && node.isOnline) {
    return const StatusPill(label: 'SOS', kind: StatusKind.critical);
  }
  if (!node.isOnline) {
    return const StatusPill(label: 'Offline', kind: StatusKind.inactive);
  }
  return const StatusPill(label: 'Online', kind: StatusKind.ok);
}

/// Baris meta mono di bawah nama node.
///
/// Node tanpa posisi (mis. GATEWAY yang hanya mengirim heartbeat) TIDAK
/// disembunyikan dan tidak dikarang koordinatnya — ia menyatakan apa adanya
/// bahwa lokasinya tidak diketahui (0B-B1, prinsip #1).
String nodeMetaLine(NodeStatus node, {String? distanceLabel}) {
  final seen = formatRelativeTime(node.lastSeen);
  if (!node.hasPosition) return 'Tanpa data lokasi · $seen';
  final prefix = node.isOnline ? '' : 'Terakhir ';
  final dist = distanceLabel != null ? '$distanceLabel · ' : '';
  return '$prefix$dist$seen';
}
