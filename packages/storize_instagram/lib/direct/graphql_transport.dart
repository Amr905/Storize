import 'dart:convert';

import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode over the GraphQL queries the web app uses (observed in the
/// T-002 capture): `POST /api/graphql` with a runtime-discovered `doc_id`.
///
/// Nothing here hard-codes a `doc_id`. A missing `doc_id` or missing page
/// tokens give `SchemaChanged`, which sends the run to page mode. The relay
/// provider flags the web app adds to `variables` are unknown and omitted:
/// whether the server accepts that is for the live test to show.
final class GraphqlTransport implements IgTransport {
  /// Creates the transport.
  const GraphqlTransport({
    required this.docIds,
    required this.tokens,
    this.mapper = const EnvelopeMapper(),
    this.postCount = 12,
  });

  /// Finds the current `doc_id`s.
  final DocIdResolver docIds;

  /// Supplies the page tokens.
  final PageTokenProvider tokens;

  /// The envelope mapper.
  final EnvelopeMapper mapper;

  /// `data.count` of the posts query (12 in the capture).
  final int postCount;

  @override
  String get name => 'graphql';

  @override
  Future<Result<UserProfile>> userById(String userId, IgCall call) async {
    final request = await _request(GraphqlQuery.profile, {
      'id': userId,
      'enable_integrity_filters': true,
    });
    if (request is Err<IgRequest>) return Err(request.failure);
    final result = await callAndParse<(UserProfile?, String?)>(
      call,
      (request as Ok<IgRequest>).value,
      mapper.graphqlProfile,
    );
    return profileOrNotFound(result.map((r) => r.$1));
  }

  /// Two calls: the posts query by username gives the owner id, then the
  /// profile query by that id gives the user. Fails for an account with no
  /// posts and for a private account the viewer does not follow.
  @override
  Future<Result<UserProfile>> userByUsername(
    String username,
    IgCall call,
  ) async {
    final posts = await _timeline(username, call);
    if (posts is Err<Timeline>) return Err(posts.failure);
    final ownerId = _ownerOf((posts as Ok<Timeline>).value);
    if (ownerId == null) {
      return const Err(UnknownFailure(null, 'username_unresolvable'));
    }
    return userById(ownerId, call);
  }

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  ) async {
    final request = await _request(GraphqlQuery.stories, {
      'reel_ids_arr': userIds,
    });
    if (request is Err<IgRequest>) return Err(request.failure);
    return callAndParse(
      call,
      (request as Ok<IgRequest>).value,
      mapper.graphqlStories,
    );
  }

  @override
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  }) async {
    var username = usernameHint;
    if (username == null) {
      final profile = await userById(userId, call);
      if (profile is Err<UserProfile>) return Err(profile.failure);
      username = (profile as Ok<UserProfile>).value.user.username;
    }
    return _timeline(username, call);
  }

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) async {
    final request = await _request(GraphqlQuery.profile, {
      'id': ownUserId,
      'enable_integrity_filters': true,
    });
    if (request is Err<IgRequest>) return Err(request.failure);
    return callAndParse(call, (request as Ok<IgRequest>).value, (body) {
      final (profile, viewerId) = mapper.graphqlProfile(body);
      if (viewerId == null) {
        throw SchemaException(body['data']['viewer']['user']['id'].path);
      }
      return Viewer(viewerId: viewerId, profile: profile);
    });
  }

  Future<Result<Timeline>> _timeline(String username, IgCall call) async {
    final request = await _request(GraphqlQuery.posts, {
      'username': username,
      'data': {
        'count': postCount,
        'include_reel_media_seen_timestamp': true,
        'include_relationship_info': true,
        'latest_reel_media': true,
        'latest_besties_reel_media': true,
      },
    });
    if (request is Err<IgRequest>) return Err(request.failure);
    return callAndParse(
      call,
      (request as Ok<IgRequest>).value,
      (body) => mapper.graphqlTimeline(body, usernameUsed: username),
    );
  }

  /// The profile owner's id from a timeline. Collab posts carry another
  /// author's id, so only posts without co-authors vote; if there are none,
  /// the one id present in every post.
  String? _ownerOf(Timeline timeline) {
    final solo = [
      for (final e in timeline.entries)
        if (e.coauthorIds.isEmpty && e.authorIds.length == 1) e,
    ];
    if (solo.isNotEmpty) return solo.first.authorIds.first;
    Set<String>? common;
    for (final e in timeline.entries) {
      final ids = {...e.authorIds, ...e.coauthorIds};
      common = common == null ? ids : common.intersection(ids);
    }
    return common != null && common.length == 1 ? common.first : null;
  }

  Future<Result<IgRequest>> _request(
    GraphqlQuery query,
    Map<String, Object?> variables,
  ) async {
    final docId = await docIds.docIdFor(query);
    if (docId == null || docId.isEmpty) {
      return Err(SchemaChanged('doc_id:${query.friendlyName}'));
    }
    final extra = await tokens.tokens();
    if (extra == null) return const Err(SchemaChanged('page_tokens'));
    final request = IgRequest.postForm(
      path: '/api/graphql',
      form: {
        ...extra,
        'doc_id': docId,
        'variables': jsonEncode(variables),
        'fb_api_req_friendly_name': query.friendlyName,
      },
    );
    return Ok(request.withHeaders({'X-FB-Friendly-Name': query.friendlyName}));
  }
}
