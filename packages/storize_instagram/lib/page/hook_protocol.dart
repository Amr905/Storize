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
    this.provided = const {},
    this.args = const [],
    this.variablesSeen = false,
    this.docIdRejected = false,
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

  /// The `__relay_internal__pv__*` scalars of the request's `variables`
  /// (T-049). Code constants of the web app, not secret.
  final Map<String, Object> provided;

  /// The argument names of the request's `variables` (providers excluded).
  final List<String> args;

  /// The request carried a `variables` object (so an empty [provided] is
  /// real: the query takes none).
  final bool variablesSeen;

  /// The request had a `doc_id` field whose shape was not accepted (for the
  /// diagnostic count only; the value is never kept).
  final bool docIdRejected;

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

/// One operation read from the page's module system (T-048). The doc_id is
/// session-bound (never logged); the provider values and argument names are
/// code constants of the web app (not secret).
final class DiscoveredOp {
  /// Creates an op.
  const DiscoveredOp({
    required this.name,
    required this.docId,
    this.provided = const {},
    this.args = const [],
    this.loaded = false,
    this.source = 'none',
  });

  /// The operation name (for example `PolarisProfilePostsQuery`).
  final String name;

  /// The `doc_id`. Never log.
  final String docId;

  /// `__relay_internal__pv__X` to its current bool, number or short string.
  final Map<String, Object> provided;

  /// The argument names of the operation.
  final List<String> args;

  /// The op's `.graphql` module was loaded, so an empty [provided] is real.
  final bool loaded;

  /// Where [provided] came from: `module`, `capture` or `none`.
  final String source;

  @override
  String toString() => 'DiscoveredOp($name)';
}

/// What the hook read from the page's own modules, without any request.
final class HookDiscovery extends HookMessage {
  /// Creates a discovery.
  const HookDiscovery({
    this.ops = const [],
    this.tokens = const {},
    this.tokenSources = const {},
    this.error,
  });

  /// The operations that resolved (empty on failure).
  final List<DiscoveredOp> ops;

  /// `fb_dtsg` and `lsd`, when present. Secret: never printed.
  final Map<String, String> tokens;

  /// Where each token came from (`module` or `capture`), by token name.
  final Map<String, String> tokenSources;

  /// The error code of a failed routine (letters and underscores).
  final String? error;

  @override
  String toString() => 'HookDiscovery(ops: ${ops.length})';
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
final RegExp _providerKeyShape = RegExp(
  r'^__relay_internal__pv__[A-Za-z0-9_]{1,100}$',
);
final RegExp _argShape = RegExp(r'^[a-z_]{1,64}$');
final RegExp _errorShape = RegExp(r'^[a-z_]{1,40}$');
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
  if (type == 'discovery') return _parseDiscovery(data);
  // A response message has no `type` (the T-002 format); only a blocked
  // notice and a discovery have one.
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
  var docIdRejected = false;
  final tokens = <String, String>{};
  final provided = <String, Object>{};
  final argNames = <String>[];
  var variablesSeen = false;
  final request = data['request'];
  if (request is Map) {
    final d = request['docId'];
    if (d is String) {
      if (_docIdShape.hasMatch(d)) {
        docId = d;
      } else {
        docIdRejected = true;
      }
    }
    final pv = request['provided'];
    if (pv is Map && pv.length <= 40) {
      pv.forEach((k, v) {
        if (k is String &&
            _providerKeyShape.hasMatch(k) &&
            (v is bool ||
                (v is num && v.isFinite) ||
                (v is String && v.length <= 64))) {
          provided[k] = v as Object;
        }
      });
    }
    variablesSeen = request['vars'] == true;
    final av = request['args'];
    if (av is List && av.length <= 40) {
      for (final a in av) {
        if (a is String && _argShape.hasMatch(a)) argNames.add(a);
      }
    }
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
    provided: Map.unmodifiable(provided),
    args: List.unmodifiable(argNames),
    variablesSeen: variablesSeen,
    docIdRejected: docIdRejected,
  );
}

/// Reads a `discovery` message with strict shapes (T-048). A malformed part
/// is dropped; a malformed container drops the message.
HookMessage _parseDiscovery(Map<Object?, Object?> data) {
  const bad = HookDropped(HookDropReason.malformed);
  final rawOps = data['ops'];
  if (rawOps is! List || rawOps.length > 12) return bad;
  final ops = <DiscoveredOp>[];
  final seen = <String>{};
  for (final raw in rawOps) {
    if (raw is! Map) return bad;
    final name = raw['name'];
    final docId = raw['docId'];
    if (name is! String || !_nameShape.hasMatch(name)) return bad;
    if (docId is! String || !_docIdShape.hasMatch(docId)) return bad;
    final provided = <String, Object>{};
    final rawProvided = raw['provided'];
    if (rawProvided != null) {
      if (rawProvided is! Map || rawProvided.length > 40) return bad;
      for (final e in rawProvided.entries) {
        final k = e.key;
        final v = e.value;
        if (k is! String || !_providerKeyShape.hasMatch(k)) return bad;
        final ok =
            v is bool ||
            (v is num && v.isFinite) ||
            (v is String && v.length <= 64);
        if (!ok) return bad;
        provided[k] = v! as Object;
      }
    }
    final args = <String>[];
    final rawArgs = raw['args'];
    if (rawArgs != null) {
      if (rawArgs is! List || rawArgs.length > 40) return bad;
      for (final a in rawArgs) {
        if (a is! String || !_argShape.hasMatch(a)) return bad;
        args.add(a);
      }
    }
    if (!seen.add(name)) continue;
    ops.add(
      DiscoveredOp(
        name: name,
        docId: docId,
        provided: Map.unmodifiable(provided),
        args: List.unmodifiable(args),
        loaded: raw['loaded'] == true,
        source: switch (raw['src']) {
          'module' => 'module',
          'capture' => 'capture',
          _ => 'none',
        },
      ),
    );
  }
  final tokenSources = <String, String>{};
  final rawSources = data['tokenSources'];
  if (rawSources is Map) {
    for (final key in const ['fb_dtsg', 'lsd']) {
      final v = rawSources[key];
      if (v == 'module' || v == 'capture') tokenSources[key] = v as String;
    }
  }
  final tokens = <String, String>{};
  final rawTokens = data['tokens'];
  if (rawTokens != null) {
    if (rawTokens is! Map) return bad;
    for (final key in const ['fb_dtsg', 'lsd']) {
      final v = rawTokens[key];
      if (v == null) continue;
      if (v is! String || v.isEmpty || v.length > 4096) return bad;
      tokens[key] = v;
    }
  }
  final error = data['error'];
  String? code;
  if (error != null) {
    if (error is! String || !_errorShape.hasMatch(error)) return bad;
    code = error;
  }
  return HookDiscovery(
    ops: List.unmodifiable(ops),
    tokens: Map.unmodifiable(tokens),
    tokenSources: Map.unmodifiable(tokenSources),
    error: code,
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
