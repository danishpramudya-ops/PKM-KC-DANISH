import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../data/repositories/connection_repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/radar_scanner.dart';
import '../widgets/surface_card.dart';
import 'home_shell.dart';

/// Layar pindai & sambung ke node SAR — visual radar taktis.
/// Logika BLE/permission SAMA PERSIS dengan Fase 0, hanya tampilannya yang
/// dirombak. Sejak Fase 2 tema gelap jadi default aplikasi, jadi layar ini
/// tidak lagi perlu membungkus dirinya sendiri dengan scope tema.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  bool _requestingPermission = false;
  late final AnimationController _animController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    setState(() => _requestingPermission = true);
    try {
      final List<Permission> needed;
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        needed = sdk >= 31
            ? [Permission.bluetoothScan, Permission.bluetoothConnect]
            : [Permission.locationWhenInUse];
      } else {
        needed = [Permission.bluetooth];
      }
      final statuses = await needed.request();
      return statuses.values.every((s) => s.isGranted || s.isLimited);
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _startScan() async {
    final connection = context.read<ConnectionRepository>();

    final btOn = await connection.ensureBluetoothOn();
    if (!btOn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bluetooth belum aktif. Nyalakan Bluetooth lalu coba lagi.'),
          backgroundColor: AppTokens.dark.statusCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _ensurePermissions();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izin Bluetooth ditolak. Buka Settings > Apps > POINTRESCUE > '
              'Permissions dan izinkan "Perangkat di sekitar".'),
          duration: const Duration(seconds: 5),
          backgroundColor: AppTokens.dark.statusCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    connection.startScan();
  }

  Future<void> _connect(BluetoothDevice device) async {
    final connection = context.read<ConnectionRepository>();
    await connection.connect(device);
    if (!mounted) return;
    if (connection.status == ConnectionStatus.connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else if (connection.status == ConnectionStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // failure.message SELALU bahasa manusia (kamus 0A-C2) — tidak ada
          // e.toString() yang boleh sampai ke layar.
          content: Text(
              connection.failure?.message ?? 'Terjadi gangguan koneksi.'),
          backgroundColor: AppTokens.dark.statusCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getDisplayName(String rawName) {
    if (rawName.isEmpty) return 'POINTRESCUE Node';
    // Jika mengandung ANCHORPULSE, ubah tampilannya menjadi POINTRESCUE
    if (rawName.toUpperCase().contains('ANCHORPULSE')) {
      return rawName.replaceAll(RegExp('ANCHORPULSE', caseSensitive: false), 'POINTRESCUE');
    }
    return rawName;
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionRepository>();
    final isScanning = connection.status == ConnectionStatus.scanning;
    final isConnecting = connection.status == ConnectionStatus.connecting;
    final tokens = AppTokens.of(context);

    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'POINTRESCUE',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpace.xl),
                      RadarScanner(isScanning: isScanning, pulse: _pulse),
                      const SizedBox(height: AppSpace.xl),
                      Text(
                        isScanning ? 'MEMINDAI' : 'SIAP MEMINDAI',
                        style: AppType.label.copyWith(
                          color: isScanning ? tokens.accent : tokens.contentMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        isScanning
                            ? 'MENCARI NODE SAR DI SEKITAR...'
                            : 'Tekan tombol di bawah untuk mulai mencari node.',
                        textAlign: TextAlign.center,
                        style: isScanning
                            ? AppType.data.copyWith(color: tokens.contentMuted, fontSize: 12)
                            : TextStyle(color: tokens.contentMuted, fontSize: 13),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'NODE TERSEDIA',
                          style: AppType.label.copyWith(
                            color: tokens.contentMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      if (connection.scanResults.isEmpty)
                        EmptyState(
                          icon: isScanning ? Icons.bluetooth_searching : Icons.router,
                          title: isScanning
                              ? 'Mencari node POINTRESCUE terdekat...'
                              : 'Belum ada node ditemukan.',
                          subtitle: isScanning
                              ? null
                              : 'Pastikan perangkat SAR menyala dan berada dalam jangkauan.',
                        )
                      else
                        Column(
                          children: [
                            for (final result in connection.scanResults)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                                child: _ScanResultTile(
                                  result: result,
                                  displayName: _getDisplayName(
                                    result.device.platformName.isNotEmpty
                                        ? result.device.platformName
                                        : result.advertisementData.advName,
                                  ),
                                  isConnecting: isConnecting,
                                  onTap: isConnecting ? null : () => _connect(result.device),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: AppTouch.minTarget,
                  child: FilledButton(
                    onPressed: (_requestingPermission || isScanning) ? null : _startScan,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: tokens.onAccent,
                      disabledBackgroundColor: tokens.accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: isScanning
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(tokens.onAccent),
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              const Text(
                                'Mencari Node...',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ],
                          )
                        : const Text(
                            'Mulai Pindai',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  'Net ID: ${BleConstants.netId}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.contentMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kualifikasi sinyal untuk sublabel di daftar node — turunan tampilan
/// dari RSSI mentah, tidak ada data baru yang diminta ke perangkat.
(Color, String) _signalTier(int rssi, AppTokens tokens) {
  if (rssi >= -60) return (tokens.statusOk, 'Baik');
  if (rssi >= -80) return (tokens.statusWarning, 'Sedang');
  return (tokens.statusCritical, 'Lemah');
}

class _ScanResultTile extends StatelessWidget {
  final ScanResult result;
  final String displayName;
  final bool isConnecting;
  final VoidCallback? onTap;

  const _ScanResultTile({
    required this.result,
    required this.displayName,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (tierColor, tierLabel) = _signalTier(result.rssi, tokens);

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.surfaceOverlay,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(Icons.router, color: tokens.contentSecondary, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(color: tokens.contentPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: tierColor),
                    ),
                    const SizedBox(width: 4),
                    Text(tierLabel, style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (isConnecting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: tokens.accent),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RSSI', style: TextStyle(color: tokens.contentMuted, fontSize: 10)),
                Text('${result.rssi}', style: AppType.data.copyWith(color: tierColor, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}
