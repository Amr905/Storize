// HAR sanitizer for the T-002 extraction spike.
//
// Plain Dart only (dart:io + dart:convert). No Flutter, no packages, so it
// runs on a Windows PC that only has the Dart SDK:
//
//   dart packages/storize_instagram/tool/sanitize_har.dart <in.har> <out_dir>
//
// Reads a HAR exported from Chrome DevTools and writes ONLY:
//   <out_dir>/summary.json   one row per instagram.com JSON request
//   <out_dir>/report.md      candidate endpoints seen, unknown requests,
//                            auto-detected media fields
//   <out_dir>/bodies/NNN_*.json  sanitized copy of each JSON response body
//
// Fails closed: if any output still looks like a cookie, token or signed
// URL, it exits 1 and writes nothing. Exit codes: 0 ok, 1 leak, 2 bad input.
// Long Markdown table strings and simple loops: lint noise only.
// ignore_for_file: lines_longer_than_80_chars, avoid_function_literals_in_foreach_calls

import 'dart:convert';
import 'dart:io';

/// Marker for removed secret values.
const String redacted = '<redacted>';

/// Query keys whose values are structural and safe to keep.
const Set<String> _safeQueryKeys = {
  'count',
  'doc_id',
  'query_hash',
  'first',
  'edit',
  '__a',
  '__d',
};

/// Query keys that carry user IDs (replaced by consistent placeholders).
const Set<String> _idQueryKeys = {
  'reel_ids',
  'user_id',
  'user_ids',
  'id',
  'ids',
};

/// Query keys that carry usernames.
const Set<String> _usernameQueryKeys = {'username', 'user', 'q'};

/// Request header values we keep (everything else: name only).
const Set<String> _keptHeaderValues = {
  'x-ig-app-id',
  'user-agent',
  'content-type',
  'accept',
};

/// JSON keys whose value is a secret or device/session identifier.
const Set<String> _secretKeys = {
  'sessionid',
  'csrftoken',
  'csrf_token',
  'ds_user_id',
  'mid',
  'ig_did',
  'rur',
  'shbid',
  'shbts',
  'datr',
  'ig_nrcb',
  'cookie',
  'set-cookie',
  'authorization',
  'x-ig-www-claim',
  'password',
  'enc_password',
  'access_token',
  'token',
  'fb_dtsg',
  'lsd',
  'jazoest',
  'device_id',
  'phone_id',
  'family_device_id',
  'adid',
  'uuid',
};

const Set<String> _usernameKeys = {
  'username',
  'ig_username',
  'owner_username',
  'viewer_username',
  'fb_username',
};

/// Pagination cursors are opaque and can encode IDs.
const Set<String> _cursorKeys = {
  'next_max_id',
  'max_id',
  'end_cursor',
  'cursor',
  'next_cursor',
  'paging_token',
};

const Set<String> _geoKeys = {'lat', 'lng', 'latitude', 'longitude'};
const Set<String> _redactKeys = {'external_url', 'address', 'city'};

/// ID-like keys that are public constants, not per-user identifiers.
const Set<String> _notIdKeys = {'app_id', 'ig_app_id', 'doc_id'};

/// Top-level paths on instagram.com that are not usernames.
const Set<String> _knownTopPaths = {
  'api',
  'graphql',
  'p',
  'reel',
  'reels',
  'stories',
  'explore',
  'accounts',
  'tv',
  'direct',
  'web',
  'static',
  'ajax',
  'challenge',
  'oauth',
  'emailsignup',
  'logging',
  'rsrc.php',
  'data',
  'async',
  'qp',
};

/// Fields the developers look for in every body.
const Set<String> _mediaFieldKeys = {
  'video_versions',
  'image_versions2',
  'carousel_media',
  'expiring_at',
  'taken_at',
  'product_type',
  'media_type',
  'has_audio',
  'video_duration',
  'video_url',
  'display_url',
  'display_resources',
  'is_video',
  'edge_sidecar_to_children',
  'taken_at_timestamp',
};

const List<String> _htmlMarkers = [
  'image_versions2',
  'video_versions',
  'carousel_media',
  'video_dash_manifest',
  'xdt_api',
  'edge_owner_to_timeline_media',
  '/api/v1/',
];

typedef _Candidate = ({String id, String purpose, String shown, RegExp path});

final List<_Candidate> _candidates = [
  (
    id: 'IG-1',
    purpose: 'Username -> user (add, refresh)',
    shown: 'GET /api/v1/users/web_profile_info/?username={u}',
    path: RegExp(r'^/api/v1/users/web_profile_info/?$'),
  ),
  (
    id: 'IG-2',
    purpose: 'Stories for up to 20 users',
    shown: 'GET /api/v1/feed/reels_media/?reel_ids={id}&reel_ids=...',
    path: RegExp(r'^/api/v1/feed/reels_media/?$'),
  ),
  (
    id: 'IG-3',
    purpose: 'User by ID',
    shown: 'GET i.instagram.com/api/v1/users/{id}/info/',
    path: RegExp(r'^/api/v1/users/\d+/info/?$'),
  ),
  (
    id: 'IG-4',
    purpose: 'Validate session',
    shown: 'GET /api/v1/accounts/current_user/?edit=true',
    path: RegExp(r'^/api/v1/accounts/current_user/?$'),
  ),
  (
    id: 'IG-5',
    purpose: 'Latest posts of a user',
    shown: 'GET /api/v1/feed/user/{id}/?count=12',
    path: RegExp(r'^/api/v1/feed/user/[^/]+/(username/)?$'),
  ),
];

// ---------------------------------------------------------------------------
// Leak scanner (independent last line of defence)
// ---------------------------------------------------------------------------

final RegExp _cookieAssign = RegExp(
  r'\b(sessionid|csrftoken|ds_user_id|ig_did|rur|mid|fbsr_[A-Za-z0-9_]*)='
  r'(?!<redacted>)[^\s;&"\x27<>]+',
);
final RegExp _secretJsonKey = RegExp(
  '"(sessionid|csrftoken|ds_user_id|ig_did|rur|mid|fbsr_[A-Za-z0-9_]*|'
  r'authorization|set-cookie|cookie)"\s*:\s*(?!"<redacted>")\S',
  caseSensitive: false,
);
final RegExp _setCookieText = RegExp(
  r'set-cookie\s*[:=]',
  caseSensitive: false,
);
final RegExp _signedUrl = RegExp(
  r'(?:https?:)?//[^\s"\x27<>]*\?(?!<redacted>)[^\s"\x27<>]+',
);
final RegExp _signedParam = RegExp(
  '[?&;](?:oh|oe|_nc_[a-z0-9]+|sig|signature|ccb|efg)=',
  caseSensitive: false,
);
final RegExp _tokenRun = RegExp('[A-Za-z0-9+_=-]{32,}');

/// True if [run] (a 32+ char run) looks like a hex/base64 secret.
bool looksLikeSecretToken(String run) {
  if (run.length < 32) return false;
  if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(run)) return true;
  final hasUpper = RegExp('[A-Z]').hasMatch(run);
  final hasLower = RegExp('[a-z]').hasMatch(run);
  final hasDigit = RegExp('[0-9]').hasMatch(run);
  return hasUpper && hasLower && hasDigit;
}

/// Finds anything in [text] that still looks like a secret. Returns kinds
/// only (never the matched text), so the report itself cannot leak.
List<String> findLeaks(String text) {
  final kinds = <String>[];
  if (_cookieAssign.hasMatch(text)) kinds.add('cookie assignment');
  if (_secretJsonKey.hasMatch(text)) kinds.add('cookie/session JSON key');
  if (_setCookieText.hasMatch(text)) kinds.add('Set-Cookie');
  if (_signedUrl.hasMatch(text)) kinds.add('URL with unredacted query');
  if (_signedParam.hasMatch(text)) kinds.add('signed URL parameter');
  if (_tokenRun.allMatches(text).any((m) => looksLikeSecretToken(m[0]!))) {
    kinds.add('long hex/base64 token');
  }
  return kinds;
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Outcome of [sanitizeHar].
class SanitizeOutcome {
  /// Creates an outcome.
  SanitizeOutcome({required this.files, required this.leaks});

  /// Relative path -> content. Empty when [leaks] is not empty.
  final Map<String, String> files;

  /// `file: kind` findings from the final scan.
  final List<String> leaks;

  /// True when nothing leaked.
  bool get ok => leaks.isEmpty;
}

class _FieldStat {
  int count = 0;
  final Set<int> requests = {};
  final Set<String> types = {};
  final Set<String> values = {};
}

// ---------------------------------------------------------------------------
// Sanitizer state: consistent placeholders across the whole HAR
// ---------------------------------------------------------------------------

class _Ctx {
  final Map<String, String> _ids = {};
  final Map<String, String> _names = {};
  final Map<String, String> _namedTexts = {};
  final Map<String, int> counts = {};
  final Set<String> knownUsers = {};
  final Set<String> knownMedia = {};
  final Map<String, Set<String>> idTypes = {};
  final Map<String, _FieldStat> fields = {};
  final Map<int, Set<String>> fieldsByRequest = {};
  int currentRequest = 0;

  int _next(String kind) => counts[kind] = (counts[kind] ?? 0) + 1;

  /// Consistent placeholder for [raw] in namespace [kind].
  String named(String kind, String raw) =>
      _names.putIfAbsent('$kind|$raw', () => '${kind}_${_next(kind)}');

  /// Consistent `<label n>` placeholder for free text.
  String text(String label, String raw) => _namedTexts.putIfAbsent(
    '$label|$raw',
    () => '<$label ${_next(label)}>',
  );

  /// Placeholder name (`user_1` / `media_1`) for numeric ID [digits].
  String idName(String digits, String hint) => _ids.putIfAbsent(digits, () {
    final kind = knownUsers.contains(digits)
        ? 'user'
        : knownMedia.contains(digits)
        ? 'media'
        : hint;
    return '${kind}_${_next(kind)}';
  });
}

final RegExp _digitsId = RegExp(r'^\d{5,}$');
final RegExp _compoundId = RegExp(r'^(\d{5,})_(\d{5,})$');

bool _isIdKey(String lk) {
  if (_notIdKeys.contains(lk)) return false;
  return lk == 'pk' ||
      lk == 'id' ||
      lk == 'fbid' ||
      lk.endsWith('_id') ||
      lk.endsWith('_ids') ||
      lk.endsWith('_pk') ||
      lk.endsWith('id__') ||
      lk.endsWith('fbid') ||
      lk.endsWith('fbid_v2');
}

String _hintFor(String lk, String parentKey) {
  const userish = ['user', 'owner', 'profile', 'viewer', 'reel', 'author'];
  final k = lk.toLowerCase();
  final p = parentKey.toLowerCase();
  if (userish.any(k.contains)) return 'user';
  if ((k == 'pk' || k == 'id') && userish.any(p.contains)) return 'user';
  return 'media';
}

/// Replaces an ID value, keeping its JSON type (int stays int).
Object? _mapId(_Ctx c, String key, Object? v, String hint) {
  if (v is int && v.toString().length >= 5) {
    c.idTypes.putIfAbsent(key, () => {}).add('int');
    final name = c.idName(v.toString(), hint);
    final n = int.parse(name.split('_').last);
    return (name.startsWith('user') ? 7000000000 : 8000000000) + n;
  }
  if (v is String) {
    if (_digitsId.hasMatch(v)) {
      c.idTypes.putIfAbsent(key, () => {}).add('digit-string');
      return c.idName(v, hint);
    }
    final m = _compoundId.firstMatch(v);
    if (m != null) {
      c.idTypes.putIfAbsent(key, () => {}).add('compound-string');
      return '${c.idName(m[1]!, 'media')}_${c.idName(m[2]!, 'user')}';
    }
  }
  return v;
}

// ---------------------------------------------------------------------------
// String scrubbing
// ---------------------------------------------------------------------------

final RegExp _urlRe = RegExp(
  r'(?:https?:)?//[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(?::\d+)?'
  r'(?:/[^\s"\x27<>\\]*)?',
);

bool _isIgHost(String host) =>
    host == 'instagram.com' || host.endsWith('.instagram.com');

String _scrubSegments(
  _Ctx c,
  List<String> segs, {
  required bool igPage,
}) {
  final out = <String>[];
  for (var i = 0; i < segs.length; i++) {
    final seg = segs[i];
    final prev = i > 0 ? segs[i - 1] : '';
    final next = i + 1 < segs.length ? segs[i + 1] : '';
    if (seg.isEmpty) {
      out.add(seg);
    } else if (igPage && const ['p', 'reel', 'reels', 'tv'].contains(prev)) {
      out.add(c.named('code', seg));
    } else if (igPage && prev == 'stories' && seg != 'highlights') {
      out.add(
        _digitsId.hasMatch(seg)
            ? c.idName(seg, 'user')
            : c.named('username', seg),
      );
    } else if (_digitsId.hasMatch(seg)) {
      out.add(c.idName(seg, prev == 'media' ? 'media' : 'user'));
    } else if (igPage && i == 0 && !_knownTopPaths.contains(seg)) {
      out.add(c.named('username', seg));
    } else if (igPage && prev == 'user' && next == 'username') {
      out.add(c.named('username', seg));
    } else if (!igPage) {
      final dot = seg.lastIndexOf('.');
      final hasExt = dot > 0 && seg.length - dot <= 5;
      final base = hasExt ? seg.substring(0, dot) : seg;
      final ext = hasExt ? seg.substring(dot) : '';
      if (base.length > 20 || RegExp(r'\d{6,}').hasMatch(base)) {
        out.add('<seg>$ext');
      } else {
        out.add(seg);
      }
    } else {
      out.add(seg);
    }
  }
  return out.join('/');
}

/// Rewrites every URL inside [s]: path IDs hashed, query -> `?<redacted>`.
String _scrubUrls(_Ctx c, String s) {
  return s.replaceAllMapped(_urlRe, (m) {
    final raw = m[0]!;
    final schemeEnd = raw.indexOf('//');
    final scheme = raw.substring(0, schemeEnd);
    var rest = raw.substring(schemeEnd + 2);
    final hash = rest.indexOf('#');
    if (hash >= 0) rest = rest.substring(0, hash);
    final q = rest.indexOf('?');
    final hasQuery = q >= 0;
    final beforeQuery = hasQuery ? rest.substring(0, q) : rest;
    final slash = beforeQuery.indexOf('/');
    final host = slash < 0 ? beforeQuery : beforeQuery.substring(0, slash);
    final path = slash < 0 ? '' : beforeQuery.substring(slash);
    final hostOnly = host.split(':').first.toLowerCase();
    final cleanPath = path.isEmpty
        ? ''
        : '/${_scrubSegments(c, path.substring(1).split('/'), igPage: _isIgHost(hostOnly))}';
    return '$scheme//$host$cleanPath${hasQuery ? '?<redacted>' : ''}';
  });
}

String _scrubString(_Ctx c, String s) {
  var out = s.replaceAllMapped(
    RegExp(
      r'\b(sessionid|csrftoken|ds_user_id|ig_did|rur|mid|fbsr_[A-Za-z0-9_]*)='
      r'[^\s;&"\x27<>]+',
    ),
    (m) => '${m[1]}=$redacted',
  );
  out = _scrubUrls(c, out);
  if (!out.contains(RegExp(r'\s')) && looksLikeSecretToken(out)) {
    return '<token>';
  }
  return out;
}

// ---------------------------------------------------------------------------
// JSON walking
// ---------------------------------------------------------------------------

String _typeOf(Object? v) => switch (v) {
  null => 'null',
  bool() => 'bool',
  int() => 'int',
  double() => 'double',
  String() => 'string',
  List<Object?>() => 'array',
  Map<String, Object?>() => 'object',
  _ => 'other',
};

/// Prepass: learn which IDs belong to users and which to media.
void _collectKnown(_Ctx c, Object? node) {
  if (node is Map<String, Object?>) {
    final isUser = node['username'] is String;
    final isMedia =
        node.containsKey('media_type') &&
        (node.containsKey('code') || node.containsKey('taken_at'));
    for (final k in const ['pk', 'pk_id', 'id', 'strong_id__']) {
      final v = node[k];
      final s = v is int ? v.toString() : (v is String ? v : null);
      if (s == null) continue;
      final m = _compoundId.firstMatch(s);
      final first = m != null ? m[1]! : s;
      if (!_digitsId.hasMatch(first)) continue;
      if (isUser) c.knownUsers.add(first);
      if (isMedia) {
        c.knownMedia.add(first);
        if (m != null) c.knownUsers.add(m[2]!);
      }
    }
    node.values.forEach((v) => _collectKnown(c, v));
  } else if (node is List<Object?>) {
    node.forEach((v) => _collectKnown(c, v));
  }
}

String _mapKey(_Ctx c, String k, String parentKey) {
  if (_digitsId.hasMatch(k) || _compoundId.hasMatch(k)) {
    final m = _compoundId.firstMatch(k);
    if (m != null) {
      return '${c.idName(m[1]!, 'media')}_${c.idName(m[2]!, 'user')}';
    }
    return c.idName(k, _hintFor(parentKey, ''));
  }
  if (looksLikeSecretToken(k) && !k.contains(RegExp(r'\s'))) {
    return c.named('token_key', k);
  }
  return k;
}

void _recordField(_Ctx c, String lk, String path, Object? v) {
  final isDash = lk.contains('dash_manifest');
  if (!_mediaFieldKeys.contains(lk) && !isDash) return;
  final label = isDash ? 'dash_manifest' : lk;
  final stat = c.fields.putIfAbsent('$label|$path', _FieldStat.new);
  stat.count++;
  stat.requests.add(c.currentRequest);
  stat.types.add(_typeOf(v));
  if ((lk == 'product_type' || lk == 'media_type' || lk == 'has_audio') &&
      (v is String || v is int || v is bool) &&
      stat.values.length < 8) {
    stat.values.add('$v');
  }
  c.fieldsByRequest.putIfAbsent(c.currentRequest, () => {}).add(label);
}

Object? _walk(
  _Ctx c,
  Object? node, {
  required String key,
  required String parentKey,
  required String path,
}) {
  if (node is Map<String, Object?>) {
    final out = <String, Object?>{};
    node.forEach((k, v) {
      final lk = k.toLowerCase();
      final newKey = _mapKey(c, k, key);
      final idKey = newKey != k;
      final childPath = '$path.${idKey ? '*' : newKey}';
      _recordField(c, lk, childPath, v);
      if (v == null) {
        out[newKey] = null;
      } else if (_secretKeys.contains(lk) || lk.startsWith('fbsr_')) {
        out[newKey] = redacted;
      } else if (_redactKeys.contains(lk)) {
        out[newKey] = v is String || v is num ? redacted : v;
      } else if (v is num && _geoKeys.contains(lk)) {
        out[newKey] = 0;
      } else if (v is String && _cursorKeys.contains(lk)) {
        out[newKey] = '<cursor>';
      } else if (v is String && _usernameKeys.contains(lk)) {
        out[newKey] = c.named('username', v);
      } else if (v is String && lk == 'full_name') {
        out[newKey] = c.named('name', v);
      } else if (v is String && (lk == 'biography' || lk == 'bio')) {
        out[newKey] = c.text('bio', v);
      } else if (v is String && (lk == 'caption' || lk == 'title')) {
        out[newKey] = c.text(lk == 'caption' ? 'caption' : 'title', v);
      } else if (v is String && lk == 'text') {
        out[newKey] = c.text(
          key.toLowerCase() == 'caption' ? 'caption' : 'text',
          v,
        );
      } else if (v is String && lk == 'accessibility_caption') {
        out[newKey] = c.text('alt', v);
      } else if (v is String &&
          (lk == 'code' || lk == 'shortcode') &&
          RegExp(r'^[A-Za-z0-9_-]{8,16}$').hasMatch(v)) {
        out[newKey] = c.named('code', v);
      } else if ((v is String || v is int) && _isIdKey(lk)) {
        out[newKey] = _mapId(c, lk, v, _hintFor(lk, key));
      } else if (v is String) {
        out[newKey] = _scrubString(c, v);
      } else if (v is Map<String, Object?> || v is List<Object?>) {
        out[newKey] = _walk(
          c,
          v,
          key: k,
          parentKey: key,
          path: childPath,
        );
      } else {
        out[newKey] = v;
      }
    });
    return out;
  }
  if (node is List<Object?>) {
    return [
      for (final e in node)
        if (e is Map<String, Object?> || e is List<Object?>)
          _walk(c, e, key: key, parentKey: parentKey, path: '$path[]')
        else if ((e is String || e is int) && _isIdKey(key.toLowerCase()))
          _mapId(
            c,
            key.toLowerCase(),
            e,
            _hintFor(key.toLowerCase(), parentKey),
          )
        else if (e is String)
          _scrubString(c, e)
        else
          e,
    ];
  }
  return node;
}

// ---------------------------------------------------------------------------
// HAR handling
// ---------------------------------------------------------------------------

Map<String, Object?>? _asMap(Object? v) => v is Map<String, Object?>
    ? v
    : (v is Map ? v.cast<String, Object?>() : null);

List<Object?> _asList(Object? v) => v is List ? v.cast<Object?>() : const [];

Object? _decodeBody(Map<String, Object?> content) {
  var text = content['text'];
  if (text is! String || text.isEmpty) return null;
  if ('${content['encoding']}'.toLowerCase() == 'base64') {
    try {
      text = utf8.decode(base64.decode(text), allowMalformed: true);
    } on FormatException {
      return null;
    }
  }
  var t = text.trim();
  if (t.startsWith('for (;;);')) t = t.substring(9);
  try {
    return jsonDecode(t);
  } on FormatException {
    return null;
  }
}

String _bodyText(Map<String, Object?> content) {
  final text = content['text'];
  if (text is! String) return '';
  if ('${content['encoding']}'.toLowerCase() == 'base64') {
    try {
      return utf8.decode(base64.decode(text), allowMalformed: true);
    } on FormatException {
      return '';
    }
  }
  return text;
}

String _describeParam(_Ctx c, String key, String value) {
  final lk = key.toLowerCase();
  if (_safeQueryKeys.contains(lk)) return value;
  if (_idQueryKeys.contains(lk)) {
    return value
        .split(',')
        .map(
          (p) => _digitsId.hasMatch(p) ? c.idName(p, 'user') : '<v>',
        )
        .join(',');
  }
  if (_usernameQueryKeys.contains(lk)) return c.named('username', value);
  return '<v>';
}

Map<String, Object?> _describeParams(
  _Ctx c,
  List<MapEntry<String, String>> kv,
) {
  final out = <String, Object?>{};
  for (final e in kv) {
    final shown = e.key.toLowerCase() == 'variables'
        ? '<json keys: ${_jsonKeys(e.value)}>'
        : _describeParam(c, e.key, e.value);
    final prev = out[e.key];
    if (prev == null) {
      out[e.key] = shown;
    } else if (prev is List<Object?>) {
      prev.add(shown);
    } else {
      out[e.key] = <Object?>[prev, shown];
    }
  }
  return out;
}

String _jsonKeys(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is Map) return v.keys.join(',');
  } on FormatException {
    // fall through
  }
  return 'unparseable';
}

List<MapEntry<String, String>> _parseForm(String s) {
  final out = <MapEntry<String, String>>[];
  for (final part in s.split('&')) {
    if (part.isEmpty) continue;
    final i = part.indexOf('=');
    final k = i < 0 ? part : part.substring(0, i);
    final v = i < 0 ? '' : part.substring(i + 1);
    try {
      out.add(
        MapEntry(Uri.decodeQueryComponent(k), Uri.decodeQueryComponent(v)),
      );
    } on FormatException {
      out.add(MapEntry(k, '<v>'));
    }
  }
  return out;
}

String _slug(String sanitizedPath) {
  final segs = sanitizedPath
      .split('/')
      .where((s) => RegExp(r'^[a-z]+(_[a-z]+)*$').hasMatch(s))
      .where((s) => s != 'api' && s != 'v1')
      .toList();
  final tail = segs.length > 2 ? segs.sublist(segs.length - 2) : segs;
  final slug = tail.join('_');
  if (slug.isEmpty) return 'request';
  return slug.length > 20 ? slug.substring(0, 20) : slug;
}

String _mdCell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// Sanitizes a HAR document and returns the files to write.
SanitizeOutcome sanitizeHar(String harText) {
  final root = _asMap(jsonDecode(harText));
  final entries = _asList(_asMap(root?['log'])?['entries']);
  if (root == null || _asMap(root['log']) == null) {
    throw const FormatException('Not a HAR file (no "log" object).');
  }

  final c = _Ctx();

  // Pass 1: select entries and learn user/media IDs.
  final selected = <({Map<String, Object?> entry, Object? body, Uri uri})>[];
  final htmlHits = <({String path, int status, List<String> markers})>[];
  var otherIg = 0;
  var noBody = 0;
  var unparseable = 0;
  final parsed = <Object?>[];
  final prepared = <Map<String, Object?>>[];
  for (final raw in entries) {
    final e = _asMap(raw);
    if (e == null) continue;
    final req = _asMap(e['request']);
    final res = _asMap(e['response']);
    if (req == null || res == null) continue;
    final uri = Uri.tryParse('${req['url']}');
    if (uri == null || !_isIgHost(uri.host)) continue;
    final content = _asMap(res['content']) ?? <String, Object?>{};
    final mime = '${content['mimeType']}'.toLowerCase();
    final looksJson =
        mime.contains('json') ||
        (_bodyText(content)
            .trimLeft()
            .startsWith(RegExp(r'[{\[]|for \(;;\);')));
    if (!looksJson) {
      if (mime.contains('html')) {
        final text = _bodyText(content);
        final hits = [
          for (final m in _htmlMarkers)
            if (text.contains(m)) m,
        ];
        htmlHits.add((
          path: uri.path,
          status: (res['status'] as num?)?.toInt() ?? 0,
          markers: hits,
        ));
      } else {
        otherIg++;
      }
      continue;
    }
    final body = _decodeBody(content);
    if (body == null) {
      if (content['text'] is! String) {
        noBody++;
      } else {
        unparseable++;
      }
    } else {
      parsed.add(body);
    }
    selected.add((entry: e, body: body, uri: uri));
    prepared.add(e);
  }
  parsed.forEach((b) => _collectKnown(c, b));

  // Pass 2: sanitize.
  final files = <String, String>{};
  final rows = <Map<String, Object?>>[];
  final seenCandidates = <String, List<int>>{};
  final candidateStatus = <String, Set<int>>{};
  final unknown = <Map<String, Object?>>[];
  const enc = JsonEncoder.withIndent('  ');

  var n = 0;
  for (final s in selected) {
    n++;
    c.currentRequest = n;
    final req = _asMap(s.entry['request'])!;
    final res = _asMap(s.entry['response'])!;
    final content = _asMap(res['content']) ?? <String, Object?>{};
    final status = (res['status'] as num?)?.toInt() ?? 0;
    final method = '${req['method']}'.toUpperCase();
    final rawPath = s.uri.path;

    // URL path with IDs hashed; query keys kept, values replaced.
    final segs = rawPath.isEmpty ? <String>[] : rawPath.substring(1).split('/');
    final cleanPath = '/${_scrubSegments(c, segs, igPage: true)}'.replaceAll(
      '//',
      '/',
    );
    final query = _parseForm(s.uri.hasQuery ? s.uri.query : '');
    final headers = _asList(req['headers']);
    final names = <String>[];
    final kept = <String, String>{};
    for (final h in headers) {
      final m = _asMap(h);
      if (m == null) continue;
      final name = '${m['name']}'.toLowerCase();
      if (!names.contains(name)) names.add(name);
      if (_keptHeaderValues.contains(name)) {
        kept[name] = _scrubString(c, '${m['value']}');
      }
    }
    final post = _asMap(req['postData']);
    List<MapEntry<String, String>>? postParams;
    if (post != null) {
      final mt = '${post['mimeType']}'.toLowerCase();
      final pt = post['text'];
      if (pt is String && mt.contains('x-www-form-urlencoded')) {
        postParams = _parseForm(pt);
      } else if (post['params'] is List) {
        postParams = [
          for (final p in _asList(post['params']))
            if (_asMap(p) != null)
              MapEntry('${_asMap(p)!['name']}', '${_asMap(p)!['value']}'),
        ];
      }
    }
    final size = (content['size'] as num?)?.toInt() ?? 0;
    final textLen = _bodyText(content).length;

    String? bodyFile;
    if (s.body != null) {
      final sanitized = _walk(c, s.body, key: '', parentKey: '', path: r'$');
      final idx = n.toString().padLeft(3, '0');
      bodyFile = 'bodies/${idx}_${_slug(cleanPath)}.json';
      files[bodyFile] = '${enc.convert(sanitized)}\n';
    }

    String? candidate;
    for (final cand in _candidates) {
      if (cand.path.hasMatch(rawPath)) {
        candidate = cand.id;
        seenCandidates.putIfAbsent(cand.id, () => []).add(n);
        candidateStatus.putIfAbsent(cand.id, () => {}).add(status);
      }
    }

    final row = <String, Object?>{
      'n': n,
      'method': method,
      'host': s.uri.host,
      'path': cleanPath,
      'query': _describeParams(c, query),
      if (postParams != null) 'postParams': _describeParams(c, postParams),
      'requestHeaderNames': names,
      'requestHeaders': kept,
      'status': status,
      'mimeType': '${content['mimeType']}',
      'responseSize': size > 0 ? size : textLen,
      'bodyFile': bodyFile,
      'bodyNote': s.body == null
          ? (content['text'] is String
                ? 'body is not parseable JSON'
                : 'HAR has no response body (export with content)')
          : null,
      'candidate': candidate,
    };
    rows.add(row);
    if (candidate == null) unknown.add(row);
  }

  // summary.json
  final summary = <String, Object?>{
    'tool': 'sanitize_har',
    'version': 1,
    'harEntries': entries.length,
    'jsonRequests': rows.length,
    'requests': rows,
  };
  files['summary.json'] = '${enc.convert(summary)}\n';

  // report.md
  final b = StringBuffer()
    ..writeln('# HAR sanitizer report')
    ..writeln()
    ..writeln('- HAR entries: ${entries.length}')
    ..writeln('- instagram.com JSON requests kept: ${rows.length}')
    ..writeln('- other instagram.com non-JSON responses skipped: $otherIg')
    ..writeln('- JSON responses with no body in the HAR: $noBody')
    ..writeln('- JSON responses that did not parse: $unparseable')
    ..writeln()
    ..writeln('## Candidate requests (TECH_SPEC 4.1)')
    ..writeln()
    ..writeln('| ID | Purpose | Candidate | Seen | Request #s | Status |')
    ..writeln('|----|---------|-----------|------|------------|--------|');
  for (final cand in _candidates) {
    final seen = seenCandidates[cand.id];
    b.writeln(
      '| ${cand.id} | ${_mdCell(cand.purpose)} | `${_mdCell(cand.shown)}` | '
      '${seen == null ? 'no' : 'yes'} | ${seen?.join(', ') ?? '-'} | '
      '${(candidateStatus[cand.id] ?? {}).join(', ').isEmpty ? '-' : candidateStatus[cand.id]!.join(', ')} |',
    );
  }
  b
    ..writeln()
    ..writeln('## Unknown JSON requests (not IG-1..IG-5)')
    ..writeln();
  if (unknown.isEmpty) {
    b.writeln('None.');
  } else {
    b
      ..writeln(
        '| # | Method | Host | Path | Query keys | Status | Size | Media fields |',
      )
      ..writeln(
        '|---|--------|------|------|------------|--------|------|--------------|',
      );
    for (final r in unknown) {
      final nn = r['n']! as int;
      final q = (r['query']! as Map<String, Object?>).keys.join(', ');
      b.writeln(
        '| $nn | ${r['method']} | ${r['host']} | `${_mdCell('${r['path']}')}` | '
        '${_mdCell(q)} | ${r['status']} | ${r['responseSize']} | '
        '${(c.fieldsByRequest[nn] ?? {}).toList().join(', ')} |',
      );
    }
  }
  b
    ..writeln()
    ..writeln('## Auto-detected media fields')
    ..writeln();
  if (c.fields.isEmpty) {
    b.writeln('None found.');
  } else {
    b
      ..writeln(
        '| Field | JSON path (`[]` = array, `*` = ID key) | Count | Request #s | Types | Distinct values |',
      )
      ..writeln(
        '|-------|----------------------------------------|-------|------------|-------|-----------------|',
      );
    final keys = c.fields.keys.toList()..sort();
    for (final k in keys) {
      final st = c.fields[k]!;
      final i = k.indexOf('|');
      final reqs = st.requests.toList()..sort();
      b.writeln(
        '| ${k.substring(0, i)} | `${_mdCell(k.substring(i + 1))}` | ${st.count} | '
        '${reqs.join(', ')} | ${st.types.join(', ')} | ${st.values.join(', ')} |',
      );
    }
  }
  b
    ..writeln()
    ..writeln('## HTML documents on instagram.com')
    ..writeln()
    ..writeln(
      'Pages can embed their data in the HTML instead of a JSON request. '
      'Only marker names are listed; no HTML is copied.',
    )
    ..writeln();
  if (htmlHits.isEmpty) {
    b.writeln('None in this HAR.');
  } else {
    b
      ..writeln('| Path | Status | Markers found |')
      ..writeln('|------|--------|---------------|');
    for (final h in htmlHits) {
      final hs = h.path.isEmpty ? <String>[] : h.path.substring(1).split('/');
      b.writeln(
        '| `/${_mdCell(_scrubSegments(c, hs, igPage: true))}` | ${h.status} | '
        '${h.markers.isEmpty ? '-' : h.markers.join(', ')} |',
      );
    }
  }
  b
    ..writeln()
    ..writeln('## ID field types (original JSON types)')
    ..writeln();
  if (c.idTypes.isEmpty) {
    b.writeln('None.');
  } else {
    b
      ..writeln('| Key | Original type(s) |')
      ..writeln('|-----|------------------|');
    final keys = c.idTypes.keys.toList()..sort();
    for (final k in keys) {
      b.writeln('| `${_mdCell(k)}` | ${c.idTypes[k]!.join(', ')} |');
    }
    b.writeln(
      '\nIn the sanitized bodies, string IDs became `user_N` / `media_N`; '
      'integer IDs became integers (user 7000000000+N, media 8000000000+N).',
    );
  }
  b
    ..writeln()
    ..writeln('## Replacement counts')
    ..writeln();
  final ck = c.counts.keys.toList()..sort();
  for (final k in ck) {
    b.writeln('- $k: ${c.counts[k]}');
  }
  files['report.md'] = b.toString();

  // Final scan of every output file (fail closed).
  final leaks = <String>[];
  files.forEach((name, text) {
    for (final kind in findLeaks(text)) {
      leaks.add('$name: $kind');
    }
  });
  if (leaks.isNotEmpty) return SanitizeOutcome(files: {}, leaks: leaks);
  return SanitizeOutcome(files: files, leaks: const []);
}

const String _usage = '''
Usage: dart sanitize_har.dart <in.har> <out_dir>

Sanitizes a Chrome HAR export for sharing. Writes summary.json, report.md and
bodies/*.json into <out_dir>. Exits 1 and writes nothing if any secret-looking
text survives. Never share the raw HAR.''';

/// Runs the CLI. Returns the exit code.
Future<int> run(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) async {
  if (args.length != 2 || args.contains('--help') || args.contains('-h')) {
    (args.contains('--help') || args.contains('-h') ? out : err).writeln(
      _usage,
    );
    return args.contains('--help') || args.contains('-h') ? 0 : 2;
  }
  final input = File(args[0]);
  if (!input.existsSync()) {
    err.writeln('Input file not found: ${args[0]}');
    return 2;
  }
  final SanitizeOutcome outcome;
  try {
    outcome = sanitizeHar(input.readAsStringSync());
  } on FormatException catch (e) {
    err.writeln('Could not read the HAR: ${e.message}');
    return 2;
  }
  if (!outcome.ok) {
    err.writeln(
      'REFUSING TO WRITE: possible secrets would remain in the output. '
      'Nothing was written. Do not share the raw HAR. Findings:',
    );
    outcome.leaks.forEach((l) => err.writeln('  - $l'));
    return 1;
  }
  final dir = Directory(args[1])..createSync(recursive: true);
  outcome.files.forEach((rel, text) {
    final f = File('${dir.path}${Platform.pathSeparator}$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  });
  out
    ..writeln('Wrote ${outcome.files.length} files to ${dir.path}')
    ..writeln('Skim report.md and bodies/ before sharing, then send the')
    ..writeln('whole folder (never the raw HAR).');
  return 0;
}

Future<void> main(List<String> args) async {
  exitCode = await run(args, out: stdout, err: stderr);
}
