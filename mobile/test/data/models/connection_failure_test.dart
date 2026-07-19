// Uji kamus kegagalan koneksi (Fase 0A-C2).
//
// Ini satu-satunya bagian 0A yang diuji otomatis (keputusan Q2,
// docs/fase-0a-implementation-plan.md §9) — fungsi murni, tanpa BLE.

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/data/models/connection_failure.dart';

void main() {
  group('ConnectionFailure.fromException — lapis tipe', () {
    test('TimeoutException → connectTimeout', () {
      final f = ConnectionFailure.fromException(
          TimeoutException('connect', const Duration(seconds: 12)));
      expect(f.kind, ConnectionFailureKind.connectTimeout);
    });

    test('StateError (service tidak ditemukan) → notPointrescueNode', () {
      final f = ConnectionFailure.fromException(
          StateError('Service ANCHORPULSE tidak ditemukan'));
      expect(f.kind, ConnectionFailureKind.notPointrescueNode);
    });

    test('FlutterBluePlusException code timeout → connectTimeout', () {
      final f = ConnectionFailure.fromException(FlutterBluePlusException(
          ErrorPlatform.fbp,
          'connect',
          FbpErrorCode.timeout.index,
          'Timed out after 12s'));
      expect(f.kind, ConnectionFailureKind.connectTimeout);
    });

    test('FlutterBluePlusException adapterIsOff → bluetoothOff', () {
      final f = ConnectionFailure.fromException(FlutterBluePlusException(
          ErrorPlatform.fbp,
          'connect',
          FbpErrorCode.adapterIsOff.index,
          'Bluetooth must be turned on'));
      expect(f.kind, ConnectionFailureKind.bluetoothOff);
    });

    test('FlutterBluePlusException deviceIsDisconnected → connectionLost', () {
      final f = ConnectionFailure.fromException(FlutterBluePlusException(
          ErrorPlatform.fbp,
          'readCharacteristic',
          FbpErrorCode.deviceIsDisconnected.index,
          'device is not connected'));
      expect(f.kind, ConnectionFailureKind.connectionLost);
    });
  });

  group('ConnectionFailure.fromException — lapis string', () {
    test('teks "permission" → permissionDenied', () {
      final f = ConnectionFailure.fromException(
          Exception('BLUETOOTH_SCAN permission denied by user'));
      expect(f.kind, ConnectionFailureKind.permissionDenied);
    });

    test('teks bluetooth off → bluetoothOff', () {
      final f = ConnectionFailure.fromException(
          Exception('bluetooth adapter is off'));
      expect(f.kind, ConnectionFailureKind.bluetoothOff);
    });

    test('teks "timed out" (bukan "timeout") tetap tertangkap', () {
      final f =
          ConnectionFailure.fromException(Exception('Timed out after 35s'));
      expect(f.kind, ConnectionFailureKind.connectTimeout);
    });

    test('teks disconnected → connectionLost', () {
      final f = ConnectionFailure.fromException(
          Exception('PlatformException(connect, device is not connected, '
              'null, null)'));
      expect(f.kind, ConnectionFailureKind.connectionLost);
    });
  });

  group('ConnectionFailure — jaminan dasar', () {
    test('exception asing → unknown, tanpa menebak', () {
      final f = ConnectionFailure.fromException(Exception('galat aneh xyz'));
      expect(f.kind, ConnectionFailureKind.unknown);
    });

    test('technicalDetail selalu menyimpan exception asli', () {
      final f = ConnectionFailure.fromException(Exception('jejak-unik-123'));
      expect(f.technicalDetail, contains('jejak-unik-123'));
    });

    test('semua kind punya pesan manusia + label aksi non-kosong', () {
      for (final kind in ConnectionFailureKind.values) {
        final f = ConnectionFailure.of(kind);
        expect(f.message, isNotEmpty, reason: '$kind tanpa pesan');
        expect(f.actionLabel, isNotEmpty, reason: '$kind tanpa aksi');
        // Pesan tidak boleh bocor jargon exception.
        expect(f.message.toLowerCase(), isNot(contains('exception')));
        expect(f.message.toLowerCase(), isNot(contains('null')));
      }
    });
  });
}
