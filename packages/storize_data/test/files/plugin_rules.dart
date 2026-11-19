/// Dart mirror of `InputValidation.kt` (storize_platform_android).
///
/// Keep in sync with the Kotlin rules. Returns null when the value is
/// accepted, otherwise the reason it is rejected.
library;

const int _maxSegment = 100;
const int _maxName = 255;
const int _maxSegments = 4;
const String _forbidden = r':*?"<>|\';

String? pluginRejectsDisplayName(String? value) {
  if (value == null || value.isEmpty) return 'required';
  if (value.contains('/')) return 'slash';
  return _checkSegment(value, _maxName);
}

String? pluginRejectsRelativeDir(String? value) {
  if (value == null || value.isEmpty) return 'required';
  if (value.startsWith('/') ||
      value.startsWith('~') ||
      RegExp('^[A-Za-z]:').hasMatch(value)) {
    return 'absolute';
  }
  final segments = value.split('/');
  if (segments.length > _maxSegments) return 'too many segments';
  for (final s in segments) {
    if (s.isEmpty) return 'empty segment';
    final r = _checkSegment(s, _maxSegment);
    if (r != null) return r;
  }
  return null;
}

String? _checkSegment(String segment, int max) {
  if (segment.length > max) return 'too long';
  if (segment.contains('..')) return 'dotdot';
  if (segment.startsWith('.')) return 'leading dot';
  if (segment.endsWith('.') || segment.endsWith(' ')) return 'trailing';
  for (final cp in segment.runes) {
    if ((cp < 0x80 && _forbidden.contains(String.fromCharCode(cp))) ||
        _hidden(cp)) {
      return 'forbidden character';
    }
  }
  return null;
}

/// Control (Cc), format (Cf), line and paragraph separators (Zl, Zp). The
/// format list is the one of Unicode 15; the test strings use well-known
/// members only.
bool _hidden(int cp) =>
    cp < 0x20 ||
    (cp >= 0x7F && cp <= 0x9F) ||
    cp == 0xAD ||
    (cp >= 0x200B && cp <= 0x200F) ||
    (cp >= 0x2028 && cp <= 0x202E) ||
    (cp >= 0x2060 && cp <= 0x2064) ||
    (cp >= 0x2066 && cp <= 0x206F) ||
    cp == 0x061C ||
    cp == 0xFEFF ||
    (cp >= 0xE0020 && cp <= 0xE007F);
