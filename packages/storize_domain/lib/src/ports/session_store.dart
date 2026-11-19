import 'package:storize_model/storize_model.dart';

/// The vault for Instagram sessions (FR-2, NFR-5). Backed by secure storage.
abstract interface class SessionStore {
  /// The cookies that every stored session must contain, non-empty
  /// (TECH_SPEC §5.1). Both the real store and the fake use this list.
  static const List<String> requiredCookies = ['sessionid', 'ds_user_id'];

  /// The names of the [requiredCookies] that [session] lacks or has empty.
  ///
  /// Returns names only, never values, so the result is safe for messages.
  static List<String> missingCookies(SessionBlob session) => [
    for (final name in requiredCookies)
      if ((session.cookies[name] ?? '').isEmpty) name,
  ];

  /// Stores [session] for the login account [accountId], replacing any old one.
  ///
  /// Throws [ArgumentError] when [session] lacks a non-empty cookie from
  /// [requiredCookies]. The message names the cookies, never their values.
  Future<void> save(int accountId, SessionBlob session);

  /// Loads the session of [accountId], or null if none is stored or it cannot
  /// be read.
  Future<SessionBlob?> load(int accountId);

  /// Removes the session of [accountId]. Does nothing if there is none.
  Future<void> clear(int accountId);
}
