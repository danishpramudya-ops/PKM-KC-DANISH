/// Status pengiriman pesan chat MILIK SENDIRI (Fase 0C-C3).
///
/// PENAMAAN INI DISENGAJA dan dilindungi batasan B8
/// (docs/fase-0c-implementation-plan.md §1): protokol TIDAK punya ACK,
/// jadi TIDAK BOLEH ada status "terkirim"/"delivered"/ikon centang.
/// [handedToNode] hanya berarti node SAR di ransel relawan sudah menerima
/// dan mengantrekan pesan ke LoRa — BUKAN bukti pesan sampai ke tim.
/// Status `delivered` sungguhan baru boleh ada bila ACK ditambahkan ke
/// protokol (butir B4 saran-tindaklanjut.txt, pasca-Fase 5).
enum ChatMessageStatus {
  /// Ditulis ke BLE, menunggu echo lokal dari node SAR.
  sending,

  /// Echo lokal diterima — node SAR sudah menerima & mengantre ke LoRa.
  handedToNode,

  /// Penulisan BLE gagal, atau echo tidak datang dalam chatEchoTimeout.
  failed,
}

/// Satu pesan chat tim SAR, hasil parse dari notifikasi characteristic
/// CHAT_RX — atau sisipan optimistis saat mengirim (0C-C3).
class ChatMessage {
  final int originId;
  final String role;
  final String msg;
  final DateTime timestamp;
  final bool isMine;

  /// Hanya bermakna untuk pesan milik sendiri ([isMine]); pesan node lain
  /// selalu [ChatMessageStatus.handedToNode] — kedatangannya di HP ini
  /// adalah bukti nyata ia tersampaikan.
  ChatMessageStatus status;

  ChatMessage({
    required this.originId,
    required this.role,
    required this.msg,
    required this.timestamp,
    required this.isMine,
    this.status = ChatMessageStatus.handedToNode,
  });
}
