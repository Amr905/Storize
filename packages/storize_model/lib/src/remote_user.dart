import 'package:meta/meta.dart';

/// A user as Instagram reports it, before it is stored as a target.
@immutable
final class RemoteUser {
  /// Creates a remote user.
  const RemoteUser({
    required this.remoteUserId,
    required this.username,
    required this.followedByViewer,
    required this.blockedByViewer,
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

  /// Whether the logged-in account follows this user (IG-1
  /// `followed_by_viewer`). With [isPrivate], this decides visibility (BR-2).
  final bool followedByViewer;

  /// Whether the logged-in account is blocked by this user (IG-1
  /// `blocked_by_viewer`). A blocked target is not visible (EC-4).
  final bool blockedByViewer;

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
          other.followedByViewer == followedByViewer &&
          other.blockedByViewer == blockedByViewer &&
          other.avatarUrl == avatarUrl);

  @override
  int get hashCode => Object.hash(
    remoteUserId,
    username,
    displayName,
    isPrivate,
    followedByViewer,
    blockedByViewer,
    avatarUrl,
  );

  @override
  String toString() =>
      'RemoteUser(remoteUserId: $remoteUserId, username: $username, '
      'isPrivate: $isPrivate, followedByViewer: $followedByViewer, '
      'blockedByViewer: $blockedByViewer)';
}
