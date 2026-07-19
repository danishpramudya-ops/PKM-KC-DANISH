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
  Timer? _presenceTimer;

  NodeRepository(this.ble) {
    _sub = ble.meshPacketStream.listen(_onRawPacket);
    // Tick presence (0B-B3): isOnline & teks waktu relatif dihitung dari
    // DateTime.now() saat widget dibangun, tapi TIDAK ADA yang memicu
    // rebuild saat waktu berlalu — notifyListeners hanya terpanggil saat
    // paket masuk. Saat seluruh mesh diam (justru momen paling genting),
    // UI membeku menampilkan "Online" + "baru saja" palsu selamanya.
    // Tick 5 dtk vs ambang offline 60 dtk = transisi terlihat maksimal
    // 5 dtk setelah ambang terlampaui. Biaya rebuild daftar <= 20 kartu
    // tak berarti dibanding radio BLE yang menyala terus.
    _presenceTimer = Timer.periodic(BleConstants.presenceTick, (_) {
      if (_nodes.isEmpty) return;
      notifyListeners();
    });
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
      // seq mundur = duplikat relay… ATAU node baru saja reboot (seqCounter
      // firmware mulai dari 0 lagi tiap boot). Tanpa pembeda ini, node yang
      // restart tertolak SEMUA paketnya sampai seq menyusul nilai lama —
      // tampil "Offline" berjam-jam padahal hidup dan mengirim posisi
      // (0B-B2; akar masalah yang sama dicatat di saran-tindaklanjut.txt
      // butir B2, solusi menyeluruhnya field "epoch" = perubahan protokol,
      // dilarang di Fase 0 — ini heuristik sisi aplikasi).
      //
      // Dua tanda reboot (cukup salah satu):
      //  - gap besar: duplikat relay sah paling banyak tertinggal ~hop
      //    limit (5); selisih >= rebootSeqGap hampir pasti reboot.
      //  - diam lama: node menghilang > rebootSilence lalu muncul dengan
      //    seq kecil — menangkap reboot saat seq lama masih kecil.
      // Batas yang diterima: reboot dengan seq kecil + jeda singkat tetap
      // membuang <= rebootSeqGap paket pertama (~20 dtk pada laju tracking
      // 5 dtk) — jauh lebih baik daripada berjam-jam.
      final gap = existing.seq - packet.seq;
      final silence = DateTime.now().difference(existing.lastSeen);
      final looksLikeReboot = gap >= BleConstants.rebootSeqGap ||
          silence > BleConstants.rebootSilence;
      if (!looksLikeReboot) {
        return; // duplikat relay asli — inti dedup controlled flooding
      }
      // Terima paket; applyPacket di bawah me-reset baseline seq.
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
    _presenceTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
