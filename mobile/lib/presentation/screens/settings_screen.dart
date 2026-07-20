import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/connection_repository.dart';
import '../widgets/data_tone.dart';
import '../widgets/detail_row.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/surface_card.dart';
import 'developer_mode_screen.dart';

/// Pengaturan — seluruhnya dirakit dari DetailRow, persis seperti panel
/// kanan dashboard laptop (docs/sistem-komponen.md). Layar inilah bukti
/// paling jelas kenapa "satu baris diulang" terasa solid.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _btStatus = PermissionStatus.denied;
  PermissionStatus _locStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final bt = await Permission.bluetoothConnect.status;
    final loc = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() {
        _btStatus = bt;
        _locStatus = loc;
      });
    }
  }

  Future<void> _requestBluetooth() async {
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await _checkPermissions();
  }

  Future<void> _requestLocation() async {
    await Permission.locationWhenInUse.request();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionRepository>();
    final connected = connection.status == ConnectionStatus.connected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxl),
      children: [
        const SectionHeader('Tampilan'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            children: [
              // Switch tema sungguhan dibangun di Fase 3 bersama keempat
              // paletnya. Sampai itu, baris ini menyatakan keadaan apa
              // adanya — bukan sakelar mati yang berpura-pura hidup
              // (settings lama: `onChanged: (val) {}`).
              const DetailRow(
                icon: Icons.dark_mode_rounded,
                label: 'Tema',
                value: 'Gelap',
                tone: DataTone.accent,
              ),
              DetailRow(
                icon: Icons.palette_outlined,
                label: 'Pilihan tema',
                value: 'Terang · Malam-merah — Fase 3',
                dimmed: true,
                onTap: () => _soon(context),
              ),
              const DetailRow(
                icon: Icons.translate_rounded,
                label: 'Bahasa',
                value: 'Indonesia',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader('Perangkat'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            children: [
              DetailRow(
                icon: Icons.router_rounded,
                label: 'Node tersambung',
                value: connected
                    ? 'SAR-${connection.myNodeId ?? '?'}'
                    : 'Tidak ada',
                tone: connected ? DataTone.ok : DataTone.neutral,
                trailing: StatusPill(
                  label: connected ? 'Aktif' : 'Putus',
                  kind: connected ? StatusKind.ok : StatusKind.inactive,
                ),
              ),
              const DetailRow(
                icon: Icons.lan_rounded,
                label: 'Jaringan mesh',
                value: 'PR01',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader('Izin'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            children: [
              _permissionRow(
                icon: Icons.bluetooth_rounded,
                label: 'Perangkat di sekitar',
                status: _btStatus,
                onRequest: _requestBluetooth,
              ),
              _permissionRow(
                icon: Icons.location_on_rounded,
                label: 'Lokasi',
                status: _locStatus,
                onRequest: _requestLocation,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader('Lanjutan'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            children: [
              DetailRow(
                icon: Icons.terminal_rounded,
                label: 'Mode pengembang',
                value: 'Log & diagnostik',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const DeveloperModeScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader('Tentang'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            children: [
              DetailRow(
                icon: Icons.shield_rounded,
                label: 'POINTRESCUE',
                value: 'Versi 1.0.0',
                tone: DataTone.accent,
              ),
              const DetailRow(
                icon: Icons.wifi_tethering_rounded,
                label: 'Signal Lost',
                value: 'Lives Found',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String label,
    required PermissionStatus status,
    required Future<void> Function() onRequest,
  }) {
    final granted = status.isGranted || status.isLimited;
    final permanentlyDenied = status.isPermanentlyDenied;

    return DetailRow(
      icon: icon,
      label: label,
      value: granted
          ? 'Diizinkan'
          : permanentlyDenied
              ? 'Ditolak permanen'
              : 'Belum diizinkan',
      tone: granted ? DataTone.ok : DataTone.warning,
      trailing: granted
          ? const StatusPill(label: 'OK', kind: StatusKind.ok)
          : const StatusPill(label: 'Perlu izin', kind: StatusKind.warning),
      onTap: granted
          ? null
          : permanentlyDenied
              ? openAppSettings
              : onRequest,
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pilihan tema lengkap dibangun di Fase 3.'),
      ),
    );
  }
}
