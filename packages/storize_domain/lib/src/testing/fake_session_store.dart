import 'package:storize_domain/src/ports/session_store.dart';
import 'package:storize_model/storize_model.dart';

/// An in-memory [SessionStore].
final class FakeSessionStore implements SessionStore {
  final Map<int, SessionBlob> _sessions = {};

  /// The account IDs that currently have a stored session.
  Set<int> get accountIds => Set.unmodifiable(_sessions.keys);

  @override
  Future<void> save(int accountId, SessionBlob session) async =>
      _sessions[accountId] = session;

  @override
  Future<SessionBlob?> load(int accountId) async => _sessions[accountId];

  @override
  Future<void> clear(int accountId) async => _sessions.remove(accountId);
}
