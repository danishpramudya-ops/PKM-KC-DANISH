import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';
import '../ble/anchorpulse_ble_service.dart';
import '../models/connection_failure.dart';

enum ConnectionStatus {
  idle,
  scanning,
  connecting,
  connected,

  /// Koneksi putus TANPA diminta pengguna; aplikasi sedang mencoba
  /// menyambung ulang otomatis dengan backoff (Fase 0A-C3).
  reconnecting,
  disconnected,
  error,
}

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

  /// Target sambung-ulang: node terakhir yang BERHASIL tersambung.
  /// Berbeda dari [connectedDevice] yang di-null-kan begitu koneksi putus.
  BluetoothDevice? _lastDevice;

  /// true bila pemutusan diminta pengguna lewat [disconnect] — pembeda KUNCI
  /// antara "putus sengaja" (jangan pernah sambung ulang) dan "putus tak
  /// sengaja" (sambung ulang otomatis). Tanpa bendera ini, sambung-ulang
  /// akan MELAWAN kehendak pengguna karena listener _connStateSub dan
  /// disconnect() sama-sama melihat event disconnected
  /// (docs/fase-0a-implementation-plan.md §4).
  bool _userInitiatedDisconnect = false;

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  /// Guard untuk callback async yang bisa selesai SETELAH dispose()
  /// (percobaan sambung-ulang bisa menggantung 12 dtk di ble.connect).
  bool _disposed = false;

  /// Nomor percobaan sambung-ulang yang sedang berjalan — dipakai teks
  /// "Menyambungkan ulang… (percobaan N)" di 0A-C7. 0 = tidak sedang
  /// menyambung ulang.
  int get reconnectAttempt => _reconnectAttempt;

  /// `FlutterBluePlus.isScanning` me-re-emit nilai terakhir saat di-subscribe
  /// (bisa `false` sebelum scan benar-benar mulai). Bendera ini memastikan
  /// hanya transisi true→false yang dianggap "scan berakhir".
  bool _scanHasStarted = false;

  Future<void> startScan() async {
    _cancelReconnect(); // memulai scan = meninggalkan sesi sambung-ulang
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
      _userInitiatedDisconnect = false; // sesi koneksi baru dimulai pengguna
      _reconnectAttempt = 0;
      _cancelReconnect();
      status = ConnectionStatus.connecting;
      notifyListeners();
      await stopScan();

      await _establishConnection(device);
      _lastDevice = device; // target sambung-ulang bila putus tak sengaja

      status = ConnectionStatus.connected;
      failure = null;
      notifyListeners();
    } catch (e) {
      status = ConnectionStatus.error;
      failure = ConnectionFailure.fromException(e);
      notifyListeners();
    }
  }

  /// Bagian koneksi yang SAMA untuk jalur manual ([connect]) dan
  /// sambung-ulang otomatis ([_attemptReconnect]): BLE connect + baca
  /// NODE_INFO + pasang pendengar status koneksi.
  Future<void> _establishConnection(BluetoothDevice device) async {
    await ble.connect(device);
    connectedDevice = device;

    final info = await ble.readNodeInfo();
    myNodeId = info != null ? info['id'] as int? : null;

    await _connStateSub?.cancel();
    _connStateSub = ble.connectionStateOf(device).listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _onDeviceDisconnected();
      }
    });
  }

  /// Dipanggil saat BLE melapor putus. Di sinilah "putus sengaja" dan
  /// "putus tak sengaja" berpisah jalan.
  void _onDeviceDisconnected() {
    if (_disposed) return;
    // Stream fbp bisa memancarkan event ganda / re-emit saat subscribe —
    // hanya transisi pertama dari connected yang diproses.
    if (status != ConnectionStatus.connected) return;

    _connStateSub?.cancel();
    _connStateSub = null;
    connectedDevice = null;

    if (_userInitiatedDisconnect || !BleConstants.autoReconnectEnabled) {
      // Diminta pengguna (atau sakelar fitur mati) → hormati: tetap putus.
      status = ConnectionStatus.disconnected;
      notifyListeners();
      return;
    }

    // Putus TAK sengaja → sembuhkan sendiri tanpa menunggu pengguna.
    failure = ConnectionFailure.of(ConnectionFailureKind.connectionLost);
    status = ConnectionStatus.reconnecting;
    notifyListeners();
    _scheduleReconnect();
  }

  /// Jadwalkan percobaan sambung-ulang berikutnya dengan backoff
  /// 1s → 2s → 4s → 8s → 16s → 30s (lalu tetap 30s, TANPA batas percobaan
  /// — menyerah diam-diam adalah mode kegagalan yang sedang kita hapus).
  void _scheduleReconnect() {
    _cancelReconnect();
    _reconnectAttempt++;
    _reconnectTimer = Timer(_backoffDelay(_reconnectAttempt), _attemptReconnect);
    notifyListeners(); // supaya "percobaan N" segar di UI (0A-C7)
  }

  Duration _backoffDelay(int attempt) {
    if (attempt >= 6) return BleConstants.reconnectMax;
    final seconds = BleConstants.reconnectInitial.inSeconds << (attempt - 1);
    final cap = BleConstants.reconnectMax.inSeconds;
    return Duration(seconds: seconds > cap ? cap : seconds);
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _attemptReconnect() async {
    if (_disposed || _userInitiatedDisconnect) return;
    if (status != ConnectionStatus.reconnecting) return;
    final device = _lastDevice;
    if (device == null) return;

    try {
      await _establishConnection(device);

      if (_disposed ||
          _userInitiatedDisconnect ||
          status != ConnectionStatus.reconnecting) {
        // Keadaan berubah SELAMA percobaan berlangsung (pengguna memutus /
        // memulai scan / app ditutup) — jangan lawan kehendak pengguna:
        // lepaskan lagi koneksi yang barusan jadi.
        await _connStateSub?.cancel();
        _connStateSub = null;
        try {
          await ble.disconnect();
        } catch (_) {}
        connectedDevice = null;
        return;
      }

      _reconnectAttempt = 0;
      failure = null;
      status = ConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      if (_disposed ||
          _userInitiatedDisconnect ||
          status != ConnectionStatus.reconnecting) {
        return;
      }
      // Kegagalan tiap percobaan BUKAN error senyap: detail terbaru selalu
      // tersimpan di failure.technicalDetail (dikonsumsi Log Viewer Fase 6);
      // UI cukup tahu "masih menyambung ulang, percobaan ke-N".
      failure = ConnectionFailure.of(ConnectionFailureKind.connectionLost,
          technicalDetail: e.toString());
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    // Bendera WAJIB diset sebelum ble.disconnect() — event disconnected yang
    // dipicu pemutusan ini tidak boleh dibaca sebagai "putus tak sengaja".
    _userInitiatedDisconnect = true;
    _cancelReconnect();
    _reconnectAttempt = 0;
    _lastDevice = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    await ble.disconnect();
    connectedDevice = null;
    myNodeId = null;
    status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _connStateSub?.cancel();
    super.dispose();
  }
}
