/// UUID & konstanta BLE GATT service "ANCHORPULSE Bridge".
///
/// HARUS sama persis dengan yang didefinisikan di firmware:
/// firmware/point_rescue_SAR/point_rescue_SAR.ino (bagian "BLE BRIDGE").
/// Kalau salah satu diubah, ubah dua-duanya berbarengan.
class BleConstants {
  BleConstants._();

  static const String serviceUuid = '9c370001-3a1e-4f6a-9c37-a1b2c3d4e5f6';
  static const String nodeInfoUuid = '9c370002-3a1e-4f6a-9c37-a1b2c3d4e5f6';
  static const String meshRxUuid = '9c370003-3a1e-4f6a-9c37-a1b2c3d4e5f6';
  static const String chatTxUuid = '9c370004-3a1e-4f6a-9c37-a1b2c3d4e5f6';
  static const String chatRxUuid = '9c370005-3a1e-4f6a-9c37-a1b2c3d4e5f6';

  /// Prefix nama device saat advertising (lihat initBLE() di firmware SAR).
  static const String devicePrefix = 'ANCHORPULSE-SAR-';

  /// Harus sama dengan NET_ID firmware & NET_ID di dashboard/serial_listener.py.
  static const String netId = 'PR01';

  /// MTU yang diminta setelah connect, supaya paket JSON (tracking ~150 byte,
  /// chat maks 100 byte + overhead) muat dalam satu notifikasi BLE tanpa
  /// terpotong (default MTU BLE hanya ~23 byte).
  static const int requestedMtu = 247;

  /// Node dianggap OFFLINE bila tidak ada paket (termasuk heartbeat) selama
  /// ini — SAMA dengan ambang di dashboard/script.js (CONFIG.OFFLINE_TIMEOUT).
  static const Duration offlineTimeout = Duration(seconds: 60);
}

/// Tipe paket mesh — harus sama dengan enum PacketType di semua firmware.
class PktType {
  PktType._();

  static const int heartbeat = 0;
  static const int tracking = 1;
  static const int sos = 2;
  static const int chat = 3;
}

/// Nama role dari node id (id ~/ 1000) — sama dengan ROLE_NAMES di
/// dashboard/serial_listener.py dan roleName() di firmware.
String roleNameFromId(int nodeId) {
  switch (nodeId ~/ 1000) {
    case 0:
      return 'GATEWAY';
    case 1:
      return 'SAR';
    case 2:
      return 'KORBAN';
    default:
      return 'UNKNOWN';
  }
}
