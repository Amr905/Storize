import 'package:storize_instagram/mapper/node.dart';
import 'package:storize_model/storize_model.dart';

/// A user plus the cheap change signals that come with the profile.
final class UserProfile {
  /// Creates a profile.
  const UserProfile({
    required this.user,
    this.latestReelMedia,
    this.mediaCount,
  });

  /// The user.
  final RemoteUser user;

  /// Time of the newest story item (`latest_reel_media`), or null when the
  /// user has no story. The cheap "are stories worth fetching" signal.
  final DateTime? latestReelMedia;

  /// The post count (`media_count`), when present.
  final int? mediaCount;
}

/// Maps a user dictionary (`data.user`, `user`, or a story reel's `user`).
final class UserMapper {
  /// Creates the mapper.
  const UserMapper();

  /// Maps [user]. `pk` or `id` gives the id; `username` is required.
  ///
  /// The viewer flags come from `friendship_status` (GraphQL, `following` and
  /// `blocking`) or from the flat `followed_by_viewer` / `blocked_by_viewer`
  /// (the web_profile_info shape, unverified). A missing flag is false.
  /// `blocking` means the logged-in account blocked the user; the real
  /// capture has no field for "the user blocked us".
  UserProfile profile(Node user) {
    final id = user['pk'].stringOrNull ?? user['id'].stringOrNull;
    if (id == null || id.isEmpty) throw SchemaException(user['pk'].path);
    final friendship = user['friendship_status'];
    final name = user['full_name'].stringOrNull;
    return UserProfile(
      user: RemoteUser(
        remoteUserId: id,
        username: user['username'].string,
        displayName: name == null || name.isEmpty ? null : name,
        isPrivate: user['is_private'].boolOrNull ?? false,
        followedByViewer:
            friendship['following'].boolOrNull ??
            user['followed_by_viewer'].boolOrNull ??
            false,
        blockedByViewer:
            friendship['blocking'].boolOrNull ??
            user['blocked_by_viewer'].boolOrNull ??
            false,
        avatarUrl: user['profile_pic_url'].stringOrNull,
      ),
      latestReelMedia: user['latest_reel_media'].unixTimeOrNull,
      mediaCount: user['media_count'].intOrNull,
    );
  }
}
