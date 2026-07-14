import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ble/anchorpulse_ble_service.dart';
import '../models/chat_message.dart';

/// Riwayat chat tim SAR untuk sesi koneksi saat ini (in-memory, tidak
/// disimpan permanen — sesuai kebutuhan "tim chat lewat device").
class ChatRepository extends ChangeNotifier {
  final AnchorpulseBleService ble;
  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _sub;

  /// NODE_ID node SAR yang sedang terhubung, dipakai menandai pesan
  /// "milik sendiri". Di-set dari luar begitu ConnectionRepository berhasil
  /// membaca characteristic NODE_INFO.
  int? myNodeId;

  ChatRepository(this.ble) {
    _sub = ble.chatRawStream.listen(_onRawChat);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _onRawChat(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final id = json['id'] as int;
      final role = json['role'] as String? ?? 'UNKNOWN';
      final msg = json['msg'] as String? ?? '';
      _messages.add(ChatMessage(
        originId: id,
        role: role,
        msg: msg,
        timestamp: DateTime.now(),
        isMine: myNodeId != null && id == myNodeId,
      ));
      notifyListeners();
    } catch (_) {
      // JSON korup/terpotong (lihat catatan MTU di mobile/README.md) — abaikan.
    }
  }

  /// Kirim pesan chat. Pesan yang terkirim TIDAK ditambah optimistic ke list
  /// di sini — firmware node SAR meng-echo balik lewat CHAT_RX begitu
  /// pesan selesai dibungkus jadi paket PKT_CHAT, jadi akan muncul otomatis.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ble.sendChat(trimmed);
  }

  void reset() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
