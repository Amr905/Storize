import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_model/storize_model.dart';

/// The default longest `Retry-After` the failure map passes on: the
/// governor's default `maxPause` (24 h).
const Duration defaultMaxRetryAfter = Duration(hours: 24);

/// Turns an integer `Retry-After` (seconds) into a [Duration] without
/// overflow (T-013 N4).
///
/// `Duration(seconds: n)` wraps for huge `n` (about 2^64 microseconds gave
/// 59 s), so [seconds] is clamped **before** the conversion. Negative gives
/// null (no usable hint); more than [max] gives [max].
///
/// An `IgHttp` that reads the header must call this for the integer form.
Duration? clampedRetryAfter(
  int seconds, {
  Duration max = defaultMaxRetryAfter,
}) {
  if (seconds < 0) return null;
  if (seconds >= max.inSeconds) return max;
  return Duration(seconds: seconds);
}

/// The `for (;;);` error code that means "not logged in". Any other code of
/// such a body (a stale or missing `fb_dtsg`, for example 1357004) means the
/// page tokens are no good. Deliberately narrow: a wrong `SessionInvalid`
/// would make the user log in again for nothing.
const int fbLoginErrorCode = 1357001;

/// Turns a reply into the `Failure` of the TECH_SPEC 4.1 failure map, or null
/// when the reply is a usable JSON object.
///
/// Rules, in this order (the first that matches wins):
/// 0. (T-049) A `for (;;);` error body: code 1357001 is
///    `SessionInvalid(loginRequired)`, any other code is
///    `SchemaChanged('page_tokens')`. A GraphQL `errors[]` message with
///    `missing_required_variable` and no `data` is
///    `SchemaChanged('providers')`.
/// 1. `checkpoint_required`, `challenge_required`, a `challenge` object or a
///    redirect to `/challenge/...`: `SessionInvalid(challenge)`.
/// 2. 401, a redirect to the login page, `login_required`,
///    `user_has_logged_out` or `require_login`:
///    `SessionInvalid(loginRequired)`.
/// 3. `feedback_required`, a disabled account or a redirect to
///    `/accounts/suspended` or `/accounts/disabled`: `AccountRestricted`.
/// 4. 429 or "please wait" or "too many requests": `RateLimited`.
/// 5. 403 "not authorized to view": `TargetNotVisible`.
/// 6. 404: `TargetNotFound`.
/// 7. Any other non-2xx: `UnknownFailure(code, 'http_<code>')`.
/// 8. A 2xx body that is not a JSON object: `SchemaChanged('response')`.
///
/// Markers are read from the top-level `message`, `error_type` and `error`.
/// On a 2xx reply they count only when `status` is `fail`, `require_login` is
/// true, or `data` is null next to an `errors[]` list. The `errors[]` messages
/// are read only when `data` is null, so a non-fatal `errors[]` next to
/// complete data is never a failure (AC8).
///
/// A `RateLimited` hint is cut to [maxRetryAfter] (and a negative one is
/// dropped), whatever the reply says; pass the governor's `maxPause`.
final class FailureClassifier {
  /// Creates the classifier.
  const FailureClassifier({this.maxRetryAfter = defaultMaxRetryAfter});

  /// The longest `retryAfter` of a `RateLimited` result.
  final Duration maxRetryAfter;

  /// Classifies [reply].
  Failure? classify(IgReply reply) {
    final body = reply.json is Map<String, Object?>
        ? reply.json! as Map<String, Object?>
        : null;
    final fbError = reply.fbError;
    if (fbError != null) {
      return fbError == fbLoginErrorCode
          ? const SessionInvalid(SessionReason.loginRequired)
          : const SchemaChanged('page_tokens');
    }
    if (reply.isSuccess && body != null && _missingProviders(body)) {
      return const SchemaChanged('providers');
    }
    if (reply.isSuccess) {
      if (body == null) return const SchemaChanged('response');
      if (!_isFailBody(body)) return null;
    }
    final redirect = reply.redirectPath ?? '';
    final text = _markers(body, includeErrors: body?['data'] == null);
    if (text.contains('checkpoint_required') ||
        text.contains('challenge_required') ||
        redirect.startsWith('/challenge') ||
        body?['challenge'] is Map<String, Object?>) {
      return const SessionInvalid(SessionReason.challenge);
    }
    final redirectToLogin = redirect.contains('/accounts/login');
    if (reply.status == 401 ||
        redirectToLogin ||
        text.contains('login_required') ||
        text.contains('user_has_logged_out') ||
        body?['require_login'] == true) {
      return const SessionInvalid(SessionReason.loginRequired);
    }
    if (redirect.startsWith('/accounts/suspended') ||
        redirect.startsWith('/accounts/disabled') ||
        text.contains('feedback_required') ||
        text.contains('account_disabled') ||
        text.contains('account has been disabled') ||
        text.contains('disabled your account')) {
      return const AccountRestricted();
    }
    if (reply.status == 429 ||
        text.contains('please wait') ||
        text.contains('too many requests')) {
      return RateLimited(_cappedHint(reply.retryAfter));
    }
    if (text.contains('not authorized to view')) {
      return const TargetNotVisible();
    }
    if (reply.status == 404) return const TargetNotFound();
    if (!reply.isSuccess) {
      return UnknownFailure(reply.status, 'http_${reply.status}${_hint(body)}');
    }
    return const UnknownFailure(null, 'status_fail');
  }

  /// A short, secret-free reason from an error body for diagnostics: the
  /// `error_type`, or the `message` reduced to lowercase letters and
  /// underscores (no digits, ids or URLs survive), at most 40 characters.
  static String _hint(Map<String, Object?>? body) {
    final reason = reasonOf(body);
    return reason.isEmpty ? '' : ':$reason';
  }

  /// The secret-free reason of an error [json] body (see [_hint]) without a
  /// leading colon; empty when there is none or [json] is not an object.
  static String reasonOf(Object? json) {
    final body = json is Map<String, Object?> ? json : null;
    final raw = body?['error_type'] ?? body?['message'];
    if (raw is! String) return '';
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp('[^a-z ]'), '')
        .trim()
        .replaceAll(RegExp(' +'), '_');
    if (cleaned.isEmpty) return '';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  Duration? _cappedHint(Duration? hint) {
    if (hint == null || hint.isNegative) return null;
    return hint > maxRetryAfter ? maxRetryAfter : hint;
  }

  /// A GraphQL answer without `data` whose `errors[]` says a required
  /// variable (a relay provider) was not sent.
  bool _missingProviders(Map<String, Object?> body) {
    if (body['data'] != null) return false;
    final errors = body['errors'];
    if (errors is! List<Object?>) return false;
    for (final e in errors) {
      if (e is Map<String, Object?> &&
          e['message'] is String &&
          (e['message']! as String).contains('missing_required_variable')) {
        return true;
      }
    }
    return false;
  }

  /// Whether a 2xx body is really a failure.
  bool _isFailBody(Map<String, Object?> body) {
    if (body['status'] == 'fail' || body['require_login'] == true) return true;
    return body.containsKey('data') &&
        body['data'] == null &&
        body['errors'] is List<Object?> &&
        (body['errors']! as List<Object?>).isNotEmpty;
  }

  String _markers(Map<String, Object?>? body, {required bool includeErrors}) {
    if (body == null) return '';
    final parts = <String>[];
    for (final key in const ['message', 'error_type', 'error']) {
      final v = body[key];
      if (v is String) parts.add(v);
    }
    final errors = body['errors'];
    if (includeErrors && errors is List<Object?>) {
      for (final e in errors) {
        if (e is Map<String, Object?> && e['message'] is String) {
          parts.add(e['message']! as String);
        }
      }
    }
    return parts.join(' ').toLowerCase();
  }
}
