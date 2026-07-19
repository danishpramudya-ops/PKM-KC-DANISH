import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/ble_constants.dart';
import '../ble/anchorpulse_ble_service.dart';
import '../models/mesh_packet.dart';
import '../models/node_status.dart';

/// Menjaga status semua node mesh yang diketahui node SAR yang terhubung.
/// Logikanya sengaja dibuat SAMA dengan dashboard/serial_listener.py:
///  - Heartbeat hanya me-refresh presence node yang SUDAH pernah terlihat.
///  - Paket dengan seq <= seq tersimpan dianggap lama/duplikat, diabaikan.
///  - Posisi/SOS hanya diperbarui oleh paket yang membawa lokasi (TRACKING/SOS).
class NodeRepository extends ChangeNotifier {
  final AnchorpulseBleService ble;
  final Map<int, NodeStatus> _nodes = {};
  StreamSubscription<String>? _sub;

  NodeRepository(this.ble) {
    _sub = ble.meshPacketStream.listen(_onRawPacket);
  }

  List<NodeStatus> get nodes {
    final list = _nodes.values.toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  List<NodeStatus> get positionedNodes =>
      nodes.where((n) => n.hasPosition).toList();

  void _onRawPacket(String raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return; // paket korup/terpotong, abaikan (bisa terjadi kalau MTU kurang)
    }

    const required = ['net', 'id', 'seq', 'type', 'hop'];
    if (!required.every(json.containsKey)) return;
    if (json['net'] != BleConstants.netId) return;

    final packet = MeshPacket.fromJson(json);
    final existing = _nodes[packet.id];

    if (packet.isHeartbeat) {
      // Heartbeat BOLEH membuat node baru (0B-B1). Tanpa ini, GATEWAY —
      // yang tidak pernah menyiarkan lokasi, hanya heartbeat — secara
      // struktural mustahil muncul di aplikasi; begitu pula node SAR/KORBAN
      // yang belum dapat fix GPS. Node buatan heartbeat tidak punya posisi,
      // jadi tampil di daftar ("Belum ada data lokasi") tapi TIDAK di peta —
      // dua-duanya jujur.
      //
      // PENTING: touch() sengaja TIDAK menyentuh seq. Firmware memakai satu
      // seqCounter untuk semua tipe paket — kalau heartbeat ikut menaikkan
      // baseline, paket TRACKING yang tiba belakangan lewat jalur multi-hop
      // lebih lambat bisa tertolak sebagai duplikat.
      final node = existing ?? NodeStatus(id: packet.id, role: packet.role);
      node.touch();
      _nodes[packet.id] = node;
      notifyListeners();
      return;
    }

    if (existing != null && packet.seq <= existing.seq) {
      return;
    }

    final node = existing ?? NodeStatus(id: packet.id, role: packet.role);
    node.applyPacket(packet);
    _nodes[packet.id] = node;
    notifyListeners();
  }

  /// Bersihkan semua data (dipanggil saat disconnect dari node SAR).
  void reset() {
    _nodes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
