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

  /// The web client's "Edit profile" form data: the logged-in username
  /// (first-login session check fallback, see `verifySession`).
  static IgRequest webFormData() =>
      IgRequest.get(path: '/api/v1/accounts/edit/web_form_data/');

  /// IG-5: latest posts of a user.
  static IgRequest userFeed(String userId, {int count = 12}) => IgRequest.get(
    path: '/api/v1/feed/user/${Uri.encodeComponent(userId)}/',
    query: [('count', '$count')],
  );

  /// One page of posts: the first page has no [maxId].
  static IgRequest userFeedPage(
    String userId, {
    String? maxId,
    int count = 12,
  }) => IgRequest.get(
    path: '/api/v1/feed/user/${Uri.encodeComponent(userId)}/',
    query: [('count', '$count'), if (maxId != null) ('max_id', maxId)],
  );

  /// The highlights tray of a user.
  static IgRequest highlightsTray(String userId) => IgRequest.get(
    path: '/api/v1/highlights/${Uri.encodeComponent(userId)}/highlights_tray/',
  );

  /// The items of highlights (read-only GET; never the `seen` endpoint).
  /// [highlightIds] are plain ids.
  static IgRequest highlightReels(List<String> highlightIds) => IgRequest.get(
    path: '/api/v1/feed/reels_media/',
    query: [for (final id in highlightIds) ('reel_ids', 'highlight:$id')],
  );
}
