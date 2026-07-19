import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/connection_repository.dart';
import '../widgets/premium_card.dart';
import 'home_shell.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  bool _requestingPermission = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
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
        const SnackBar(
          content: Text('Bluetooth belum aktif. Nyalakan Bluetooth lalu coba lagi.'),
          backgroundColor: AppColors.offline,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _ensurePermissions();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin Bluetooth ditolak. Buka Settings > Apps > POINTRESCUE > '
              'Permissions dan izinkan "Perangkat di sekitar".'),
          duration: Duration(seconds: 5),
          backgroundColor: AppColors.offline,
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
          backgroundColor: AppColors.offline,
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),
              // Hero Image
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isScanning ? _scaleAnimation.value : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (isScanning)
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 10,
                              )
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/logo.png',
                      width: 140,
                      height: 140,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                'POINTRESCUE',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Emergency Monitoring System',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // Scan Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_requestingPermission || isScanning) ? null : _startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: isScanning
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Mencari Node...',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                            ],
                          )
                        : const Text(
                            'Mulai Pindai',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Results or Empty State
              Expanded(
                child: connection.scanResults.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                                    size: 48,
                                    color: AppColors.primary.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  isScanning
                                      ? 'Mencari node POINTRESCUE terdekat...'
                                      : 'Belum ada node ditemukan.\nPastikan perangkat menyala.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.text.withOpacity(0.5),
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: connection.scanResults.length,
                        itemBuilder: (context, index) {
                          final result = connection.scanResults[index];
                          final rawName = result.device.platformName.isNotEmpty
                              ? result.device.platformName
                              : result.advertisementData.advName;
                          final displayName = _getDisplayName(rawName);
                          final isConnecting = connection.status == ConnectionStatus.connecting;

                          return PremiumCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            onTap: isConnecting ? null : () => _connect(result.device),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.router, color: AppColors.primary, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.signal_cellular_alt,
                                            size: 16,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'RSSI ${result.rssi} dBm',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.text.withOpacity(0.6),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isConnecting)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 3),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Connect',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              // Footer Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Net ID: ${BleConstants.netId}',
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                    color: AppColors.text.withOpacity(0.3)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
