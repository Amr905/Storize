import 'dart:convert';

/// The only page origin whose hook messages are accepted.
const String allowedHookOrigin = 'https://www.instagram.com';

/// Summary of one instagram.com JSON response seen by the page hook.
///
/// Holds no body and no cookies: only what the spike needs to prove that the
/// page-mode hook sees the same JSON as DevTools.
class CapturedResponse {
  /// Creates a captured summary.
  const CapturedResponse({
    required this.url,
    required this.status,
    required this.bodyLength,
    required this.topLevelKeys,
    this.via = '',
  });

  /// Absolute request URL.
  final String url;

  /// HTTP status.
  final int status;

  /// Length of the response text in characters.
  final int bodyLength;

  /// Top-level JSON keys (capped).
  final List<String> topLevelKeys;

  /// `fetch` or `xhr`.
  final String via;

  /// Host plus path, without the query, for compact display.
  String get shortUrl {
    final uri = Uri.tryParse(url);
    return uri == null ? url : '${uri.host}${uri.path}';
  }
}

/// Parses a message posted by `hook.js`. Returns null if it must be rejected.
///
/// [pageOrigin] is the origin of the page the WebView is showing, as reported
/// by the native side (not by the page). The message is accepted only if that
/// origin AND the origin claimed in the payload both equal
/// [allowedHookOrigin], and the request URL is on instagram.com.
CapturedResponse? parseHookMessage(Object? raw, {required String pageOrigin}) {
  if (pageOrigin != allowedHookOrigin) return null;
  var data = raw;
  if (data is List<Object?> && data.isNotEmpty) data = data.first;
  if (data is String) {
    try {
      data = jsonDecode(data);
    } on FormatException {
      return null;
    }
  }
  if (data is! Map) return null;
  if (data['origin'] != allowedHookOrigin) return null;
  final url = data['url'];
  final status = data['status'];
  final length = data['bodyLength'];
  final keys = data['topLevelKeys'];
  if (url is! String || status is! int || length is! int) return null;
  if (length < 0 || keys is! List) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.scheme != 'https') return null;
  final host = uri.host;
  if (host != 'instagram.com' && !host.endsWith('.instagram.com')) return null;
  final keyStrings = <String>[];
  for (final k in keys) {
    if (k is! String) return null;
    if (keyStrings.length < 50) {
      keyStrings.add(k.length > 80 ? k.substring(0, 80) : k);
    }
  }
  final via = data['via'];
  return CapturedResponse(
    url: url,
    status: status,
    bodyLength: length,
    topLevelKeys: keyStrings,
    via: via is String ? via : '',
  );
}
