/// LAST RESORT (TECH_SPEC 4.1 page-mode step 3). Reading `img` and `video`
/// sources from the page gives bare CDN URLs without ids, times or owners, so
/// it cannot become `RemoteContent`. Use it only to learn that media is
/// visible when the JSON paths are broken; direct and JSON-hook parsing stay
/// the real source. The script is read-only: no click, tap or scroll.
library;

import 'dart:convert';

/// The script `PageSession.collectDomMedia` evaluates. Returns a JSON string.
const String domCollectScript = r'''
(function () {
  var out = [];
  function add(src, kind) { if (src && out.length < 50) out.push({src: src, kind: kind}); }
  document.querySelectorAll('video').forEach(function (v) { add(v.currentSrc || v.src, 'video'); });
  document.querySelectorAll('img').forEach(function (i) {
    var best = i.currentSrc || i.src, bestW = 0;
    (i.srcset || '').split(',').forEach(function (part) {
      var p = part.trim().split(/\s+/);
      var w = parseInt(p[1], 10) || 0;
      if (p[0] && w >= bestW) { best = p[0]; bestW = w; }
    });
    add(best, 'image');
  });
  return JSON.stringify(out);
})()
''';

/// One media URL read from the DOM. The URL is signed: never log it.
final class DomMedia {
  /// Creates an entry.
  const DomMedia({required this.url, required this.isVideo});

  /// The https CDN URL.
  final String url;

  /// True for a `video` element.
  final bool isVideo;

  @override
  String toString() => 'DomMedia(isVideo: $isVideo)';
}

bool _isCdnHost(String host) =>
    host.endsWith('.fbcdn.net') ||
    host.endsWith('.cdninstagram.com') ||
    host == 'cdninstagram.com';

/// Reads the script result. Keeps only https URLs on the Instagram CDN hosts;
/// `blob:`, `data:`, page URLs and other hosts are dropped.
List<DomMedia> parseDomMedia(Object? raw) {
  var data = raw;
  if (data is String) {
    try {
      data = jsonDecode(data);
    } on FormatException {
      return const [];
    }
  }
  if (data is! List) return const [];
  final out = <DomMedia>[];
  for (final e in data) {
    if (e is! Map) continue;
    final src = e['src'];
    if (src is! String) continue;
    final uri = Uri.tryParse(src);
    if (uri == null || uri.scheme != 'https' || !_isCdnHost(uri.host)) {
      continue;
    }
    out.add(DomMedia(url: src, isVideo: e['kind'] == 'video'));
    if (out.length >= 50) break;
  }
  return out;
}
