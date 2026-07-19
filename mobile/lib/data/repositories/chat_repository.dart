import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/utils/utf8_limit.dart';
import '../ble/anchorpulse_ble_service.dart';
import '../models/chat_message.dart';

/// Riwayat chat tim SAR untuk sesi koneksi saat ini (in-memory, tidak
/// disimpan permanen — sesuai kebutuhan "tim chat lewat device").
class ChatRepository extends ChangeNotifier {
  final AnchorpulseBleService ble;
  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _sub;

  /// Timer batas-tunggu echo per pesan ber-status `sending` (kunci =
  /// identitas objek pesan). Semua dibatalkan di reset() dan dispose().
  final Map<ChatMessage, Timer> _echoTimers = {};

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

      // Rekonsiliasi echo (0C-C3): firmware meng-echo balik pesan yang kami
      // kirim (originateChat → bleNotifyChat) SEGERA setelah masuk antrean
      // TX — echo tidak membawa pengenal apa pun, jadi pencocokan heuristik:
      // pesan `sending` TERTUA dengan teks sama persis. Saat myNodeId null
      // (NODE_INFO gagal dibaca) tetap cocokkan teks saja — lebih baik
      // daripada salah menandai gagal padahal berhasil (rencana 0C §4).
      final canBeEcho = myNodeId == null || id == myNodeId;
      if (canBeEcho) {
        final i = _messages.indexWhere(
            (m) => m.status == ChatMessageStatus.sending && m.msg == msg);
        if (i != -1) {
          final message = _messages[i];
          _echoTimers.remove(message)?.cancel();
          message.status = ChatMessageStatus.handedToNode;
          notifyListeners();
          return; // JANGAN tambah entri baru — inilah pencegah duplikat
        }
      }

      // Bukan echo pesan lokal → pesan baru dari node lain (atau pesan kami
      // dari sesi sebelumnya yang di-relay).
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

  /// Kirim pesan chat dengan sisipan optimistis (0C-C3).
  ///
  /// Pesan LANGSUNG masuk daftar ber-status `sending` — sebelumnya pesan
  /// baru muncul saat echo firmware datang, dan bila echo hilang, pesan
  /// lenyap tanpa jejak padahal kolom input sudah dikosongkan: relawan
  /// yakin sudah melapor, padahal tidak.
  ///
  /// Method ini TIDAK melempar: kegagalan disalurkan lewat status pesan
  /// (`failed`, tampil "gagal terkirim" di 0C-C4) yang persisten di daftar
  /// — bukan lewat exception + snackbar yang lenyap sendiri.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    // Lapis kedua setelah formatter di TextField: apa pun yang lolos ke
    // sini tidak boleh melebihi batas byte firmware (0C-C2). trim() ulang
    // karena pemotongan pada batas byte bisa menyisakan spasi di ujung —
    // firmware juga men-trim, dan teks harus sama persis agar echo bisa
    // dicocokkan (0C-C3).
    final limited = truncateUtf8(trimmed, BleConstants.chatMaxBytes).trim();
    if (limited.isEmpty) return;

    final message = ChatMessage(
      originId: myNodeId ?? -1,
      role: myNodeId != null ? roleNameFromId(myNodeId!) : 'SAR',
      msg: limited,
      timestamp: DateTime.now(),
      isMine: true,
      status: ChatMessageStatus.sending,
    );
    _messages.add(message);
    notifyListeners();

    try {
      await ble.sendChat(limited);
      _startEchoTimer(message);
    } catch (_) {
      _markFailed(message);
    }
  }

  void _startEchoTimer(ChatMessage message) {
    _echoTimers[message] = Timer(BleConstants.chatEchoTimeout, () {
      _echoTimers.remove(message);
      _markFailed(message);
    });
  }

  void _markFailed(ChatMessage message) {
    _echoTimers.remove(message)?.cancel();
    if (message.status == ChatMessageStatus.sending) {
      // Sengaja dibiarkan `failed` walau echo mungkin datang terlambat
      // setelah ini: terlalu berhati-hati lebih baik daripada terlalu
      // percaya diri (rencana 0C §4). Pesan TETAP terlihat di daftar.
      message.status = ChatMessageStatus.failed;
      notifyListeners();
    }
  }

  void reset() {
    for (final t in _echoTimers.values) {
      t.cancel();
    }
    _echoTimers.clear();
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _echoTimers.values) {
      t.cancel();
    }
    _echoTimers.clear();
    _sub?.cancel();
    super.dispose();
  }
}
