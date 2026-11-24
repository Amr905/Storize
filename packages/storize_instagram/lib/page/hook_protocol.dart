import 'dart:convert';

import 'package:storize_instagram/page/hook_config.dart';

/// The `scheme://host` of a frame origin, with the default port dropped.
/// Any other port stays in the string, so it never matches the allow-list.
String originOf(String scheme, String host, [int? port]) {
  final defaultPort = scheme == 'https' ? 443 : (scheme == 'http' ? 80 : 0);
  final showPort = port != null && port > 0 && port != defaultPort;
  return '$scheme://$host${showPort ? ':$port' : ''}';
}

/// Why a hook message was dropped.
enum HookDropReason {
  /// The frame or claimed origin is not instagram.com.
  origin,

  /// The payload has the wrong shape.
  malformed,
}

/// The result of reading one hook message.
sealed class HookMessage {
  const HookMessage();
}

/// A JSON response seen by the hook. Holds the body and, for GraphQL,
/// the page's own `doc_id` and tokens (secret: never printed).
final class HookCapture extends HookMessage {
  /// Creates a capture.
  const HookCapture({
    required this.path,
    required this.status,
    required this.json,
    this.friendlyName,
    this.docId,
    this.tokens = const {},
  });

  /// The URL path (the query is dropped on parsing).
  final String path;

  /// The HTTP status.
  final int status;

  /// The decoded JSON body.
  final Object? json;

  /// `fb_api_req_friendly_name` of the request, when it had one.
  final String? friendlyName;

  /// The request's `doc_id`, when sent. Secret-ish: never log.
  final String? docId;

  /// The request's page tokens. Secret: never log.
  final Map<String, String> tokens;

  @override
  String toString() => 'HookCapture(status: $status)';
}

/// The hook blocked a request locally (never sent).
final class HookBlocked extends HookMessage {
  /// Creates a notice.
  const HookBlocked(this.friendlyName);

  /// The blocked friendly name.
  final String friendlyName;

  @override
  String toString() => 'HookBlocked($friendlyName)';
}

/// A message that was dropped.
final class HookDropped extends HookMessage {
  /// Creates a drop.
  const HookDropped(this.reason);

  /// Why.
  final HookDropReason reason;

  @override
  String toString() => 'HookDropped(${reason.name})';
}

/// The largest body accepted (characters).
const int maxHookBodyLength = 8 * 1024 * 1024;

final RegExp _nameShape = RegExp(r'^[A-Za-z0-9_]{1,120}$');
final RegExp _docIdShape = RegExp(r'^\d{5,32}$');
final RegExp _tokenKeyShape = RegExp(r'^[A-Za-z0-9_]{1,40}$');

bool _isInstagramHost(String host) =>
    host == 'instagram.com' || host.endsWith('.instagram.com');

/// Reads a message posted by `hook.js` (AC5).
///
/// [pageOrigin] is what the native side says about the posting frame. The
/// message is accepted only if that origin AND the origin claimed in the
/// payload are both in [allowedPageOrigins]. Anything else is
/// `HookDropped(origin)`; a bad shape is `HookDropped(malformed)`.
HookMessage parseHookMessage(List<Object?> args, {required String pageOrigin}) {
  if (!allowedPageOrigins.contains(pageOrigin)) {
    return const HookDropped(HookDropReason.origin);
  }
  if (args.isEmpty) return const HookDropped(HookDropReason.malformed);
  var data = args.first;
  if (data is String) {
    try {
      data = jsonDecode(data);
    } on FormatException {
      return const HookDropped(HookDropReason.malformed);
    }
  }
  if (data is! Map) return const HookDropped(HookDropReason.malformed);
  if (!allowedPageOrigins.contains(data['origin'])) {
    return const HookDropped(HookDropReason.origin);
  }
  final type = data['type'];
  final name = data['friendlyName'];
  final friendly = name is String && _nameShape.hasMatch(name) ? name : null;
  if (type == 'blocked') {
    return friendly == null
        ? const HookDropped(HookDropReason.malformed)
        : HookBlocked(friendly);
  }
  // A response message has no `type` (the T-002 format); only a blocked
  // notice has one.
  if (type != null) return const HookDropped(HookDropReason.malformed);

  final url = data['url'];
  final status = data['status'];
  final body = data['body'];
  if (url is! String || status is! int || body is! String) {
    return const HookDropped(HookDropReason.malformed);
  }
  if (body.length > maxHookBodyLength) {
    return const HookDropped(HookDropReason.malformed);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || !_isInstagramHost(uri.host)) {
    return const HookDropped(HookDropReason.origin);
  }
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return const HookDropped(HookDropReason.malformed);
  }
  String? docId;
  final tokens = <String, String>{};
  final request = data['request'];
  if (request is Map) {
    final d = request['docId'];
    if (d is String && _docIdShape.hasMatch(d)) docId = d;
    final t = request['tokens'];
    if (t is Map) {
      t.forEach((k, v) {
        if (k is String &&
            v is String &&
            v.isNotEmpty &&
            _tokenKeyShape.hasMatch(k)) {
          tokens[k] = v;
        }
      });
    }
  }
  return HookCapture(
    path: uri.path,
    status: status,
    json: json,
    friendlyName: friendly,
    docId: docId,
    tokens: Map.unmodifiable(tokens),
  );
}

/// The friendly names of one page load, made safe for the diagnostic log:
/// each reduced to `[A-Za-z0-9_]`, cut to 60 characters, empty ones and
/// duplicates dropped, at most 12 names. Query names are Instagram's code
/// identifiers, not user data. Never pass a doc_id or token here.
List<String> logSafeNames(Iterable<String?> names) {
  final out = <String>[];
  for (final raw in names) {
    if (raw == null) continue;
    var n = raw.replaceAll(RegExp('[^A-Za-z0-9_]'), '');
    if (n.length > 60) n = n.substring(0, 60);
    if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n) || out.contains(n)) continue;
    out.add(n);
    if (out.length >= 12) break;
  }
  return out;
}
