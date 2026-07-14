import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import 'developer_mode_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
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
    _checkPermissions();
  }

  Future<void> _requestLocation() async {
    await Permission.locationWhenInUse.request();
    _checkPermissions();
  }

  Widget _buildPermissionStatus(PermissionStatus status) {
    String text;
    Color color;
    
    if (status.isGranted) {
      text = 'Granted';
      color = AppColors.success;
    } else if (status.isPermanentlyDenied) {
      text = 'Permanently Denied';
      color = AppColors.offline;
    } else {
      text = 'Denied';
      color = AppColors.offline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // About Card
        Card(
          color: AppColors.card,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                GestureDetector(
                  onLongPress: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Developer Mode Activated'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeveloperModeScreen()),
                    );
                  },
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset('assets/logo.png', width: 90, height: 90),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'POINTRESCUE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Emergency Monitoring System',
                  style: TextStyle(
                    color: AppColors.text.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Settings List
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'PERMISSIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text.withOpacity(0.4),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.text.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bluetooth, color: AppColors.primary),
                ),
                title: const Text('Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Required for BLE scan', style: TextStyle(fontSize: 12)),
                trailing: _buildPermissionStatus(_btStatus),
                onTap: _btStatus.isGranted ? null : _requestBluetooth,
              ),
              Divider(height: 1, indent: 70, color: AppColors.text.withOpacity(0.05)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on, color: AppColors.primary),
                ),
                title: const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Required on Android < 12', style: TextStyle(fontSize: 12)),
                trailing: _buildPermissionStatus(_locStatus),
                onTap: _locStatus.isGranted ? null : _requestLocation,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.text.withOpacity(0.4),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.text.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.dark_mode, color: AppColors.secondary),
            ),
            title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Switch(
              value: false, // Not implemented yet
              onChanged: (val) {},
              activeColor: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
