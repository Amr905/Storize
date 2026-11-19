// Every class here is immutable: final fields and unmodifiable collections.
// The lint cannot see that without @immutable from package:meta, which this
// package does not depend on (T-003 rules out new dependencies).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// A user as Instagram reports it, before it is stored as a target.
final class RemoteUser {
  /// Creates a remote user.
  const RemoteUser({
    required this.remoteUserId,
    required this.username,
    this.displayName,
    this.isPrivate = false,
    this.avatarUrl,
  });

  /// The stable numeric user ID (`pk`). This is the identity key (FR-13).
  final String remoteUserId;

  /// The current username. It can change (EC-5).
  final String username;

  /// The full name, when the account has one.
  final String? displayName;

  /// Whether the account is private.
  final bool isPrivate;

  /// The profile picture URL. It is a signed CDN URL, so it is left out of
  /// [toString].
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteUser &&
          other.remoteUserId == remoteUserId &&
          other.username == username &&
          other.displayName == displayName &&
          other.isPrivate == isPrivate &&
          other.avatarUrl == avatarUrl);

  @override
  int get hashCode => Object.hash(
    remoteUserId,
    username,
    displayName,
    isPrivate,
    avatarUrl,
  );

  @override
  String toString() =>
      'RemoteUser(remoteUserId: $remoteUserId, username: $username, '
      'isPrivate: $isPrivate)';
}
