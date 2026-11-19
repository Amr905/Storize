import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Builds the request headers for a stored session (AC6): the cookies, the
/// WebView User-Agent, the CSRF token and the Referer.
///
/// The exact header set is not captured yet (INSTAGRAM_EXTRACTION.md, Pending),
/// so `appId` is configuration and is sent only when given, never hard-coded.
final class IgSession {
  /// Creates the headers source for [blob].
  IgSession(this.blob, {this.appId});

  /// Loads the session of [accountId] from [store], or null when there is no
  /// usable one (missing, or without the required cookies).
  static Future<IgSession?> load(
    SessionStore store,
    int accountId, {
    String? appId,
  }) async {
    final blob = await store.load(accountId);
    if (blob == null || SessionStore.missingCookies(blob).isNotEmpty) {
      return null;
    }
    return IgSession(blob, appId: appId);
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
    };
  }

  @override
  String toString() => 'IgSession(cookies: ${blob.cookies.keys.toList()})';
}
