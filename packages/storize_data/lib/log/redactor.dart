/// Removes secrets from text before it is written anywhere (TECH_SPEC §8).
///
/// Everything the diagnostic log or the crash marker stores goes through
/// [Redactor.redact] first, including error messages and stack traces.
///
/// What is removed:
/// - Cookies: the values of `sessionid`, `csrftoken`, `ds_user_id`, `rur`,
///   `mid` (and a few sibling cookies), and the whole value of any `Cookie:`
///   or `Set-Cookie:` header.
/// - Tokens: `Authorization` / `Bearer` values, `x-ig-*` and `x-csrftoken`
///   header values, `fb_dtsg`, `lsd`, `csrf*`, `access_token` and similar.
/// - Signed URL parts: the whole query of CDN URLs (Instagram and Facebook
///   CDNs), plus `oh`, `oe`, `efg`, `sig` and `_nc_*` parameters anywhere.
/// - The PIN and its hashes: `v1:...` strings and values of `pin`, `pin_hash`
///   and similar keys.
///
/// Limits (by design, it is a pattern filter and not a taint tracker): a bare
/// secret with no key, header or known shape around it cannot be recognised,
/// so callers must not log raw secrets. A PIN typed without a `pin` key is
/// not detectable.
abstract final class Redactor {
  /// The replacement written in place of a secret.
  static const String mask = '[REDACTED]';

  /// Longest text kept after redaction. Longer text is cut so one line cannot
  /// fill the 1 MB log file.
  static const int maxLength = 4000;

  /// Key names whose value is secret, matched after `:`, `=` or `%3D`.
  static const String _secretKeys =
      'set-cookie|cookie|proxy-authorization|authorization|sessionid|'
      'csrftoken|csrfmiddlewaretoken|csrf_?token|csrf|ds_user_id|rur|mid|'
      'ig_did|datr|shbid|shbts|ig_nrcb|fb_dtsg|dtsg|jazoest|lsd|'
      'access_?token|refresh_?token|id_?token|api_?key|secret|token|'
      '(?:x-)?ig-[a-z0-9-]+|x-csrftoken|x-fb-[a-z0-9-]+|'
      '(?:new_?|old_?|current_?|confirm_?)?pin(?:_?hash|_?salt)?|'
      'passcode|passwd|password|enc_password';

  /// URL query parameters that are signatures. Matched only before `=`.
  static const String _signedParams = 'oh|oe|efg|sig|signature|_nc_[a-z0-9_]*';

  // After a key: optional closing (possibly escaped) quote, separator, and an
  // optional opening (possibly escaped) quote.
  static const String _sep =
      r'''(?:\\?["'])?\s*(?:[:=]|%3[Dd]|%3[Aa])\s*(?:\\?["'])?''';

  // Whole `Name: value` header lines: everything to the end of the line.
  static final RegExp _headerLine = RegExp(
    '(?<![A-Za-z0-9_-])((?:set-cookie|cookie|proxy-authorization|authorization|'
    r'x-ig-[a-z0-9-]+|x-csrftoken|x-fb-[a-z0-9-]+))[ \t]*:[ \t]*[^\r\n]*',
    caseSensitive: false,
  );

  // `key: "value with spaces"` (JSON or Dart, either quote). Runs first so
  // quoted secrets containing spaces or `;` are removed whole.
  static final RegExp _quoted = RegExp(
    '(?<![A-Za-z0-9])((?:$_secretKeys)["\']?\\s*[:=]\\s*)'
    r'''(["'])(?:(?!\2)[^\\]|\\.)*\2''',
    caseSensitive: false,
  );

  // `key=value`, `key: value`, `"key":"value"` (escaped too), `key%3Dvalue`.
  static final RegExp _keyValue = RegExp(
    '(?<![A-Za-z0-9])((?:$_secretKeys)$_sep)'
    r'''[^\s"'\;,&{}()\[\]]+''',
    caseSensitive: false,
  );

  static final RegExp _signedParam = RegExp(
    '(?<![A-Za-z0-9])((?:$_signedParams)(?:=|%3[Dd]))'
    r'''[^\s"'\;,&{}()\[\]]*''',
    caseSensitive: false,
  );

  static final RegExp _bearer = RegExp(
    r'\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );

  // PIN hashes and the cooldown counter share the `v1:` prefix.
  static final RegExp _pinHash = RegExp(r'''(?<![A-Za-z0-9])v1:[^\s"'\\]+''');

  // Any URL, including JSON-escaped ones (`https:\/\/host\/path`).
  static final RegExp _url = RegExp(
    r'''https?:(?:\\?/){2}[^\s"'<>]+''',
    caseSensitive: false,
  );

  static final RegExp _cdnHost = RegExp(
    r'''^https?:(?:\\?/){2}[^/\\?#\s]*(?:cdninstagram\.com|fbcdn\.net|fbsbx\.com)(?::\d+)?(?=[/\\?#]|$)''',
    caseSensitive: false,
  );

  /// Returns [input] with every known secret pattern replaced by [mask] and
  /// cut to [maxLength]. Safe to call on any text; applying it twice gives the
  /// same result.
  static String redact(String input) {
    var s = input;
    s = s.replaceAllMapped(_url, _stripCdnQuery);
    s = s.replaceAllMapped(_headerLine, (m) => '${m[1]}: $mask');
    s = s.replaceAllMapped(_quoted, (m) => '${m[1]}${m[2]}$mask${m[2]}');
    s = s.replaceAllMapped(_keyValue, (m) => '${m[1]}$mask');
    s = s.replaceAllMapped(_signedParam, (m) => '${m[1]}$mask');
    s = s.replaceAllMapped(_bearer, (m) => '${m[1]} $mask');
    s = s.replaceAllMapped(_pinHash, (_) => 'v1:$mask');
    if (s.length > maxLength) {
      s = '${s.substring(0, maxLength)}...[cut ${s.length - maxLength}]';
    }
    return s;
  }

  /// Redacts the first line of [input] only, cut to [maxChars]. Used for the
  /// crash marker.
  static String redactFirstLine(String input, {int maxChars = 200}) {
    final line = redact(input).split(RegExp(r'[\r\n]')).first;
    return line.length <= maxChars ? line : line.substring(0, maxChars);
  }

  /// Describes a captured response body by its size only (TECH_SPEC §8: in
  /// release only the size of captured JSON is logged, never its content).
  static String bodySummary(String? body) =>
      '[body ${body?.length ?? 0} chars]';

  static String _stripCdnQuery(Match m) {
    final url = m[0]!;
    final host = _cdnHost.firstMatch(url);
    if (host == null) return url;
    final rest = url.substring(host.end);
    final cut = rest.indexOf(RegExp('[?#]'));
    if (cut < 0) return url;
    return '${url.substring(0, host.end)}${rest.substring(0, cut)}?$mask';
  }
}
