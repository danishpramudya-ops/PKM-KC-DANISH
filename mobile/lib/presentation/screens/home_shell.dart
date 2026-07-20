import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/node_repository.dart';
import 'chat_screen.dart';
import 'connect_screen.dart';
import 'map_home_screen.dart';
import 'settings_screen.dart';

/// Shell utama setelah terhubung: **tiga tab** — Peta · Chat · Pengaturan
/// (keputusan D1, docs/strategi-ux.md).
///
/// Daftar node TIDAK punya tab sendiri; ia hidup sebagai bottom sheet di
/// atas peta (D2). Peta adalah rumah: membuka aplikasi = langsung melihat
/// posisi tim.
///
/// Status koneksi tidak lagi memakai bar terpisah — ia jadi chip mengambang
/// di peta (satu sumber kebenaran, tidak menghabiskan tinggi permanen).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  /// Pemutusan koneksi kini WAJIB dikonfirmasi: sebelumnya satu ketukan tak
  /// sengaja di pojok kanan atas langsung memutus kontak di tengah operasi
  /// (temuan audit UX #9).
  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putuskan koneksi?'),
        content: const Text(
          'Aplikasi berhenti menerima posisi tim dan sinyal SOS sampai '
          'kamu menyambung lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final connection = context.read<ConnectionRepository>();
    context.read<NodeRepository>().reset();
    context.read<ChatRepository>().reset();
    await connection.disconnect();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tab peta tampil penuh sampai ke belakang status bar; dua tab lain
    // memakai AppBar biasa.
    final isMap = _tabIndex == 0;

    return Scaffold(
      extendBodyBehindAppBar: isMap,
      appBar: isMap
          ? null
          : AppBar(
              title: Text(_tabIndex == 1 ? 'Chat tim' : 'Pengaturan'),
              actions: [
                IconButton(
                  tooltip: 'Putuskan koneksi',
                  onPressed: _confirmDisconnect,
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ],
            ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          MapHomeScreen(),
          ChatScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Peta',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
