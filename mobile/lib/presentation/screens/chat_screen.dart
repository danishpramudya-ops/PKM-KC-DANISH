import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../core/utils/utf8_limit.dart';
import '../../data/repositories/chat_repository.dart';

/// Chat tim SAR — dikirim lewat BLE ke node SAR, di-broadcast firmware ke
/// mesh LoRa sebagai paket PKT_CHAT (lihat docs/protokol-paket.md §8).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final chat = context.read<ChatRepository>();
    setState(() => _sending = true);
    try {
      await chat.send(text);
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim pesan: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatRepository>();
    final messages = chat.messages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text('Belum ada pesan.\nKetik di bawah untuk memulai.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[messages.length - 1 - index];
                    return Align(
                      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: m.isMine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!m.isMine)
                              Text('${m.role}-${m.originId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: m.isMine ? Colors.white70 : AppColors.primary,
                                  )),
                            Text(m.msg,
                                style: TextStyle(color: m.isMine ? Colors.white : AppColors.text)),
                            const SizedBox(height: 4),
                            Text(
                              formatClock(m.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: m.isMine ? Colors.white70 : AppColors.text.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    // maxLength dipertahankan untuk penghitung "N/100" —
                    // batas SEBENARNYA adalah byte, ditegakkan formatter di
                    // bawah (firmware membatasi 100 BYTE; 100 karakter emoji
                    // = 400 byte akan dipotong firmware dan bisa rusak).
                    // Penghitung karakter yang menyesatkan utk teks multi-
                    // byte = kompromi sadar Fase 0, dibereskan di Fase 2.
                    maxLength: 100,
                    inputFormatters: const [
                      Utf8LengthLimitingFormatter(BleConstants.chatMaxBytes),
                    ],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 24), // to align with the input because of maxLength counter
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
