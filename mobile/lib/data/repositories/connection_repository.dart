import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/anchorpulse_ble_service.dart';

enum ConnectionStatus { idle, scanning, connecting, connected, disconnected, error }

/// State koneksi BLE ke satu node SAR: scan -> connect -> baca NODE_INFO.
/// Layar (screens/) hanya membaca state ini lewat Provider, tidak menyentuh
/// AnchorpulseBleService langsung.
class ConnectionRepository extends ChangeNotifier {
  final AnchorpulseBleService ble;

  ConnectionRepository(this.ble);

  ConnectionStatus status = ConnectionStatus.idle;
  String? errorMessage;
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;

  /// NODE_ID node SAR yang sedang terhubung (dari characteristic NODE_INFO).
  /// Dipakai ChatRepository untuk menandai pesan "milik sendiri".
  int? myNodeId;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  Future<void> startScan() async {
    status = ConnectionStatus.scanning;
    scanResults = [];
    errorMessage = null;
    notifyListeners();

    await _scanSub?.cancel();
    _scanSub = ble.startScan().listen((results) {
      // Tampilkan HANYA node ANCHORPULSE (disaring di Dart, bukan di platform,
      // agar tahan keterbatasan advertising ESP32).
      scanResults = results.where(AnchorpulseBleService.isAnchorpulse).toList();
      notifyListeners();
    });
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
      errorMessage = e.toString();
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
    _connStateSub?.cancel();
    super.dispose();
  }
}
