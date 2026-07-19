import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Jenis-jenis kegagalan koneksi yang dikenali aplikasi.
///
/// Setiap jenis dipetakan ke pesan bahasa manusia + satu label aksi lewat
/// [ConnectionFailure.of]. TIDAK ADA e.toString() yang boleh sampai ke layar
/// (docs/fase-0a-implementation-plan.md §3, prinsip "Gagal dengan terang").
enum ConnectionFailureKind {
  /// Adapter Bluetooth HP mati / tidak tersedia.
  bluetoothOff,

  /// Izin BLUETOOTH_SCAN/CONNECT (atau lokasi di Android lama) ditolak.
  permissionDenied,

  /// Scan berakhir tanpa menemukan satu pun node POINTRESCUE.
  nodeNotFound,

  /// connect() melewati batas waktu — node tidak merespons.
  connectTimeout,

  /// Perangkat tersambung tapi service/characteristic ANCHORPULSE tidak ada.
  notPointrescueNode,

  /// Koneksi yang sudah jadi terputus di tengah jalan.
  connectionLost,

  /// Apa pun yang tidak bisa diklasifikasikan dengan yakin.
  unknown,
}

/// Kegagalan koneksi dalam bentuk yang boleh ditampilkan ke relawan.
class ConnectionFailure {
  final ConnectionFailureKind kind;

  /// Pesan bahasa manusia — inilah (dan hanya ini) yang ditampilkan widget.
  final String message;

  /// Label satu tombol aksi yang masuk akal untuk kegagalan ini.
  final String actionLabel;

  /// Detail teknis mentah (mis. e.toString()) — disimpan untuk log/Developer
  /// Mode (Fase 6), TIDAK PERNAH ditampilkan ke relawan.
  final String technicalDetail;

  const ConnectionFailure._({
    required this.kind,
    required this.message,
    required this.actionLabel,
    this.technicalDetail = '',
  });

  /// Buat kegagalan dari jenis yang sudah diketahui pemanggil.
  factory ConnectionFailure.of(
    ConnectionFailureKind kind, {
    String technicalDetail = '',
  }) {
    switch (kind) {
      case ConnectionFailureKind.bluetoothOff:
        return ConnectionFailure._(
          kind: kind,
          message: 'Bluetooth belum menyala.',
          actionLabel: 'Nyalakan Bluetooth',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.permissionDenied:
        return ConnectionFailure._(
          kind: kind,
          message: 'POINTRESCUE perlu izin Perangkat di Sekitar '
              'untuk menemukan node.',
          actionLabel: 'Buka Pengaturan',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.nodeNotFound:
        return ConnectionFailure._(
          kind: kind,
          message: 'Node tidak ditemukan. Pastikan node menyala dan '
              'jaraknya di bawah 10 meter.',
          actionLabel: 'Cari Lagi',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.connectTimeout:
        return ConnectionFailure._(
          kind: kind,
          message: 'Node tidak merespons. Dekatkan HP ke node, '
              'lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.notPointrescueNode:
        return ConnectionFailure._(
          kind: kind,
          message: 'Perangkat ini bukan node POINTRESCUE, atau '
              'firmware-nya belum mendukung aplikasi.',
          actionLabel: 'Pilih Node Lain',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.connectionLost:
        return ConnectionFailure._(
          kind: kind,
          message: 'Koneksi ke node terputus.',
          actionLabel: 'Sambungkan Ulang',
          technicalDetail: technicalDetail,
        );
      case ConnectionFailureKind.unknown:
        return ConnectionFailure._(
          kind: kind,
          message: 'Terjadi gangguan koneksi.',
          actionLabel: 'Coba Lagi',
          technicalDetail: technicalDetail,
        );
    }
  }

  /// Klasifikasikan exception jadi kegagalan yang dipahami relawan.
  ///
  /// Urutan pemeriksaan: TIPE dulu (stabil antar versi pustaka), pola string
  /// hanya lapis kedua. Yang tidak dikenal jatuh ke [ConnectionFailureKind.unknown]
  /// — jangan menebak, pesan menyesatkan lebih buruk daripada pesan netral.
  factory ConnectionFailure.fromException(Object e) {
    final detail = e.toString();

    // --- Lapis 1: tipe ---
    if (e is TimeoutException) {
      return ConnectionFailure.of(ConnectionFailureKind.connectTimeout,
          technicalDetail: detail);
    }
    if (e is StateError) {
      // AnchorpulseBleService.connect() melempar StateError saat service
      // ANCHORPULSE tidak ditemukan di perangkat yang tersambung.
      return ConnectionFailure.of(ConnectionFailureKind.notPointrescueNode,
          technicalDetail: detail);
    }
    if (e is FlutterBluePlusException) {
      // fbp 1.36.8: timeout connect dilempar sebagai FlutterBluePlusException
      // dengan code == FbpErrorCode.timeout.index (lib/src/utils.dart:16-21).
      if (e.code == FbpErrorCode.timeout.index) {
        return ConnectionFailure.of(ConnectionFailureKind.connectTimeout,
            technicalDetail: detail);
      }
      if (e.code == FbpErrorCode.adapterIsOff.index) {
        return ConnectionFailure.of(ConnectionFailureKind.bluetoothOff,
            technicalDetail: detail);
      }
      if (e.code == FbpErrorCode.deviceIsDisconnected.index) {
        return ConnectionFailure.of(ConnectionFailureKind.connectionLost,
            technicalDetail: detail);
      }
      // FlutterBluePlusException lain: lanjut ke pencocokan string di bawah.
    }

    // --- Lapis 2: pola string (konservatif) ---
    final text = detail.toLowerCase();
    if (text.contains('permission')) {
      return ConnectionFailure.of(ConnectionFailureKind.permissionDenied,
          technicalDetail: detail);
    }
    if (text.contains('bluetooth must be turned on') ||
        (text.contains('bluetooth') &&
            (text.contains('off') || text.contains('disabled')))) {
      return ConnectionFailure.of(ConnectionFailureKind.bluetoothOff,
          technicalDetail: detail);
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return ConnectionFailure.of(ConnectionFailureKind.connectTimeout,
          technicalDetail: detail);
    }
    if (text.contains('disconnect') || text.contains('not connected')) {
      return ConnectionFailure.of(ConnectionFailureKind.connectionLost,
          technicalDetail: detail);
    }

    return ConnectionFailure.of(ConnectionFailureKind.unknown,
        technicalDetail: detail);
  }
}
