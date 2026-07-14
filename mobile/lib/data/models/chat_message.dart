/// Satu pesan chat tim SAR, hasil parse dari notifikasi characteristic CHAT_RX.
class ChatMessage {
  final int originId;
  final String role;
  final String msg;
  final DateTime timestamp;
  final bool isMine;

  const ChatMessage({
    required this.originId,
    required this.role,
    required this.msg,
    required this.timestamp,
    required this.isMine,
  });
}
