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

// ---------------------------------------------------------------------------
// Policy tables. The body sanitizer is DEFAULT-DENY: every string value is
// replaced unless its key is on an explicit allowlist of structural keys.
// ---------------------------------------------------------------------------

/// String values kept (if they also match a short pattern) for these keys.
const Set<String> _allowedStringKeys = {
  'media_type',
  'product_type',
  'audience',
  'status',
  '__typename',
  'mime_type',
  'content_type',
  'type',
  'kind',
  'reel_type',
};

/// Enum-like values (QA-12): identifier shape, 32 chars at most. `__typename`
/// values such as `XDTGraphImage` pass.
final RegExp _structValue = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,31}$');
final RegExp _mimeValue = RegExp(r'^[A-Za-z0-9_\-]+/[A-Za-z0-9_.+\-]+$');

/// Object keys that are kept verbatim (QA-10, default-deny for keys).
///
/// Rationale: only names that are fixed by the Instagram/GraphQL schema may
/// appear. Sources: TECH_SPEC 4.1 key fields (IG-1..IG-5), [_mediaFieldKeys],
/// keys of `synthetic.har`, the GraphQL envelope (`data`, `edges`, `node`,
/// `page_info`, `__typename`, `extensions`, `errors`), the friendship and
/// counter flags, and the ID fields. Dynamic keys (usernames, IDs, display
/// names) are never in this list.
const Set<String> _allowedKeys = {
  // TECH_SPEC 4.1 IG-1..IG-5
  'id', 'username', 'full_name', 'is_private', 'followed_by_viewer',
  'blocked_by_viewer', 'profile_pic_url', 'user', 'users', 'pk', 'reels',
  'items', 'taken_at', 'expiring_at', 'media_type', 'image_versions2',
  'candidates', 'video_versions', 'video_duration', 'audience',
  'story_link_stickers', 'code', 'product_type', 'carousel_media', 'caption',
  'text', 'width', 'height', 'url', 'count', 'more_available', 'next_max_id',
  'num_results', 'status', 'message', 'require_login', 'spam',
  // synthetic.har
  'biography', 'dimensions', 'edge_media_to_caption',
  'edge_owner_to_timeline_media', 'edges', 'external_url', 'has_audio',
  'node', 'original_height', 'original_width', 'shortcode', 'type',
  'video_dash_manifest', 'video_url', 'display_url', 'is_video',
  'taken_at_timestamp', 'phone_number', 'profile_pic_id',
  // GraphQL / web envelope
  'data', '__typename', 'extensions', 'errors', 'page_info', 'has_next_page',
  'end_cursor', 'edge_followed_by', 'edge_follow', 'edge_sidecar_to_children',
  'display_resources', 'config_width', 'config_height', 'src', 'viewer',
  'owner', 'reel', 'reels_media', 'tray', 'latest_reel_media', 'seen',
  'ranked_position', 'can_reply', 'can_reshare', 'story_cta', 'strong_id__',
  'pk_id', 'media_id', 'user_id', 'owner_id', 'fbid', 'is_verified',
  'is_bestie', 'friendship_status', 'friendship_statuses', 'following',
  'followed_by', 'blocking', 'outgoing_request', 'incoming_request',
  'like_count', 'comment_count', 'view_count', 'play_count', 'usertags',
  'in', 'video_codec', 'is_dash_eligible', 'number_of_qualities', 'mime_type',
  'content_type', 'kind', 'reel_type', 'accessibility_caption',
  'clips_metadata', 'original_sound_info', 'is_paid_partnership',
  'media_overlay_info', 'timestamp', 'app_id', 'doc_id', 'query_hash',
  'variables', 'ig_app_id', 'edit', 'shortcode_media',
};

/// GraphQL root fields under `data` (for example
/// `xdt_api__v1__feed__user_timeline_graphql_connection`). They are schema
/// names the extractor has to know, and they only count directly under `data`.
final RegExp _graphqlRootField = RegExp(r'^(xdt|xig)_[a-z0-9_]{1,100}$');

/// Parents whose own keys are dynamic (usernames or IDs). Every key under
/// them that is not an ID becomes `key_N`, whatever it looks like.
const Set<String> _idMapParents = {
  'users',
  'friendship_statuses',
  'reels',
  'user_map',
  'profiles',
  'friendships',
  'statuses',
};

/// Safe-word shape: lower-case snake_case, at most 40 chars. Allowed for an
/// unknown key only when a sibling key is on the allowlist.
final RegExp _safeWordKey = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

bool _isKnownKey(String k) =>
    _allowedKeys.contains(k) ||
    _mediaFieldKeys.contains(k) ||
    _secretKeys.contains(k.toLowerCase());

/// Request header values we keep (everything else: name only).
const Set<String> _keptHeaderValues = {
  'x-ig-app-id',
  'user-agent',
  'content-type',
  'accept',
};

/// JSON keys whose value is a secret or device/session identifier. The value
/// (any type) is replaced even if it is an object.
const Set<String> _secretKeys = {
  'sessionid',
  'csrftoken',
  'x-csrftoken',
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
  'ig-set-authorization',
  'x-ig-www-claim',
  'x-instagram-ajax',
  'x-asbd-id',
  'x-fb-lsd',
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

const Set<String> _geoKeys = {'lat', 'lng', 'latitude', 'longitude'};

/// Numeric keys that stay as they are even when they have 13+ digits.
final RegExp _timeKey = RegExp(
  r'(time|_at$|^at$|_ms$|_us$|date|latest_reel_media|duration|expir)',
);

/// ID-like keys that are public constants, not per-user identifiers.
const Set<String> _notIdKeys = {'app_id', 'ig_app_id', 'doc_id'};

/// Path segments that are known API structure. Everything else is `<seg>`.
const Set<String> _allowedSegments = {
  'api',
  'v1',
  'v2',
  'feed',
  'reels_media',
  'reels',
  'reel',
  'reels_tray',
  'user',
  'users',
  'web_profile_info',
  'info',
  'accounts',
  'current_user',
  'graphql',
  'query',
  'stories',
  'story',
  'highlights',
  'p',
  'tv',
  'friendships',
  'show',
  'usernameinfo',
  'username',
  'media',
  'tray',
  'explore',
  'web',
  'search',
  'topsearch',
  'clips',
  'timeline',
  'seen',
  'comments',
  'tags',
  'locations',
  'location',
  'ajax',
  'async',
  'data',
  'logging',
  'qp',
  'direct_v2',
  'inbox',
  'bulk-route-definitions',
};

/// Query/param names whose value shape is structural.
const Set<String> _idQueryKeys = {
  'reel_ids',
  'user_id',
  'user_ids',
  'id',
  'ids',
};

/// POST/form parameter names we are willing to list.
const Set<String> _allowedParamNames = {
  'doc_id',
  'query_hash',
  'variables',
  'count',
  'first',
  '__a',
  '__d',
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
// Leak scanner (independent last line of defence). Scans the raw text, a
// URL-decoded copy and a JSON-unescaped copy (and both), case-insensitively.
// ---------------------------------------------------------------------------

/// A cookie/session/auth name followed by a separator and a real value.
/// Header-name lists ("x-csrftoken",) and placeholders (`<v>`, `<redacted>`)
/// do not match.
final RegExp _secretAssign = RegExp(
  '(?<![a-z0-9_])'
  '(sessionid|csrftoken|x-csrftoken|csrf_token|ds_user_id|ig_did|rur|'
  'fbsr_[a-z0-9_]*|authorization|ig-set-authorization|mid)'
  r'''["']?\s*(?:=|:)\s*["']?(?!<)[^\s"'&;,<>]''',
  caseSensitive: false,
);
final RegExp _bearer = RegExp(
  r'\bbearer\s+[A-Za-z0-9._~+/=-]{8,}',
  caseSensitive: false,
);
final RegExp _setCookieText = RegExp(
  r'set-cookie\s*[:=]',
  caseSensitive: false,
);
final RegExp _urlWithQuery = RegExp(
  r'(?:https?:)?//[^\s"<>]*\?',
  caseSensitive: false,
);
final RegExp _signedParam = RegExp(
  '[?&;](?:oh|oe|_nc_[a-z0-9]+|sig|signature|ccb|efg)=',
  caseSensitive: false,
);
final RegExp _email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}');
final RegExp _phoneIntl = RegExp(r'\+\d[\d\s().-]{8,}\d');
final RegExp _phoneGroups = RegExp(
  r'\(?\d{2,4}\)?[\s.-]\d{3,4}[\s.-]\d{3,4}',
);
final RegExp _quotedLongDigits = RegExp(r'"\d{10,}"');
final RegExp _allowedConstants = RegExp(
  r'"(?:doc_id|docId|query_hash|x-ig-app-id)"\s*:\s*"[A-Za-z0-9]{1,40}"',
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

String _urlDecode(String s) => s.replaceAllMapped(
  RegExp('%([0-9a-fA-F]{2})'),
  (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
);

String _jsonUnescape(String s) => s
    .replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
    )
    .replaceAll(r'\"', '"')
    .replaceAll(r'\/', '/')
    .replaceAll(r'\\', r'\');

/// Finds anything in [text] that still looks like a secret or personal data.
/// Returns kinds only (never the matched text), so the report cannot leak.
List<String> findLeaks(String text) {
  final kinds = <String>{};
  final base = text.replaceAll(_allowedConstants, '"<const>"');
  final unescaped = _jsonUnescape(base);
  final variants = <String>{
    base,
    _urlDecode(base),
    unescaped,
    _urlDecode(unescaped),
    _urlDecode(_urlDecode(unescaped)),
  };
  for (final v in variants) {
    if (_secretAssign.hasMatch(v)) kinds.add('cookie/session/auth value');
    if (_bearer.hasMatch(v)) kinds.add('bearer token');
    if (_setCookieText.hasMatch(v)) kinds.add('Set-Cookie');
    if (_urlWithQuery.hasMatch(v)) kinds.add('URL with a query string');
    if (_signedParam.hasMatch(v)) kinds.add('signed URL parameter');
    if (_email.hasMatch(v)) kinds.add('email address');
    if (_phoneIntl.hasMatch(v) ||
        _phoneGroups.hasMatch(v) ||
        _quotedLongDigits.hasMatch(v)) {
      kinds.add('phone-like number');
    }
    if (_tokenRun.allMatches(v).any((m) => looksLikeSecretToken(m[0]!))) {
      kinds.add('long hex/base64 token');
    }
  }
  return kinds.toList();
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
  final Map<String, String> _keys = {};
  final Map<String, int> counts = {};
  final Set<String> knownUsers = {};
  final Set<String> knownMedia = {};
  final Map<String, Set<String>> idTypes = {};
  final Map<String, _FieldStat> fields = {};
  final Map<int, Set<String>> fieldsByRequest = {};
  int currentRequest = 0;

  /// Object keys replaced by `key_N` (occurrences).
  int keysReplaced = 0;

  /// Distinct original keys replaced by `key_N`.
  int get distinctKeysReplaced => _keys.length;

  int bump(String kind) => counts[kind] = (counts[kind] ?? 0) + 1;

  /// Consistent `key_N` placeholder for an unsafe object key.
  String keyName(String raw) =>
      _keys.putIfAbsent(raw, () => 'key_${_keys.length + 1}');

  /// Placeholder name (`user_1` / `media_1`) for numeric ID [digits].
  String idName(String digits, String hint) => _ids.putIfAbsent(digits, () {
    final kind = knownUsers.contains(digits)
        ? 'user'
        : knownMedia.contains(digits)
        ? 'media'
        : hint;
    return '${kind}_${bump(kind)}';
  });
}

final RegExp _digitsId = RegExp(r'^\d{5,}$');
final RegExp _compoundId = RegExp(r'^(\d{5,})_(\d{5,})$');
final RegExp _idKey = RegExp(r'(^|_)(pk|id|ids|user_id|media_id|owner)$');

bool _isIdKey(String lk) {
  if (_notIdKeys.contains(lk)) return false;
  return _idKey.hasMatch(lk) ||
      lk == 'fbid' ||
      lk == 'ds_user_id' ||
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

/// Replaces an ID value, keeping its JSON type (int stays int). Returns null
/// if [v] is not an ID-shaped value.
Object? _mapId(_Ctx c, String key, Object? v, String hint) {
  if (v is int && v.abs().toString().length >= 5) {
    c.idTypes.putIfAbsent(key, () => {}).add('int');
    final name = c.idName(v.abs().toString(), hint);
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
  return null;
}

// ---------------------------------------------------------------------------
// Default-deny value rules
// ---------------------------------------------------------------------------

bool _isIgHost(String host) =>
    host == 'instagram.com' || host.endsWith('.instagram.com');

bool _isUrlKey(String lk) =>
    lk == 'url' ||
    lk == 'uri' ||
    lk == 'src' ||
    lk.endsWith('_url') ||
    lk.endsWith('_uri') ||
    lk.startsWith('url_');

final RegExp _wholeUrl = RegExp(
  r'^(?:https?:)?//([^/?#\s]+)([^?#\s]*)(?:[?#]\S*)?$',
);

/// `<url host=H path_shape=3seg.jpg>` for a whole-string URL, else null.
String? _urlPlaceholder(String s) {
  final m = _wholeUrl.firstMatch(s.trim());
  if (m == null) return null;
  var host = m[1]!.toLowerCase();
  final at = host.lastIndexOf('@');
  if (at >= 0) host = host.substring(at + 1);
  host = host.split(':').first;
  if (!RegExp(r'^[a-z0-9.-]{1,80}$').hasMatch(host)) host = 'unknown';
  // Only hosts that matter for the spike are named; anything else (bio
  // links, external sites) is just "external".
  const known = [
    'instagram.com',
    'cdninstagram.com',
    'fbcdn.net',
    'facebook.com',
    'fbsbx.com',
  ];
  if (!known.any((k) => host == k || host.endsWith('.$k'))) host = 'external';
  final segs = m[2]!.split('/').where((p) => p.isNotEmpty).toList();
  final ext = segs.isEmpty
      ? ''
      : (RegExp(r'\.[A-Za-z0-9]{1,5}$').firstMatch(segs.last)?[0] ?? '');
  return '<url host=$host path_shape=${segs.length}seg$ext>';
}

/// Default-deny for one string value under key [lk].
String _denyString(_Ctx c, String lk, String s) {
  if (lk.contains('dash_manifest')) {
    c.bump('dash');
    return '<dash:${s.length}>';
  }
  final u = _urlPlaceholder(s);
  if (u != null && (_isUrlKey(lk) || !s.contains(RegExp(r'\s')))) {
    c.bump('url');
    return u;
  }
  if (_allowedStringKeys.contains(lk)) {
    final ok = (lk == 'mime_type' || lk == 'content_type')
        ? _mimeValue.hasMatch(s)
        : _structValue.hasMatch(s);
    if (ok) return s;
  }
  c.bump('str');
  return '<str:${s.length}>';
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
    for (final v in node.values) {
      _collectKnown(c, v);
    }
  } else if (node is List<Object?>) {
    for (final v in node) {
      _collectKnown(c, v);
    }
  }
}

String _mapKey(
  _Ctx c,
  String k,
  String parentKey, {
  required bool dynamicMap,
  required bool hasKnownSibling,
}) {
  if (_digitsId.hasMatch(k) || _compoundId.hasMatch(k)) {
    final m = _compoundId.firstMatch(k);
    if (m != null) {
      return '${c.idName(m[1]!, 'media')}_${c.idName(m[2]!, 'user')}';
    }
    return c.idName(k, _hintFor(parentKey, ''));
  }
  // Default-deny (QA-10). URL-, email- and phone-shaped keys, usernames and
  // display names fail both the allowlist and the safe-word shape, so they
  // always end up as key_N.
  final reserved = RegExp(r'^key_\d+$').hasMatch(k);
  final keep =
      !dynamicMap &&
      !reserved &&
      !k.toLowerCase().startsWith('fbsr_') &&
      (_isKnownKey(k) ||
          (parentKey == 'data' && _graphqlRootField.hasMatch(k)) ||
          (hasKnownSibling &&
              k.length <= 40 &&
              _safeWordKey.hasMatch(k) &&
              !looksLikeSecretToken(k)));
  if (keep) return k;
  c.keysReplaced++;
  return c.keyName(k);
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
      stat.values.length < 8) {
    // Only enum-shaped values reach report.md (QA-12); anything else would
    // be copied from the raw HAR.
    if (v is int || v is bool) {
      stat.values.add('$v');
    } else if (v is String) {
      stat.values.add(_structValue.hasMatch(v) ? v : '<v>');
    }
  }
  c.fieldsByRequest.putIfAbsent(c.currentRequest, () => {}).add(label);
}

/// Sanitizes one scalar under key `lk` (already lower-cased).
Object? _scalar(_Ctx c, String lk, Object? v, String parentKey) {
  if (v == null || v is bool) return v;
  if (v is num) {
    if (lk.contains('phone') || _geoKeys.contains(lk)) {
      c.bump('num');
      return 0;
    }
    if (_timeKey.hasMatch(lk)) return v;
    if (v is int && (_isIdKey(lk) || v.abs().toString().length >= 13)) {
      return _mapId(c, lk, v, _hintFor(lk, parentKey)) ?? v;
    }
    return v;
  }
  if (v is String) {
    if (_isIdKey(lk)) {
      final m = _mapId(c, lk, v, _hintFor(lk, parentKey));
      if (m != null) return m;
    }
    return _denyString(c, lk, v);
  }
  return v;
}

Object? _walk(
  _Ctx c,
  Object? node, {
  required String key,
  required String parentKey,
  required String path,
  bool inList = false,
}) {
  if (node is Map<String, Object?>) {
    final out = <String, Object?>{};
    final dynamicMap = !inList && _idMapParents.contains(key.toLowerCase());
    final hasKnownSibling = node.keys.any(_isKnownKey);
    node.forEach((k, v) {
      final rawLk = k.toLowerCase();
      final newKey = _mapKey(
        c,
        k,
        key,
        dynamicMap: dynamicMap,
        hasKnownSibling: hasKnownSibling,
      );
      final replaced = newKey != k;
      // A replaced key carries no meaning, so its value is judged as unnamed.
      final lk = replaced ? '' : rawLk;
      final childPath = '$path.${replaced ? '*' : newKey}';
      _recordField(c, lk, childPath, v);
      if (v == null) {
        out[newKey] = null;
      } else if (_secretKeys.contains(rawLk) || rawLk.startsWith('fbsr_')) {
        out[newKey] = redacted;
      } else if (v is Map<String, Object?> || v is List<Object?>) {
        out[newKey] = _walk(c, v, key: k, parentKey: key, path: childPath);
      } else {
        out[newKey] = _scalar(c, lk, v, key);
      }
    });
    return out;
  }
  if (node is List<Object?>) {
    final lk = key.toLowerCase();
    return [
      for (final e in node)
        if (e is Map<String, Object?> || e is List<Object?>)
          _walk(
            c,
            e,
            key: key,
            parentKey: parentKey,
            path: '$path[]',
            inList: true,
          )
        else
          _scalar(c, lk, e, parentKey),
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
  final text = _bodyText(content);
  if (text.isEmpty) return null;
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

/// Path with only allowlisted segments kept. Long numeric IDs become the
/// same `user_N` / `media_N` placeholders used in bodies. Everything else
/// is `<seg>`.
String _allowPath(_Ctx c, List<String> segs) {
  final out = <String>[];
  for (var i = 0; i < segs.length; i++) {
    final s = segs[i];
    final prev = i > 0 ? segs[i - 1] : '';
    if (s.isEmpty || _allowedSegments.contains(s)) {
      out.add(s);
    } else if (_digitsId.hasMatch(s)) {
      out.add(c.idName(s, prev == 'media' ? 'media' : 'user'));
    } else {
      out.add('<seg>');
    }
  }
  return out.join('/');
}

/// Query value policy: keys stay, values become `<v>` except numeric
/// count/first, doc_id/query_hash (public constants that identify GraphQL
/// calls), true/false, and numeric IDs (hashed placeholders).
String _queryValue(_Ctx c, String key, String value) {
  final lk = key.toLowerCase();
  if ((lk == 'count' || lk == 'first') &&
      RegExp(r'^\d{1,4}$').hasMatch(value)) {
    return value;
  }
  if (lk == 'doc_id') {
    return RegExp(r'^\d{6,20}$').hasMatch(value) ? value : '<v>';
  }
  if (lk == 'query_hash') {
    return RegExp(r'^[0-9a-f]{16,64}$').hasMatch(value) ? value : '<v>';
  }
  if (value == 'true' || value == 'false') return value;
  if (_idQueryKeys.contains(lk)) {
    return value
        .split(',')
        .map((p) => _digitsId.hasMatch(p) ? c.idName(p, 'user') : '<v>')
        .join(',');
  }
  return '<v>';
}

Map<String, Object?> _describeQuery(
  _Ctx c,
  List<MapEntry<String, String>> kv,
) {
  final out = <String, Object?>{};
  for (final e in kv) {
    final name = _safeName(e.key);
    final shown = _queryValue(c, e.key, e.value);
    final prev = out[name];
    if (prev == null) {
      out[name] = shown;
    } else if (prev is List<Object?>) {
      prev.add(shown);
    } else {
      out[name] = <Object?>[prev, shown];
    }
  }
  return out;
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
      out.add(MapEntry(k, ''));
    }
  }
  return out;
}

/// POST body: never copied. Only mimeType, size and allowlisted names.
Map<String, Object?> _describePost(Map<String, Object?> post) {
  final mt = '${post['mimeType']}'.toLowerCase();
  final text = post['text'];
  final names = <String>[];
  String? docId;
  if (text is String && mt.contains('x-www-form-urlencoded')) {
    for (final e in _parseForm(text)) {
      names.add(e.key);
      if (e.key == 'doc_id' && RegExp(r'^\d{6,20}$').hasMatch(e.value)) {
        docId = e.value;
      }
    }
  } else if (post['params'] is List) {
    for (final p in _asList(post['params'])) {
      final m = _asMap(p);
      if (m == null) continue;
      names.add('${m['name']}');
      if ('${m['name']}' == 'doc_id' &&
          RegExp(r'^\d{6,20}$').hasMatch('${m['value']}')) {
        docId = '${m['value']}';
      }
    }
  } else if (text is String && mt.contains('json')) {
    try {
      final j = jsonDecode(text);
      if (j is Map) names.addAll(j.keys.map((k) => '$k'));
    } on FormatException {
      // ignore
    }
  }
  return {
    'mimeType': RegExp(r'^[A-Za-z0-9_.+\-/;= ]{1,80}$').hasMatch(mt)
        ? mt
        : '<str>',
    'size': text is String ? text.length : 0,
    'paramCount': names.length,
    'paramNames': [
      for (final n in names)
        if (_allowedParamNames.contains(n)) n,
    ],
    'docId': ?docId,
  };
}

String _slug(String sanitizedPath) {
  final segs = sanitizedPath
      .split('/')
      .where((s) => RegExp(r'^[a-z]+(_[a-z]+)*$').hasMatch(s))
      .where((s) => s != 'api' && s != 'v1' && s != 'v2')
      .toList();
  final tail = segs.length > 2 ? segs.sublist(segs.length - 2) : segs;
  final slug = tail.join('_');
  if (slug.isEmpty) return 'request';
  return slug.length > 20 ? slug.substring(0, 20) : slug;
}

String _mdCell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// Query parameter and header names that are known to be structural.
const Set<String> _knownQueryNames = {
  'username',
  'reel_ids',
  'user_id',
  'user_ids',
  'id',
  'ids',
  'count',
  'first',
  'after',
  'max_id',
  'edit',
  'doc_id',
  'query_hash',
  'variables',
  'surface',
  'page_size',
  'include_chaining',
  'include_reel',
  'include_suggested_users',
  'include_logged_out_extras',
  'include_live_status',
  'include_highlight_reels',
  'is_prefetch',
  'is_pull_to_refresh',
  'reason',
  'source',
  'device_id',
  '__a',
  '__d',
  'fb_api_req_friendly_name',
};
final RegExp _shortQueryName = RegExp(r'^_{0,2}[a-z][a-z_]{0,23}$');
final RegExp _shortHeaderName = RegExp(r'^[a-z]+(-[a-z]+){0,4}$');
const Set<String> _knownHeaderNames = {
  'accept',
  'accept-encoding',
  'accept-language',
  'content-type',
  'content-length',
  'cookie',
  'origin',
  'referer',
  'user-agent',
  'x-csrftoken',
  'x-ig-app-id',
  'x-ig-www-claim',
  'x-asbd-id',
  'x-instagram-ajax',
  'x-requested-with',
  'x-fb-lsd',
  'x-fb-friendly-name',
  'x-web-device-id',
  'x-bloks-version-id',
  'sec-fetch-dest',
  'sec-fetch-mode',
  'sec-fetch-site',
  'sec-ch-ua',
  'sec-ch-ua-mobile',
  'sec-ch-ua-platform',
  'sec-ch-prefers-color-scheme',
  'authorization',
  'range',
  'dpr',
  'viewport-width',
  'priority',
  'connection',
  'host',
  ':authority',
  ':method',
  ':path',
  ':scheme',
};

/// Request header name for summary.json (QA-13).
String _headerName(String raw) {
  final n = raw.toLowerCase();
  if (_knownHeaderNames.contains(n) || _shortHeaderName.hasMatch(n)) {
    return n.length <= 40 ? n : '<hdr>';
  }
  return '<hdr>';
}

/// Query parameter name for summary.json (QA-13).
String _safeName(String n) =>
    (_knownQueryNames.contains(n) || _shortQueryName.hasMatch(n))
    ? n
    : '<name>';

/// Reduces a User-Agent to browser/app family, major version and OS family
/// (QA-13). No device model, build ID or minor version survives.
String coarseUserAgent(String ua) {
  const families = <(String, String)>[
    ('Instagram', r'Instagram[ /](\d{1,4})'),
    ('Edge', r'Edg[AiOS]*/(\d{1,4})'),
    ('Opera', r'OPR/(\d{1,4})'),
    ('Firefox', r'Firefox/(\d{1,4})'),
    ('Chrome', r'(?:Chrome|CriOS)/(\d{1,4})'),
    ('Safari', r'Version/(\d{1,4})[^)]*Safari'),
  ];
  String? fam;
  for (final f in families) {
    final m = RegExp(f.$2).firstMatch(ua);
    if (m != null) {
      fam = '${f.$1}/${m[1]}';
      break;
    }
  }
  if (fam == null) return '<ua>';
  final os = ua.contains('Android')
      ? 'Android'
      : RegExp('iPhone|iPad|iOS').hasMatch(ua)
      ? 'iOS'
      : ua.contains('Windows')
      ? 'Windows'
      : ua.contains('Mac OS X')
      ? 'macOS'
      : ua.contains('Linux')
      ? 'Linux'
      : 'other';
  final wv = RegExp(r'; wv\)').hasMatch(ua) ? ', WebView' : '';
  return '$fam ($os$wv)';
}

final RegExp _mimeList = RegExp(r'^[A-Za-z0-9_.+\-/;=*, ]{0,120}$');

String _safeHeaderValue(String name, String v) {
  if (name == 'user-agent') return coarseUserAgent(v);
  if (name == 'x-ig-app-id') {
    return RegExp(r'^\d{6,20}$').hasMatch(v) ? v : '<v>';
  }
  final ok = _mimeList.hasMatch(v) && findLeaks(v).isEmpty;
  return ok ? v : '<str:${v.length}>';
}

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
        (_bodyText(
          content,
        ).trimLeft().startsWith(RegExp(r'[{\[]|for \(;;\);')));
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
  }
  for (final b in parsed) {
    _collectKnown(c, b);
  }

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

    final segs = rawPath.isEmpty ? <String>[] : rawPath.substring(1).split('/');
    final cleanPath = '/${_allowPath(c, segs)}'.replaceAll('//', '/');
    final query = _parseForm(s.uri.hasQuery ? s.uri.query : '');
    final headers = _asList(req['headers']);
    final names = <String>[];
    final kept = <String, String>{};
    for (final h in headers) {
      final m = _asMap(h);
      if (m == null) continue;
      final raw = '${m['name']}';
      final name = _headerName(raw);
      if (!names.contains(name)) names.add(name);
      if (_keptHeaderValues.contains(name)) {
        kept[name] = _safeHeaderValue(name, '${m['value']}');
      }
    }
    final post = _asMap(req['postData']);
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

    final mimeRaw = '${content['mimeType']}';
    final row = <String, Object?>{
      'n': n,
      'method': RegExp(r'^[A-Z]{3,10}$').hasMatch(method) ? method : '<str>',
      'host': s.uri.host,
      'path': cleanPath,
      'query': _describeQuery(c, query),
      if (post != null) 'postData': _describePost(post),
      'requestHeaderNames': names,
      'requestHeaders': kept,
      'status': status,
      'mimeType': RegExp(r'^[A-Za-z0-9_.+\-/;= ]{1,80}$').hasMatch(mimeRaw)
          ? mimeRaw
          : '<str>',
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
        '| `/${_mdCell(_allowPath(c, hs))}` | ${h.status} | '
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
    ..writeln()
    ..writeln(
      '- object keys replaced with key_N: ${c.keysReplaced} '
      '(${c.distinctKeysReplaced} distinct)',
    );
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
