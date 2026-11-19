import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// Reason codes that [SessionUnreadableCallback] receives.
///
/// The codes describe why a stored session could not be used. They never
/// contain stored data.
abstract final class SessionUnreadableReason {
  /// The secure storage threw (for example a Keystore key that the OEM
  /// invalidated, or a failed decryption).
  static const String platformError = 'platform_error';

  /// The stored value is not valid JSON.
  static const String corruptJson = 'corrupt_json';

  /// The envelope has a version this build does not know.
  static const String unknownVersion = 'unknown_version';

  /// The envelope parsed, but its fields are missing, have the wrong type, or
  /// lack the required cookies.
  static const String invalidShape = 'invalid_shape';
}

/// Called when a stored session exists but cannot be used.
///
/// [reasonCode] is one of [SessionUnreadableReason]. The raw value is never
/// passed. The app wires this to mark the account `LOGGED_OUT` (ADR-0006), see
/// [markLoggedOutOnUnreadable].
typedef SessionUnreadableCallback = FutureOr<void> Function(
  int accountId,
  String reasonCode,
);

/// Returns a [SessionUnreadableCallback] that marks the account
/// `LOGGED_OUT` through [accounts] (ADR-0006: a decryption failure means the
/// user must log in again).
///
/// The status reason is the reason code. Errors from the repo are swallowed:
/// reporting a problem must never break a background run. `accountId` is the
/// `login_account.id`, the same ID the session is stored under.
SessionUnreadableCallback markLoggedOutOnUnreadable(AccountRepo accounts) {
  return (int accountId, String reasonCode) async {
    try {
      await accounts.setStatus(
        accountId,
        AccountStatus.loggedOut,
        reason: reasonCode,
      );
    } on Object {
      // The account row may be gone. Nothing useful to do, and the error text
      // is not worth the risk of leaking context.
    }
  };
}

/// A [SessionStore] that keeps each session in [FlutterSecureStorage].
///
/// **Android encryption (flutter_secure_storage 11.2.0).** The default
/// `AndroidOptions()` is used: an AES-256-GCM data key, wrapped by an
/// RSA-OAEP key in the Android Keystore (`AndroidOptions.defaultOptions`).
/// This is the Keystore-backed mode of TECH_SPEC §9. The old
/// `encryptedSharedPreferences` option was deprecated in 10.x because Jetpack
/// Security is deprecated, and 11.0 removed it (package CHANGELOG, 11.0
/// entry), so it must not be used. `resetOnError` stays `true` (the default):
/// when the Keystore key is lost the plugin wipes the unreadable entries
/// instead of throwing on every call, and [load] then returns null. The
/// account becomes logged out, which is the ADR-0006 outcome.
///
/// **Background isolates.** flutter_secure_storage talks to the native side
/// through a platform channel. The workmanager background isolate registers
/// plugins before the dispatcher runs, so a store built inside that isolate
/// reads the same Keystore-backed data as the UI isolate. Do not share one
/// instance across isolates: create one per isolate with [defaultStorage].
///
/// **Never logs.** No value is ever logged or placed in an exception message.
/// Messages contain cookie names and reason codes only.
final class SecureStorageSessionStore implements SessionStore {
  /// Creates the store over the given secure storage.
  ///
  /// [onUnreadable] is called when a stored session cannot be used. Use
  /// [defaultStorage] for the production [FlutterSecureStorage].
  SecureStorageSessionStore(this._storage, {this.onUnreadable});

  /// The Android options of the production storage. See the class comment.
  static const AndroidOptions androidOptions = AndroidOptions.defaultOptions;

  /// A [FlutterSecureStorage] that uses [androidOptions] (its default).
  static FlutterSecureStorage defaultStorage() => const FlutterSecureStorage();

  /// The cookies that a session must contain (TECH_SPEC §5.1).
  static const List<String> requiredCookies = ['sessionid', 'ds_user_id'];

  /// The current envelope version.
  static const int envelopeVersion = 1;

  /// The storage key for [accountId]: `storize.session.<accountId>`.
  static String keyFor(int accountId) => 'storize.session.$accountId';

  final FlutterSecureStorage _storage;

  /// Called when a stored session cannot be used. See
  /// [SessionUnreadableCallback].
  final SessionUnreadableCallback? onUnreadable;

  @override
  Future<void> save(int accountId, SessionBlob session) async {
    final missing = requiredCookies
        .where((name) => (session.cookies[name] ?? '').isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Session is missing required cookies: ${missing.join(', ')}',
      );
    }
    final envelope = <String, Object?>{
      'v': envelopeVersion,
      'cookies': session.cookies,
      'userAgent': session.userAgent,
      'capturedAt': session.capturedAt.toUtc().millisecondsSinceEpoch,
    };
    await _storage.write(key: keyFor(accountId), value: jsonEncode(envelope));
  }

  @override
  Future<SessionBlob?> load(int accountId) async {
    final String? raw;
    try {
      raw = await _storage.read(key: keyFor(accountId));
    } on Object {
      // Do not keep the exception: its text comes from the platform.
      return _unreadable(accountId, SessionUnreadableReason.platformError);
    }
    if (raw == null) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // FormatException.toString() quotes part of the input, so it is dropped.
      return _unreadable(accountId, SessionUnreadableReason.corruptJson);
    }
    if (decoded is! Map<String, Object?>) {
      return _unreadable(accountId, SessionUnreadableReason.invalidShape);
    }
    if (decoded['v'] != envelopeVersion) {
      return _unreadable(accountId, SessionUnreadableReason.unknownVersion);
    }

    final cookiesRaw = decoded['cookies'];
    final userAgent = decoded['userAgent'];
    final capturedAt = decoded['capturedAt'];
    if (cookiesRaw is! Map<String, Object?> ||
        userAgent is! String ||
        capturedAt is! int) {
      return _unreadable(accountId, SessionUnreadableReason.invalidShape);
    }
    final cookies = <String, String>{};
    for (final entry in cookiesRaw.entries) {
      final value = entry.value;
      if (value is! String) {
        return _unreadable(accountId, SessionUnreadableReason.invalidShape);
      }
      cookies[entry.key] = value;
    }
    if (requiredCookies.any((name) => (cookies[name] ?? '').isEmpty)) {
      return _unreadable(accountId, SessionUnreadableReason.invalidShape);
    }
    return SessionBlob(
      cookies: cookies,
      userAgent: userAgent,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(capturedAt, isUtc: true),
    );
  }

  @override
  Future<void> clear(int accountId) => _storage.delete(key: keyFor(accountId));

  Future<SessionBlob?> _unreadable(int accountId, String reasonCode) async {
    try {
      await onUnreadable?.call(accountId, reasonCode);
    } on Object {
      // load must never throw, even when the callback does.
    }
    return null;
  }

  @override
  String toString() => 'SecureStorageSessionStore()';
}
