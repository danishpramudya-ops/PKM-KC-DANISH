import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/anchorpulse_ble_service.dart';
import '../models/connection_failure.dart';

enum ConnectionStatus { idle, scanning, connecting, connected, disconnected, error }

/// State koneksi BLE ke satu node SAR: scan -> connect -> baca NODE_INFO.
/// Layar (screens/) hanya membaca state ini lewat Provider, tidak menyentuh
/// AnchorpulseBleService langsung.
class ConnectionRepository extends ChangeNotifier {
  final AnchorpulseBleService ble;

  ConnectionRepository(this.ble);

  ConnectionStatus status = ConnectionStatus.idle;

  /// Kegagalan terakhir dalam bahasa manusia (null bila tidak ada).
  /// Widget menampilkan failure.message — BUKAN e.toString().
  ConnectionFailure? failure;

  /// Shim kompatibilitas untuk layar lama — dihapus di 0A-C7.
  String? get errorMessage => failure?.message;

  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;

  /// NODE_ID node SAR yang sedang terhubung (dari characteristic NODE_INFO).
  /// Dipakai ChatRepository untuk menandai pesan "milik sendiri".
  int? myNodeId;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  /// `FlutterBluePlus.isScanning` me-re-emit nilai terakhir saat di-subscribe
  /// (bisa `false` sebelum scan benar-benar mulai). Bendera ini memastikan
  /// hanya transisi true→false yang dianggap "scan berakhir".
  bool _scanHasStarted = false;

  Future<void> startScan() async {
    status = ConnectionStatus.scanning;
    scanResults = [];
    failure = null;
    notifyListeners();

    await _scanSub?.cancel();
    _scanSub = ble.scanResults.listen((results) {
      // Tampilkan HANYA node ANCHORPULSE (disaring di Dart, bukan di platform,
      // agar tahan keterbatasan advertising ESP32).
      scanResults = results.where(AnchorpulseBleService.isAnchorpulse).toList();
      notifyListeners();
    });

    // Ini yang membuat status TIDAK PERNAH buntu di `scanning`: apa pun
    // penyebab scan berhenti (timeout 15 dtk, stopScan(), error platform),
    // FlutterBluePlus.isScanning memancarkan false dan kita kembali ke
    // keadaan yang bisa dipakai. Sebelumnya tidak ada satu pun jalur kode
    // yang mengembalikan status dari `scanning` — tombol pindai mati permanen.
    _scanHasStarted = false;
    await _isScanningSub?.cancel();
    _isScanningSub = ble.isScanningStream.listen(_onScanningChanged);

    try {
      await ble.startScan();
    } catch (e) {
      if (status != ConnectionStatus.scanning) return;
      status = ConnectionStatus.error;
      failure = ConnectionFailure.fromException(e);
      notifyListeners();
    }
  }

  void _onScanningChanged(bool scanning) {
    if (scanning) {
      _scanHasStarted = true;
      return;
    }
    if (!_scanHasStarted) return; // emisi awal sebelum scan mulai — abaikan
    if (status != ConnectionStatus.scanning) return; // sudah connect/putus dll.

    if (scanResults.isEmpty) {
      status = ConnectionStatus.error;
      failure = ConnectionFailure.of(ConnectionFailureKind.nodeNotFound);
    } else {
      status = ConnectionStatus.idle; // daftar hasil tetap tampil, bisa dipilih
    }
    notifyListeners();
  }

  /// Pastikan Bluetooth HP menyala sebelum scan. Kembalikan false bila user
  /// menolak/menyalakan gagal.
  Future<bool> ensureBluetoothOn() async {
    if (await ble.getAdapterState() == BluetoothAdapterState.on) return true;
    try {
      await ble.turnOnBluetooth();
      return await ble.getAdapterState() == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopScan() async {
    await ble.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    await _isScanningSub?.cancel();
    _isScanningSub = null;
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      status = ConnectionStatus.connecting;
      notifyListeners();
      await stopScan();

      await ble.connect(device);
      connectedDevice = device;

      final info = await ble.readNodeInfo();
      myNodeId = info != null ? info['id'] as int? : null;

      await _connStateSub?.cancel();
      _connStateSub = ble.connectionStateOf(device).listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          status = ConnectionStatus.disconnected;
          connectedDevice = null;
          notifyListeners();
        }
      });

      status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      status = ConnectionStatus.error;
      failure = ConnectionFailure.fromException(e);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _connStateSub?.cancel();
    await ble.disconnect();
    connectedDevice = null;
    myNodeId = null;
    status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _connStateSub?.cancel();
    super.dispose();
  }
}
