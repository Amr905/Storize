import 'dart:convert';

import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// The protocol half of in-page fetching (T-050): the web app's own GraphQL
/// read queries, named, with their variables. The request it builds is the
/// neutral form `{name, variables}` that `InPageHttp` runs inside the page;
/// the page adds the `doc_id`, tokens and cookies itself.
///
/// Answers the same neutral values as `GraphqlTransport` (shared mappers).
/// `userById` and `viewer` need queries that are not allowed in the page and
/// give `UnknownFailure('inpage_unsupported')`.
final class InPageTransport implements IgTransport, LinkTransport {
  /// Creates the transport.
  const InPageTransport({
    this.mapper = const EnvelopeMapper(),
    this.postCount = 12,
    this.highlightsFirst = 30,
  });

  /// The envelope mapper.
  final EnvelopeMapper mapper;

  /// `data.count` of the posts query.
  final int postCount;

  /// `first` of the highlights tray query.
  final int highlightsFirst;

  @override
  String get name => 'inpage';

  static const String _connectionKey =
      'xdt_api__v1__feed__user_timeline_graphql_connection';

  static const Failure _unsupported = UnknownFailure(
    null,
    'inpage_unsupported',
  );

  static IgRequest _request(String query, Map<String, Object?> variables) =>
      IgRequest.postForm(
        path: '/api/graphql',
        form: {'name': query, 'variables': jsonEncode(variables)},
      );

  @override
  Future<Result<(UserProfile, RemoteContent)?>> postByShortcode(
    String shortcode,
    IgCall call,
  ) => callAndParse(
    call,
    _request('PolarisPostRootQuery', {
      'shortcode': shortcode,
      'include_longform_landscape_cover': false,
    }),
    mapper.graphqlShortcodeWebInfo,
  );

  @override
  Future<Result<(UserProfile, List<RemoteContent>)?>> highlightWithOwner(
    String highlightId,
    IgCall call,
  ) => callAndParse(
    call,
    _request('PolarisStoriesV3ReelPageStandaloneQuery', {
      'reel_ids_arr': ['highlight:$highlightId'],
      'is_highlight': true,
    }),
    (body) => mapper.graphqlHighlightWithOwner(body, highlightId),
  );

  @override
  Future<Result<UserProfile>> userById(String userId, IgCall call) async =>
      const Err(_unsupported);

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) async =>
      const Err(_unsupported);

  /// One posts query; the user is read from the posts' `user` object
  /// (`pk`, `username`, `full_name`, `profile_pic_url`, `is_private`). An
  /// account without posts is `UnknownFailure('username_unresolvable')`: the
  /// caller then reads the profile page.
  @override
  Future<Result<UserProfile>> userByUsername(
    String username,
    IgCall call,
  ) async {
    final r = await callAndParse<UserProfile?>(
      call,
      _request('PolarisProfilePostsQuery', _postsVariables(username, null)),
      (body) {
        final connection = body['data'][_connectionKey];
        final edges = connection['edges'].list;
        if (edges.isEmpty) return null;
        // Prefer a post of the asked user (a collab post names its author).
        for (final e in edges) {
          final u = e['node']['user'];
          if (u['username'].stringOrNull?.toLowerCase() ==
              username.toLowerCase()) {
            return const UserMapper().profile(u);
          }
        }
        return const UserMapper().profile(edges.first['node']['user']);
      },
    );
    return switch (r) {
      Err<UserProfile?>(:final failure) => Err(failure),
      Ok<UserProfile?>(:final value) =>
        value == null
            ? const Err(UnknownFailure(null, 'username_unresolvable'))
            : Ok(value),
    };
  }

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  ) => callAndParse(
    call,
    _request('PolarisStoriesV3ReelPageStandaloneQuery', {
      'reel_ids_arr': userIds,
      'is_highlight': false,
    }),
    mapper.graphqlStories,
  );

  @override
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  }) => timelinePage(userId, call, usernameHint: usernameHint);

  @override
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  }) async {
    final username = usernameHint;
    if (username == null) {
      return const Err(UnknownFailure(null, 'username_unknown'));
    }
    return callAndParse(
      call,
      _request('PolarisProfilePostsQuery', _postsVariables(username, cursor)),
      (body) => mapper.graphqlTimeline(body, usernameUsed: username),
    );
  }

  Map<String, Object?> _postsVariables(String username, String? cursor) => {
    'username': username,
    'data': {
      'count': postCount,
      'include_reel_media_seen_timestamp': true,
      'include_relationship_info': true,
      'latest_besties_reel_media': true,
      'latest_reel_media': true,
    },
    if (cursor != null) ...{'after': cursor, 'first': postCount},
  };

  @override
  Future<Result<List<RemoteHighlight>>> highlights(
    String userId,
    IgCall call,
  ) => callAndParse(
    call,
    _request('PolarisProfileStoryHighlightsTrayContentQuery', {
      'user_id': userId,
      'first': highlightsFirst,
    }),
    mapper.graphqlHighlights,
  );

  @override
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  ) => callAndParse(
    call,
    _request('PolarisStoriesV3ReelPageStandaloneQuery', {
      'reel_ids_arr': [for (final id in highlightIds) 'highlight:$id'],
      'is_highlight': true,
    }),
    (body) => mapper.graphqlHighlightItems(body, highlightIds),
  );
}
