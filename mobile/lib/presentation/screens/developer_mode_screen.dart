import 'package:flutter/material.dart';


class DeveloperModeScreen extends StatelessWidget {
  const DeveloperModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tools = [
      {'icon': Icons.bluetooth_searching, 'name': 'BLE Scanner', 'desc': 'Raw advertisement data'},
      {'icon': Icons.science, 'name': 'A/B Scan Test', 'desc': 'Test scanning performance'},
      {'icon': Icons.code, 'name': 'Raw Advertisement Viewer', 'desc': 'View raw manufacturer data'},
      {'icon': Icons.key, 'name': 'UUID Viewer', 'desc': 'Service & Characteristic verification'},
      {'icon': Icons.signal_cellular_alt, 'name': 'RSSI Monitor', 'desc': 'Real-time signal graph'},
      {'icon': Icons.data_array, 'name': 'Packet Log', 'desc': 'View raw bytes Rx/Tx'},
      {'icon': Icons.history, 'name': 'Connection Log', 'desc': 'Connect/Disconnect history'},
      {'icon': Icons.list_alt, 'name': 'Characteristic Viewer', 'desc': 'Read/Write raw characteristics'},
      {'icon': Icons.memory, 'name': 'Firmware Information', 'desc': 'Read device firmware version'},
      {'icon': Icons.security, 'name': 'Permission Status', 'desc': 'Detailed permission breakdown'},
      {'icon': Icons.bluetooth, 'name': 'Bluetooth Status', 'desc': 'Adapter state and capabilities'},
      {'icon': Icons.download, 'name': 'Export Debug Log', 'desc': 'Save logs to device storage'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Warning: These tools are for debugging POINTRESCUE hardware and connection protocols.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...tools.map((t) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(t['icon'] as IconData, color: Colors.white),
              ),
              title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(t['desc'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${t['name']} is not implemented yet.')),
                );
              },
            ),
          )),
        ],
      ),
    );
  }
}
