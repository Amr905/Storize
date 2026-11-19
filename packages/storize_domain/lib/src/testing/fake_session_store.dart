import 'package:storize_domain/src/ports/session_store.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [SessionStore] that enforces the same required-cookie rule on
/// save as the real vault.
final class FakeSessionStore implements SessionStore {
  final Map<int, SessionBlob> _sessions = {};

  /// The account IDs that currently have a stored session.
  Set<int> get accountIds => Set.unmodifiable(_sessions.keys);

  @override
  Future<void> save(int accountId, SessionBlob session) async {
    final missing = SessionStore.missingCookies(session);
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Session is missing required cookies: ${missing.join(', ')}',
      );
    }
    _sessions[accountId] = session;
  }

  @override
  Future<SessionBlob?> load(int accountId) async => _sessions[accountId];

  @override
  Future<void> clear(int accountId) async => _sessions.remove(accountId);
}
