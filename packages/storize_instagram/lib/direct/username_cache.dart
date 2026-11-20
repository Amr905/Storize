/// Remembers which username belongs to a user id, so a posts check does not
/// pay an extra lookup call (GraphQL needs the username for the posts query).
///
/// The default is in memory and is lost when the isolate restarts, which
/// costs one extra call per target on the first check afterwards. T-015
/// backs it with the target repo, which stores the username.
abstract interface class UsernameCache {
  /// The username stored for [userId], or null.
  Future<String?> usernameOf(String userId);

  /// Stores [username] for [userId].
  Future<void> remember(String userId, String username);
}

/// A [UsernameCache] in memory.
final class InMemoryUsernameCache implements UsernameCache {
  final Map<String, String> _names = {};

  @override
  Future<String?> usernameOf(String userId) async => _names[userId];

  @override
  Future<void> remember(String userId, String username) async =>
      _names[userId] = username;
}
