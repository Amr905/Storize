import 'package:storize_instagram/direct/ig_http.dart';

/// The IG-1 to IG-5 requests (TECH_SPEC 4.1 candidates), in one place so the
/// transport and the live probe send exactly the same thing.
abstract final class RestRequests {
  /// IG-1: username to user.
  static IgRequest webProfileInfo(String username) => IgRequest.get(
    path: '/api/v1/users/web_profile_info/',
    query: [('username', username)],
  );

  /// IG-2: stories of several users.
  static IgRequest reelsMedia(List<String> userIds) => IgRequest.get(
    path: '/api/v1/feed/reels_media/',
    query: [for (final id in userIds) ('reel_ids', id)],
  );

  /// IG-3: user by id.
  static IgRequest userInfo(String userId) => IgRequest.get(
    host: 'i.instagram.com',
    path: '/api/v1/users/${Uri.encodeComponent(userId)}/info/',
  );

  /// IG-4: session validation.
  static IgRequest currentUser() => IgRequest.get(
    path: '/api/v1/accounts/current_user/',
    query: const [('edit', 'true')],
  );

  /// IG-5: latest posts of a user.
  static IgRequest userFeed(String userId, {int count = 12}) => IgRequest.get(
    path: '/api/v1/feed/user/${Uri.encodeComponent(userId)}/',
    query: [('count', '$count')],
  );
}
