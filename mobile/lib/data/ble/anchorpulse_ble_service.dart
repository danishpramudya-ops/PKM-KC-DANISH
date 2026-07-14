import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';

/// Lapisan tipis di atas flutter_blue_plus, khusus untuk protokol
/// "ANCHORPULSE Bridge" (lihat docs/protokol-paket.md §8). Tidak ada logika
/// bisnis di sini — hanya scan/connect/baca/tulis/notify mentah. Parsing &
/// state ada di repositories/.
class AnchorpulseBleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _chNodeInfo;
  BluetoothCharacteristic? _chMeshRx;
  BluetoothCharacteristic? _chChatTx;
  BluetoothCharacteristic? _chChatRx;

  StreamSubscription<List<int>>? _meshRxSub;
  StreamSubscription<List<int>>? _chatRxSub;

  final _meshPacketController = StreamController<String>.broadcast();
  final _chatRawController = StreamController<String>.broadcast();

  /// JSON mentah tiap paket mesh (TRACKING/HEARTBEAT/SOS/CHAT) yang diterima
  /// node SAR ini dari LoRa — identik dengan yang dicetak firmware ke Serial.
  Stream<String> get meshPacketStream => _meshPacketController.stream;

  /// JSON mentah khusus notifikasi chat ({"id","role","msg"}).
  Stream<String> get chatRawStream => _chatRawController.stream;

  BluetoothDevice? get device => _device;

  bool get isConnected => _device != null;

  /// Status adapter Bluetooth HP saat ini — HARUS lewat stream (`.first`),
  /// BUKAN `FlutterBluePlus.adapterStateNow` langsung. `adapterStateNow` cuma
  /// nilai cache yang baru terisi setelah stream `adapterState` pernah
  /// didengarkan minimal sekali; dibaca langsung di cold start akan selalu
  /// `unknown` walau Bluetooth sebenarnya sudah menyala (ini penyebab bug
  /// "Bluetooth belum aktif" padahal sudah aktif).
  Future<BluetoothAdapterState> getAdapterState() => FlutterBluePlus.adapterState.first
      .timeout(const Duration(seconds: 5), onTimeout: () => BluetoothAdapterState.unknown);

  /// Minta sistem menyalakan Bluetooth (Android). Aman dipanggil kalau sudah on.
  Future<void> turnOnBluetooth() async {
    if (await getAdapterState() != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
  }

  /// Apakah satu hasil scan adalah node ANCHORPULSE.
  ///
  /// Dicek dua arah supaya TAHAN terhadap keterbatasan paket advertising ESP32
  /// (nama panjang + UUID 128-bit bisa melebihi 31 byte, sehingga salah satu
  /// bisa terpotong): cocok bila nama diawali "ANCHORPULSE-SAR-" ATAU
  /// service UUID yang di-advertise mengandung UUID ANCHORPULSE.
  static bool isAnchorpulse(ScanResult r) {
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : r.advertisementData.advName;
    if (name.startsWith(BleConstants.devicePrefix)) return true;
    return r.advertisementData.serviceUuids
        .any((g) => g.str128.toLowerCase() == BleConstants.serviceUuid);
  }

  /// Mulai scan TANPA filter platform (lebih andal untuk ESP32) — penyaringan
  /// node ANCHORPULSE dilakukan di Dart lewat [isAnchorpulse].
  Stream<List<ScanResult>> startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  Stream<BluetoothConnectionState> connectionStateOf(BluetoothDevice device) =>
      device.connectionState;

  /// Connect + discover service + subscribe ke MESH_RX & CHAT_RX.
  /// Melempar exception bila service/characteristic yang diharapkan tidak
  /// ditemukan (berarti device yang di-scan bukan node ANCHORPULSE yang benar).
  Future<void> connect(BluetoothDevice device) async {
    // `mtu:` di connect() otomatis me-request MTU lebih besar dari default
    // (~23 byte) begitu terhubung (Android), supaya paket JSON (tracking
    // ~150 byte) tidak terpotong dalam satu notifikasi.
    await device.connect(
      timeout: const Duration(seconds: 12),
      mtu: BleConstants.requestedMtu,
    );
    _device = device;

    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid.str128.toLowerCase() == BleConstants.serviceUuid,
      orElse: () => throw StateError(
        'Service ANCHORPULSE tidak ditemukan — pastikan ini node SAR dengan firmware ber-BLE.',
      ),
    );

    for (final c in service.characteristics) {
      final uuid = c.uuid.str128.toLowerCase();
      if (uuid == BleConstants.nodeInfoUuid) _chNodeInfo = c;
      if (uuid == BleConstants.meshRxUuid) _chMeshRx = c;
      if (uuid == BleConstants.chatTxUuid) _chChatTx = c;
      if (uuid == BleConstants.chatRxUuid) _chChatRx = c;
    }

    if (_chMeshRx != null) {
      await _chMeshRx!.setNotifyValue(true);
      _meshRxSub = _chMeshRx!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        _meshPacketController.add(utf8.decode(value, allowMalformed: true));
      });
    }

    if (_chChatRx != null) {
      await _chChatRx!.setNotifyValue(true);
      _chatRxSub = _chChatRx!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        _chatRawController.add(utf8.decode(value, allowMalformed: true));
      });
    }
  }

  /// Baca characteristic NODE_INFO sekali (id/net/role node SAR yang sedang
  /// terhubung) — dipakai untuk menandai pesan chat siapa "milik sendiri".
  Future<Map<String, dynamic>?> readNodeInfo() async {
    if (_chNodeInfo == null) return null;
    final value = await _chNodeInfo!.read();
    if (value.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Kirim teks chat ke node SAR lewat CHAT_TX. Firmware yang membungkusnya
  /// jadi paket PKT_CHAT dan meng-broadcast ke mesh (lihat originateChat()
  /// di firmware SAR).
  Future<void> sendChat(String text) async {
    final ch = _chChatTx;
    if (ch == null) {
      throw StateError('Belum terhubung ke node SAR (characteristic CHAT_TX tidak ada).');
    }
    await ch.write(utf8.encode(text), withoutResponse: false);
  }

  Future<void> disconnect() async {
    await _meshRxSub?.cancel();
    await _chatRxSub?.cancel();
    _meshRxSub = null;
    _chatRxSub = null;
    _chNodeInfo = null;
    _chMeshRx = null;
    _chChatTx = null;
    _chChatRx = null;
    final d = _device;
    _device = null;
    if (d != null) {
      await d.disconnect();
    }
  }

  void dispose() {
    _meshPacketController.close();
    _chatRawController.close();
  }
}
