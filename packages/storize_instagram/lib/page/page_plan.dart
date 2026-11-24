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
    this.scroll,
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

  /// Set for a plan that scrolls the page after the load and collects every
  /// matching response (its [parse] returns null and keeps state).
  final PageScroll<T>? scroll;

  /// DOM plans only: reads the page once it has loaded.
  final Future<T> Function(PageSession page)? collectOnLoad;

  static bool _never(HookCapture _) => false;
  static Result<Never>? _noParse(Node _) => null;
}

/// How a scrolling plan walks the page and when it is done.
final class PageScroll<T> {
  /// Creates the spec.
  const PageScroll({
    required this.maxSteps,
    required this.satisfied,
    required this.result,
  });

  /// The most scroll steps.
  final int maxSteps;

  /// Whether what was collected is enough (stops scrolling early).
  final bool Function() satisfied;

  /// The answer from what was collected, or null when nothing usable was.
  final Result<T>? Function() result;
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

  /// `/<username>/`, waiting for the highlights tray query. Matched by the
  /// tray's name and by the shape (`data.highlights`).
  static PagePlan<List<RemoteHighlight>> highlights(String username) =>
      PagePlan(
        url: _https('/$username/'),
        matches: (c) => GraphqlQuery.highlights.matchesName(c.friendlyName),
        parse: (body) {
          if (!body['data'].has('highlights')) return null;
          return Ok(const EnvelopeMapper().graphqlHighlights(body));
        },
      );

  /// `/stories/highlights/<id>/`: the reel query for `highlight:<id>`. The
  /// page also fires the seen mutation, which the hook blocks and the
  /// extractor treats as a leak if it was answered (`storyViewer`).
  /// Tentative: an empty reel list is "no items".
  static PagePlan<List<RemoteContent>> highlightItems(String highlightId) =>
      PagePlan(
        url: _https('/stories/highlights/$highlightId/'),
        matches: (c) => c.friendlyName == GraphqlQuery.stories.friendlyName,
        parse: (body) {
          final mine = const EnvelopeMapper().graphqlHighlightItems(body, [
            highlightId,
          ]);
          final items = mine[highlightId];
          return items == null ? null : Ok(items);
        },
        tentative: (body) {
          final reels =
              body['data']['xdt_api__v1__feed__reels_media']['reels_media'];
          return reels.list.isEmpty ? const Ok(<RemoteContent>[]) : null;
        },
        storyViewer: true,
      );

  /// `/<username>/` plus scrolling: every posts connection the page fetches
  /// is collected. The result is the posts older than [cursor] (a
  /// `PostCursor`; null is the newest), at most [pageSize], newest first.
  ///
  /// Done when more than [pageSize] older posts are known, or the last
  /// response says there is no next page. If the steps run out with posts
  /// collected, the result is what was found; if no post older than the
  /// cursor was reached while more exist, it is
  /// `SchemaChanged('page_scroll_stalled')`.
  static PagePlan<PostPage> postsScroll(
    String userId,
    String username, {
    required PostCursor? cursor,
    required int pageSize,
    required int maxSteps,
  }) {
    final collected = <String, TimelineEntry>{};
    var sawResponse = false;
    bool? hasNext;
    const mapper = EnvelopeMapper();

    // Order: time desc, then pk desc (total, so a tie splits the same way
    // every time). The boundary second keeps the posts not yet delivered.
    List<TimelineEntry> older() {
      final t = cursor?.takenAt;
      return [
        for (final e in collected.values)
          if (t == null ||
              e.takenAt.isBefore(t) ||
              (e.takenAt == t && !cursor!.boundaryPks.contains(e.pk)))
            e,
      ]..sort((a, b) {
        final byTime = b.takenAt.compareTo(a.takenAt);
        return byTime != 0 ? byTime : b.pk.compareTo(a.pk);
      });
    }

    return PagePlan(
      url: _https('/$username/'),
      matches: (c) =>
          (c.friendlyName?.startsWith(GraphqlQuery.posts.friendlyName) ??
              false) ||
          _hasConnection(c.json),
      parse: (body) {
        if (!_hasConnection(body.value)) return null;
        final t = mapper.graphqlTimeline(body, usernameUsed: username);
        sawResponse = true;
        hasNext = t.hasNextPage;
        for (final e in t.entries) {
          if (e.belongsTo(userId)) collected.putIfAbsent(e.pk, () => e);
        }
        return null;
      },
      scroll: PageScroll(
        maxSteps: maxSteps,
        satisfied: () => older().length > pageSize || hasNext == false,
        result: () {
          if (!sawResponse) return null;
          final all = older();
          if (all.isEmpty) {
            return hasNext == false
                ? Ok(PostPage(items: const []))
                : const Err(SchemaChanged('page_scroll_stalled'));
          }
          if (all.length <= pageSize && hasNext == null) {
            return const Err(SchemaChanged('page_info.has_next_page'));
          }
          final page = all.take(pageSize).toList();
          final more = all.length > pageSize || hasNext == true;
          return guardMapping(
            () => PostPage(
              items: [
                for (final e in page)
                  const MediaMapper().post(
                    e.node,
                    pinned: e.pinned,
                    collab: e.isCollabOf(userId),
                  ),
              ],
              nextCursor: more
                  ? PostCursor(
                      takenAt: page.last.takenAt,
                      igCursor: '',
                      boundaryPks: {
                        for (final e in page)
                          if (e.takenAt == page.last.takenAt) e.pk,
                        if (cursor != null &&
                            cursor.takenAt == page.last.takenAt)
                          ...cursor.boundaryPks,
                      },
                    ).encode()
                  : null,
            ),
          );
        },
      ),
    );
  }

  static bool _hasConnection(Object? json) {
    if (json is! Map) return false;
    final data = json['data'];
    return data is Map &&
        data.containsKey('xdt_api__v1__feed__user_timeline_graphql_connection');
  }

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
