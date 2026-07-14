import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../widgets/connection_status_bar.dart';
import 'chat_screen.dart';
import 'connect_screen.dart';
import 'map_screen.dart';
import 'node_list_screen.dart';
import 'settings_screen.dart';

/// Shell utama setelah terhubung ke node SAR: 4 tab (Node List / Peta / Chat / Settings).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  Future<void> _disconnect() async {
    final connection = context.read<ConnectionRepository>();
    final nodeRepository = context.read<NodeRepository>();
    final chatRepository = context.read<ChatRepository>();

    await connection.disconnect();
    nodeRepository.reset();
    chatRepository.reset();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionRepository>();

    final screens = const [
      NodeListScreen(),
      MapScreen(),
      ChatScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('POINTRESCUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Putuskan koneksi',
            onPressed: _disconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionStatusBar(connection: connection),
          Expanded(child: screens[_tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Node'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Peta'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
