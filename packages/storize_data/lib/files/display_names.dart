/// Pure helpers that build gallery names the native plugin accepts.
///
/// The rules mirror `InputValidation.kt` in `storize_platform_android`:
/// a segment is at most 100 characters (a file name 255), has no `/`, no
/// `:*?"<>|\`, no `..`, no leading `.`, no trailing `.` or space, and no
/// control, format (bidi, zero-width) or line/paragraph separator characters.
library;

const int _maxSegment = 100;
const int _maxName = 255;

/// Cap for the username and remote ID parts, so a later `name (1).ext` rename
/// by the gallery still fits in [_maxName].
const int _maxPart = 64;

const String _forbidden = r':*?"<>|\/';

/// Builds `<username>_<yyyyMMdd_HHmmss>_<remoteId>[_<slide>].<ext>` in UTC.
///
/// Unsafe characters become `_`. An empty username falls back to `user`, an
/// empty remote ID to `0`. [slideIndex] is added only when it is not null.
/// Throws [ArgumentError] for a negative [slideIndex] or an [ext] with no
/// letters or digits.
String displayNameFor({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) {
  if (slideIndex != null && slideIndex < 0) {
    throw ArgumentError.value(slideIndex, 'slideIndex', 'must not be negative');
  }
  final cleanExt = ext.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  if (cleanExt.isEmpty) {
    throw ArgumentError.value(ext, 'ext', 'needs letters or digits');
  }
  final user = _part(username, 'user');
  final id = _part(remoteId, '0');
  final u = postedAt.toUtc();
  final stamp =
      '${_pad(u.year, 4)}${_pad(u.month, 2)}${_pad(u.day, 2)}'
      '_${_pad(u.hour, 2)}${_pad(u.minute, 2)}${_pad(u.second, 2)}';
  final slide = slideIndex == null ? '' : '_$slideIndex';
  final name = '${user}_${stamp}_$id$slide.$cleanExt';
  assert(name.length <= _maxName, 'display name too long');
  return name;
}

/// The single folder segment for [username] under `Pictures/Storize/`.
///
/// The plugin adds the `Pictures/Storize/` prefix. Falls back to `unknown`.
String relativeDirFor(String username) {
  final cleaned = _sanitize(username);
  final cut = _truncate(cleaned, _maxSegment);
  // The plugin rejects a folder that starts with `~` (home-relative).
  final noTilde = cut.startsWith('~') ? '_${cut.substring(1)}' : cut;
  return _finish(noTilde, 'unknown');
}

String _part(String value, String fallback) =>
    _finish(_truncate(_sanitize(value), _maxPart), fallback);

String _pad(int v, int width) => v.toString().padLeft(width, '0');

/// Replaces every character the plugin would reject, and `..` runs.
String _sanitize(String input) {
  final out = StringBuffer();
  for (final cp in input.runes) {
    final bad =
        (cp < 0x80 && _forbidden.contains(String.fromCharCode(cp))) ||
        _isHiddenControl(cp) ||
        _isWhitespace(cp) ||
        (cp >= 0xD800 && cp <= 0xDFFF);
    out.writeCharCode(bad ? 0x5F : cp);
  }
  return out.toString().replaceAll('..', '_');
}

/// Applies the start/end rules and the fallback.
String _finish(String value, String fallback) {
  var v = value;
  while (v.startsWith('.')) {
    v = '_${v.substring(1)}';
  }
  while (v.endsWith('.') || v.endsWith(' ')) {
    v = '${v.substring(0, v.length - 1)}_';
  }
  return v.isEmpty ? fallback : v;
}

String _truncate(String value, int max) {
  if (value.length <= max) return value;
  var end = max;
  // Do not split a surrogate pair.
  final unit = value.codeUnitAt(end - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) end--;
  return value.substring(0, end);
}

bool _isWhitespace(int cp) =>
    cp == 0x20 ||
    cp == 0xA0 ||
    cp == 0x1680 ||
    (cp >= 0x2000 && cp <= 0x200A) ||
    cp == 0x202F ||
    cp == 0x205F ||
    cp == 0x3000;

/// Control (C0, DEL, C1), format (bidi marks, zero-width) and line/paragraph
/// separators: the Unicode categories Cc, Cf, Zl and Zp.
bool _isHiddenControl(int cp) {
  if (cp < 0x20 || (cp >= 0x7F && cp <= 0x9F)) return true;
  if (cp == 0x2028 || cp == 0x2029) return true;
  const formatRanges = <List<int>>[
    [0x00AD, 0x00AD],
    [0x0600, 0x0605],
    [0x061C, 0x061C],
    [0x06DD, 0x06DD],
    [0x070F, 0x070F],
    [0x0890, 0x0891],
    [0x08E2, 0x08E2],
    [0x180E, 0x180E],
    [0x200B, 0x200F],
    [0x202A, 0x202E],
    [0x2060, 0x2064],
    [0x2066, 0x206F],
    [0xFEFF, 0xFEFF],
    [0xFFF9, 0xFFFB],
    [0x110BD, 0x110BD],
    [0x110CD, 0x110CD],
    [0x13430, 0x1343F],
    [0x1BCA0, 0x1BCA3],
    [0x1D173, 0x1D17A],
    [0xE0001, 0xE0001],
    [0xE0020, 0xE007F],
  ];
  for (final r in formatRanges) {
    if (cp >= r[0] && cp <= r[1]) return true;
  }
  return false;
}
