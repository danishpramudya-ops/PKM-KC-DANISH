/// Format waktu relatif ("baru saja", "12 dtk lalu", dst) — sengaja disamakan
/// gaya bahasanya dengan dashboard/script.js (formatRelativeTime) supaya
/// pengalaman SAR di HP & di dashboard PC konsisten.
String formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) return '—';
  final diff = DateTime.now().difference(timestamp);
  if (diff.isNegative || diff.inSeconds < 5) return 'baru saja';
  if (diff.inSeconds < 60) return '${diff.inSeconds} dtk lalu';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  return '${diff.inHours} jam lalu';
}

String formatClock(DateTime? timestamp) {
  if (timestamp == null) return '—';
  final t = timestamp.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
