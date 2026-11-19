import 'package:storize_model/storize_model.dart';

/// The vault for Instagram sessions (FR-2, NFR-5). Backed by secure storage.
abstract interface class SessionStore {
  /// Stores [session] for the login account [accountId], replacing any old one.
  Future<void> save(int accountId, SessionBlob session);

  /// Loads the session of [accountId], or null if none is stored or it cannot
  /// be read.
  Future<SessionBlob?> load(int accountId);

  /// Removes the session of [accountId]. Does nothing if there is none.
  Future<void> clear(int accountId);
}
