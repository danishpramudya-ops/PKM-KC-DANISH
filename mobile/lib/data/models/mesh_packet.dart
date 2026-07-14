import '../../core/constants/ble_constants.dart';

/// Representasi satu paket mesh mentah — field-nya sama persis dengan JSON
/// yang dikirim firmware (lihat docs/protokol-paket.md), TIDAK dimodifikasi.
class MeshPacket {
  final String net;
  final int id;
  final int seq;
  final int type;
  final int hop;
  final double? lat;
  final double? lng;
  final double? alt;
  final double? spd;
  final int? sats;
  final bool? valid;
  final String? msg;

  const MeshPacket({
    required this.net,
    required this.id,
    required this.seq,
    required this.type,
    required this.hop,
    this.lat,
    this.lng,
    this.alt,
    this.spd,
    this.sats,
    this.valid,
    this.msg,
  });

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return MeshPacket(
      net: json['net'] as String,
      id: json['id'] as int,
      seq: json['seq'] as int,
      type: json['type'] as int,
      hop: json['hop'] as int,
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      alt: asDouble(json['alt']),
      spd: asDouble(json['spd']),
      sats: json['sats'] as int?,
      valid: json['valid'] as bool?,
      msg: json['msg'] as String?,
    );
  }

  /// Sama seperti "hasLocation" di firmware/serial_listener.py — heartbeat
  /// & chat tidak membawa lokasi, tracking & SOS membawa.
  bool get hasLocation => lat != null && lng != null;

  int get role => id ~/ 1000;
  String get roleName => roleNameFromId(id);

  bool get isHeartbeat => type == PktType.heartbeat;
  bool get isTracking => type == PktType.tracking;
  bool get isSos => type == PktType.sos;
  bool get isChat => type == PktType.chat;
}
