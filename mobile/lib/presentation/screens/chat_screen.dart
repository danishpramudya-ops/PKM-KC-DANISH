import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';
import '../../core/utils/time_format.dart';
import '../../core/utils/utf8_limit.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../widgets/empty_state.dart';

/// Chat tim SAR — dikirim lewat BLE ke node SAR, di-broadcast firmware ke
/// mesh LoRa sebagai paket PKT_CHAT (docs/protokol-paket.md §8).
///
/// Dua aturan yang mengikat layar ini:
///  1. **Preset satu ketuk** menyelesaikan mayoritas kebutuhan — mengetik
///     dengan sarung tangan basah hampir mustahil (keputusan ronde 4).
///  2. **Tidak ada centang/"Terkirim"** di mana pun: protokol tanpa ACK
///     tidak bisa membuktikannya (batasan B8, docs/fase-0c §1).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  /// Pesan siap pakai — dipilih untuk kejadian paling sering di lapangan.
  static const _presets = [
    'Butuh bantuan medis',
    'Area aman',
    'Menuju lokasi',
    'Kembali ke pos',
  ];

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() => _sending = true);
    // send() tidak melempar: kegagalan disalurkan lewat status pesan yang
    // persisten di daftar, bukan snackbar yang lenyap (0C-C3).
    await context.read<ChatRepository>().send(trimmed);
    _controller.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final messages = context.watch<ChatRepository>().messages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Belum ada pesan',
                  subtitle: 'Ketuk pesan cepat di bawah untuk mengirim '
                      'kabar ke seluruh tim.',
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[messages.length - 1 - index];
                    return _Bubble(message: m);
                  },
                ),
        ),
        _presetRow(tokens),
        _inputRow(tokens),
      ],
    );
  }

  Widget _presetRow(AppTokens tokens) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        itemCount: _presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) => Center(
          child: OutlinedButton(
            onPressed: _sending ? null : () => _send(_presets[i]),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.accent,
              side: BorderSide(color: tokens.accent, width: 1.5),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              shape: const StadiumBorder(),
              textStyle: AppType.label,
            ),
            child: Text(_presets[i]),
          ),
        ),
      ),
    );
  }

  Widget _inputRow(AppTokens tokens) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                style: AppType.body.copyWith(color: tokens.contentPrimary),
                // Batas SEBENARNYA adalah byte (firmware memotong pada byte
                // ke-100 dan bisa membelah karakter multi-byte) — 0C-C2.
                inputFormatters: const [
                  Utf8LengthLimitingFormatter(BleConstants.chatMaxBytes),
                ],
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan…',
                  hintStyle: AppType.body.copyWith(color: tokens.contentMuted),
                  filled: true,
                  fillColor: tokens.surfaceOverlay,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            SizedBox(
              width: AppTouch.minTarget,
              height: AppTouch.minTarget,
              child: Material(
                color: tokens.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : () => _send(_controller.text),
                  child: Icon(Icons.send_rounded,
                      color: tokens.onAccent, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final mine = message.isMine;
    final failed = message.status == ChatMessageStatus.failed;

    final bg = !mine
        ? tokens.surfaceOverlay
        : failed
            ? Colors.transparent
            : tokens.accent;
    final fg = !mine
        ? tokens.contentPrimary
        : failed
            ? tokens.statusCritical
            : tokens.onAccent;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        padding: const EdgeInsets.fromLTRB(
            AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: failed
              ? Border.all(color: tokens.statusCritical, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${message.role}-${message.originId}',
                  style: AppType.overline.copyWith(color: tokens.accent),
                ),
              ),
            Text(
              message.msg,
              style: AppType.body.copyWith(fontSize: 14, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              _statusLine(message),
              style: AppType.data.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: failed ? 1 : 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Keadaan normal tetap sunyi — hanya penyimpangan yang bersuara
  /// (prinsip "Terbaca dalam tiga detik"). DILARANG kata "Terkirim" atau
  /// ikon centang: protokol tanpa ACK tidak bisa membuktikannya (B8).
  String _statusLine(ChatMessage m) {
    final clock = formatClock(m.timestamp);
    if (!m.isMine) return clock;
    return switch (m.status) {
      ChatMessageStatus.sending => '$clock · mengirim…',
      ChatMessageStatus.handedToNode => clock,
      ChatMessageStatus.failed => '$clock · gagal terkirim',
    };
  }
}
