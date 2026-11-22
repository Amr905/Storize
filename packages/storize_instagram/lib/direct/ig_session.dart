import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Builds the request headers for a stored session (AC6): the cookies, the
/// WebView User-Agent, the CSRF token and the Referer.
///
/// `appId` is configuration: the app's composition passes it (no literal
/// here, see guardrails_test).
final class IgSession {
  /// Creates the headers source for [blob].
  IgSession(this.blob, {this.appId});

  /// Loads the session of [accountId] from [store], or null when there is no
  /// usable one (missing, without the required cookies, or with a character
  /// in a header name or value that HTTP headers cannot carry).
  ///
  /// Allowed are TAB and the printable ASCII range 0x20..0x7E only. CR, LF,
  /// NUL, other control characters and non-ASCII are refused (T-013 N1): the
  /// platform HTTP client would refuse them inside `governor.run`, which
  /// costs a token on every run until the user logs in again.
  static Future<IgSession?> load(
    SessionStore store,
    int accountId, {
    String? appId,
  }) async {
    final blob = await store.load(accountId);
    if (blob == null || SessionStore.missingCookies(blob).isNotEmpty) {
      return null;
    }
    if (!_headerSafe(blob.userAgent) ||
        blob.cookies.entries.any(
          (e) => !_headerSafe(e.key) || !_headerSafe(e.value),
        ) ||
        !_headerSafe(appId ?? '')) {
      // A header value with CR, LF, NUL or non-ASCII is a corrupt session (or
      // header injection). Treated like no session: the user logs in again.
      // The value is never echoed.
      return null;
    }
    return IgSession(blob, appId: appId);
  }

  /// Whether every code unit is TAB or printable ASCII (0x20..0x7E).
  static bool _headerSafe(String value) {
    for (final unit in value.codeUnits) {
      if (unit != 0x09 && (unit < 0x20 || unit > 0x7E)) return false;
    }
    return true;
  }

  /// The stored session.
  final SessionBlob blob;

  /// The value of `X-IG-App-ID`, when known.
  final String? appId;

  /// The logged-in user id (`ds_user_id`).
  String get userId => blob.cookies['ds_user_id'] ?? '';

  /// The headers for an authenticated request. Contains secrets: never log.
  Map<String, String> headers() {
    final csrf = blob.cookies['csrftoken'];
    return {
      'Cookie': blob.cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; '),
      'User-Agent': blob.userAgent,
      'Referer': 'https://www.instagram.com/',
      'X-CSRFToken': ?csrf,
      'X-IG-App-ID': ?appId,
      // Sent by the site's own API calls; some endpoints answer 400 without.
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  @override
  String toString() => 'IgSession(cookies: ${blob.cookies.keys.toList()})';
}
