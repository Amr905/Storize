import 'package:meta/meta.dart';
import 'package:storize_model/src/internal/deep_equality.dart';

/// The Instagram session that the vault stores: cookies, the WebView user agent
/// and the capture time.
///
/// Cookie values are secrets. [toString] shows only the cookie names.
@immutable
final class SessionBlob {
  /// Creates a session blob. The cookie map is copied into an unmodifiable map.
  SessionBlob({
    required Map<String, String> cookies,
    required this.userAgent,
    required this.capturedAt,
  }) : cookies = Map<String, String>.unmodifiable(cookies);

  /// Cookie name to cookie value. Values are secret.
  final Map<String, String> cookies;

  /// The WebView user agent. Requests reuse it (ADR-3).
  final String userAgent;

  /// When the session was captured (UTC).
  final DateTime capturedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionBlob &&
          deepEquals(other.cookies, cookies) &&
          other.userAgent == userAgent &&
          other.capturedAt == capturedAt);

  @override
  int get hashCode =>
      Object.hash('SessionBlob', deepHash(cookies), userAgent, capturedAt);

  /// Shows cookie names only, never their values.
  @override
  String toString() =>
      'SessionBlob(cookies: [${cookies.keys.join(', ')}], '
      'userAgent: $userAgent, capturedAt: ${capturedAt.toIso8601String()})';
}
