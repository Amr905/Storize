import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/page/hook_protocol.dart';
import 'package:storize_instagram/page/page_driver.dart';
import 'package:storize_model/storize_model.dart';

/// Usernames allowed in a page URL (letters, digits, dot, underscore).
final RegExp pageUsernameShape = RegExp(r'^[A-Za-z0-9._]{1,30}$');

final RegExp _shortcodeShape = RegExp(r'^[A-Za-z0-9_-]{5,20}$');
final RegExp _mediaInfoPath = RegExp(r'^/api/v1/media/\d+/info/?$');

/// What to load, which captured response is the answer, and how to read it.
final class PagePlan<T> {
  /// A plan answered by a captured JSON response, or (with [collectOnLoad])
  /// the LAST RESORT plan that reads the DOM once the page has loaded.
  const PagePlan({
    required this.url,
    this.matches = _never,
    this.parse = _noParse,
    this.tentative,
    this.emptyOnPath,
    this.empty,
    this.collectOnLoad,
    this.storyViewer = false,
  });

  /// The page to load.
  final Uri url;

  /// Whether a captured response is the one this plan wants.
  final bool Function(HookCapture capture) matches;

  /// Reads the body. Null means "not the one, keep waiting"; `Err` ends the
  /// run with that failure (a `SchemaException` becomes `SchemaChanged`).
  final Result<T>? Function(Node body) parse;

  /// Called when [parse] returns null. A non-null result is a *tentative*
  /// answer (for example "no stories"): it ends the run only if no definitive
  /// answer arrives after the page has loaded plus a short grace period (QA-F8,
  /// QA-F11). A page may fire the query more than once.
  final Result<T>? Function(Node body)? tentative;

  /// Normalized lower-case path. Landing there is a *tentative* [empty]; a
  /// different single-segment user path is a tentative `username_mismatch`.
  final String? emptyOnPath;

  /// The tentative answer for [emptyOnPath].
  final Result<T>? empty;

  /// Whether this plan opens a story page. A tripped `SeenGuard` refuses it.
  final bool storyViewer;

  /// DOM plans only: reads the page once it has loaded.
  final Future<T> Function(PageSession page)? collectOnLoad;

  static bool _never(HookCapture _) => false;
  static Result<Never>? _noParse(Node _) => null;
}

/// Builds the plans of page mode. The URLs follow the web app's routes; the
/// shapes matched are the ones observed by T-002.
abstract final class PagePlans {
  static Uri _https(String path) => Uri.https('www.instagram.com', path);

  /// `/<username>/`: fires the profile and the posts queries.
  static PagePlan<UserProfile> profile(String username) => PagePlan(
    url: _https('/$username/'),
    matches: (c) => c.friendlyName == GraphqlQuery.profile.friendlyName,
    parse: (body) {
      final (profile, _) = const EnvelopeMapper().graphqlProfile(body);
      return profile == null ? const Err(TargetNotFound()) : Ok(profile);
    },
  );

  /// `/<username>/`, waiting for the posts query.
  static PagePlan<Timeline> posts(String username) => PagePlan(
    url: _https('/$username/'),
    matches: (c) => c.friendlyName == GraphqlQuery.posts.friendlyName,
    parse: (body) => Ok(
      const EnvelopeMapper().graphqlTimeline(body, usernameUsed: username),
    ),
  );

  /// `/stories/<username>/`: the reel query.
  ///
  /// Definitive: the reel of [userId]. Tentative (decided after the page has
  /// loaded plus a grace period, unless the real reel arrives first): an
  /// empty reel list or a landing on the profile page means no stories; a
  /// list holding only other users, or a landing on another user's page, means
  /// `username_mismatch` (a renamed account whose old name is someone
  /// else's now).
  static PagePlan<StoryReel> stories(String userId, String username) =>
      PagePlan(
        url: _https('/stories/$username/'),
        matches: (c) => c.friendlyName == GraphqlQuery.stories.friendlyName,
        parse: (body) {
          final mine = const EnvelopeMapper().graphqlStories(body)[userId];
          return mine == null ? null : Ok(mine);
        },
        tentative: (body) {
          final reels = const EnvelopeMapper().graphqlStories(body);
          if (reels.isEmpty) {
            return Ok(StoryReel(userId: userId, items: const []));
          }
          return reels.containsKey(userId)
              ? null
              : const Err(UnknownFailure(null, 'username_mismatch'));
        },
        emptyOnPath: '/${username.toLowerCase()}',
        empty: Ok(StoryReel(userId: userId, items: const [])),
        storyViewer: true,
      );

  /// `/p/<shortcode>/`: the REST `media/<pk>/info/` reply.
  static PagePlan<RemoteContent>? post(String shortcode) {
    if (!_shortcodeShape.hasMatch(shortcode)) return null;
    return PagePlan(
      url: _https('/p/$shortcode/'),
      matches: (c) => _mediaInfoPath.hasMatch(c.path),
      parse: (body) {
        final items = body['items'].list;
        if (items.isEmpty) return const Err(TargetNotFound());
        final item = items.first;
        final code = item['code'].stringOrNull;
        if (code != null && code != shortcode) return null;
        return Ok(const MediaMapper().post(item));
      },
    );
  }
}
