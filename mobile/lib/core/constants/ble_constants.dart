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

  // ------------------------------------------------------------------
  // Fase 0 — konstanta keandalan (docs/fase-0-handoff.md)
  // ------------------------------------------------------------------

  /// Durasi maksimum satu sesi scan BLE. Dipindahkan dari
  /// AnchorpulseBleService.startScan() — nilai tidak berubah.
  static const Duration scanTimeout = Duration(seconds: 15);

  /// Batas waktu connect() ke node SAR. Dipindahkan dari
  /// AnchorpulseBleService.connect() — nilai tidak berubah.
  static const Duration connectTimeout = Duration(seconds: 12);

  /// Jeda percobaan sambung-ulang otomatis pertama; digandakan tiap
  /// kegagalan (exponential backoff) sampai mentok di [reconnectMax].
  static const Duration reconnectInitial = Duration(seconds: 1);

  /// Batas atas jeda sambung-ulang otomatis — menjaga baterai saat node
  /// hilang lama, tanpa pernah menyerah selama app di depan.
  static const Duration reconnectMax = Duration(seconds: 30);

  /// Sakelar fitur sambung-ulang otomatis (Fase 0A-C3).
  /// false = kembali ke perilaku lama (putus ya putus) tanpa revert commit —
  /// jalur rollback tingkat-1 (docs/fase-0-handoff.md §10).
  static const bool autoReconnectEnabled = true;

  /// Selisih mundur seq minimal yang ditafsirkan sebagai node reboot
  /// (seqCounter firmware mulai dari 0 lagi tiap boot) — bukan duplikat
  /// relay. Duplikat multi-hop yang sah paling banyak tertinggal ~hop
  /// limit (5), jadi ambang ini di atasnya.
  static const int rebootSeqGap = 5;

  /// Jeda diam minimal yang membuat paket ber-seq mundur ditafsirkan
  /// sebagai reboot walau selisih seq-nya kecil.
  static const Duration rebootSilence = Duration(minutes: 2);

  /// Interval penyegaran presence di UI — tanpa tick ini badge Online dan
  /// teks waktu relatif membeku saat tidak ada paket masuk (Fase 0B-B3).
  static const Duration presenceTick = Duration(seconds: 5);

  /// Batas isi pesan chat dalam BYTE UTF-8 — HARUS sama dengan
  /// CHAT_MSG_MAX_LEN di firmware/point_rescue_SAR/point_rescue_SAR.ino.
  /// Firmware menghitung byte (String.length() Arduino), bukan karakter.
  static const int chatMaxBytes = 100;

  /// Batas tunggu echo lokal dari node SAR sebelum pesan chat dianggap
  /// gagal (Fase 0C-C3). Jauh di atas latensi BLE lokal yang normal.
  static const Duration chatEchoTimeout = Duration(seconds: 10);
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
