/// Wraps [text] (a username, handle or other always-LTR token) in Unicode
/// left-to-right isolate marks so it stays LTR inside RTL text without
/// reordering the surrounding sentence (UX §6).
String isolateLtr(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';

/// Formats a media duration as `m:ss` (or `h:mm:ss`).
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}
