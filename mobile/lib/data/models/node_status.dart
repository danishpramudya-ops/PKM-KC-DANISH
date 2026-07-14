import '../../core/constants/ble_constants.dart';
import 'mesh_packet.dart';

/// Status terkini satu node mesh, dibangun dari paket-paket MeshPacket yang
/// diterima lewat BLE. Setara dengan satu entry di dashboard/gps.json,
/// tapi dijaga langsung di memori HP (tidak lewat file perantara).
class NodeStatus {
  final int id;
  final int role;
  double? lat;
  double? lng;
  double? alt;
  double? spd;
  int? sats;
  bool? gpsValid;
  bool isSos;
  int seq;
  DateTime lastSeen;

  NodeStatus({
    required this.id,
    required this.role,
    this.lat,
    this.lng,
    this.alt,
    this.spd,
    this.sats,
    this.gpsValid,
    this.isSos = false,
    this.seq = 0,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get deviceId => '${roleNameFromId(id)}-$id';
  bool get hasPosition => lat != null && lng != null;

  bool get isOnline =>
      DateTime.now().difference(lastSeen) < BleConstants.offlineTimeout;

  /// Terapkan paket baru. Posisi/SOS HANYA disentuh oleh paket yang membawa
  /// lokasi (TRACKING/SOS) — heartbeat & chat cuma me-refresh lastSeen/seq,
  /// sama persis dengan logika dashboard/serial_listener.py.
  void applyPacket(MeshPacket p) {
    seq = p.seq;
    lastSeen = DateTime.now();
    if (p.hasLocation) {
      lat = p.lat;
      lng = p.lng;
      alt = p.alt;
      spd = p.spd;
      sats = p.sats;
      gpsValid = p.valid;
      isSos = p.isSos;
    }
  }

  /// Refresh presence saja (dipanggil untuk heartbeat pada node yang sudah ada).
  void touch() {
    lastSeen = DateTime.now();
  }
}
