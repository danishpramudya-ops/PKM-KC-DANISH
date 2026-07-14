import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../data/ble/anchorpulse_ble_service.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/connection_repository.dart';
import '../data/repositories/node_repository.dart';
import 'screens/connect_screen.dart';

/// Root widget: satu instance AnchorpulseBleService dibagi ke tiga
/// repository (connection/node/chat) lewat Provider, supaya screens/ tidak
/// perlu tahu detail BLE sama sekali.
class AnchorpulseApp extends StatefulWidget {
  const AnchorpulseApp({super.key});

  @override
  State<AnchorpulseApp> createState() => _AnchorpulseAppState();
}

class _AnchorpulseAppState extends State<AnchorpulseApp> {
  late final AnchorpulseBleService _ble;
  late final ConnectionRepository _connectionRepository;
  late final NodeRepository _nodeRepository;
  late final ChatRepository _chatRepository;

  @override
  void initState() {
    super.initState();
    _ble = AnchorpulseBleService();
    _connectionRepository = ConnectionRepository(_ble);
    _nodeRepository = NodeRepository(_ble);
    _chatRepository = ChatRepository(_ble);
  }

  @override
  void dispose() {
    _connectionRepository.dispose();
    _nodeRepository.dispose();
    _chatRepository.dispose();
    _ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _connectionRepository),
        ChangeNotifierProvider.value(value: _nodeRepository),
        ChangeNotifierProvider.value(value: _chatRepository),
      ],
      child: MaterialApp(
        title: 'POINTRESCUE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const ConnectScreen(),
      ),
    );
  }
}
