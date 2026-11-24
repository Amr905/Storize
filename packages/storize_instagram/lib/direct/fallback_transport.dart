import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/direct/graphql_transport.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_transport.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode: GraphQL when it can run, REST only where a probe proved it
/// (T-044, gated by T-045; ADR-0003 amendment).
///
/// - GraphQL is tried first only when the `doc_id` of every query the op
///   needs and the page tokens are available right now (they may come from
///   the persisted `PageDiscovery`).
/// - Without them, or when GraphQL answers `SchemaChanged`, REST is used
///   **only** for ops in [restOps] (what a probe report proved). Otherwise
///   the `SchemaChanged` is returned **without any request**, so the
///   platform uses page mode in the foreground and skips cleanly in the
///   background. The device showed an unproven REST route answering 404 and a
///   "please wait" soft block, so unproven REST is never tried.
/// - A GraphQL `SchemaChanged` drops the `doc_id`s of that op from the
///   [docIds] store when it can forget them (a stale `doc_id`).
/// - Every other failure (rate limit, session, private, not found, network)
///   is returned as it is, with no retry on the other transport.
///
/// Every request still goes through the governed [IgCall]. The log gets the
/// op name and failure types only.
final class FallbackTransport implements IgTransport {
  /// Creates the transport. [log] is optional.
  FallbackTransport({
    required this.docIds,
    required this.tokens,
    GraphqlTransport? graphql,
    this.rest = const RestTransport(),
    this.restOps = const {},
    this.log,
  }) : graphql = graphql ?? GraphqlTransport(docIds: docIds, tokens: tokens);

  /// Finds the current `doc_id`s.
  final DocIdResolver docIds;

  /// Supplies the page tokens.
  final PageTokenProvider tokens;

  /// The GraphQL half.
  final GraphqlTransport graphql;

  /// The REST half.
  final RestTransport rest;

  /// The ops (method names of [IgTransport]) whose REST route a probe proved.
  /// Empty by default: REST is not used.
  final Set<String> restOps;

  /// Where the fallback decisions are logged (types only), or null.
  final DiagnosticLog? log;

  String _last = 'fallback';

  /// The transport that answered the latest call (`graphql` or `rest`).
  @override
  String get name => _last;

  /// The `where` of the first missing piece, or null when GraphQL can run.
  Future<String?> _missing(List<GraphqlQuery> queries) async {
    for (final q in queries) {
      final id = await docIds.docIdFor(q);
      if (id == null || id.isEmpty) return 'doc_id:${q.friendlyName}';
    }
    return await tokens.tokens() == null ? 'page_tokens' : null;
  }

  Future<void> _forget(List<GraphqlQuery> queries) async {
    final resolver = docIds;
    if (resolver is! DocIdForgetter) return;
    final all = [
      ...queries,
      // The paging doc_id goes with the posts one when a timeline fails.
      if (queries.contains(GraphqlQuery.posts)) GraphqlQuery.postsPaging,
    ];
    for (final q in all) {
      try {
        await resolver.forget(q);
      } on Object {
        // Only a clean-up.
      }
    }
  }

  Future<Result<T>> _run<T>(
    String op,
    List<GraphqlQuery> queries,
    Future<Result<T>> Function(IgTransport t) body,
  ) async {
    final missing = await _missing(queries);
    final restAllowed = restOps.contains(op);
    if (missing == null) {
      _last = graphql.name;
      final first = await body(graphql);
      if (first is! Err<T> || first.failure is! SchemaChanged) {
        _last = graphql.name;
        return first;
      }
      final where = (first.failure as SchemaChanged).where;
      if (!where.startsWith('doc_id:') && where != 'page_tokens') {
        await _forget(queries);
      }
      log?.log(
        LogLevel.info,
        'direct',
        'op=$op via=graphql failure=SchemaChanged '
            'next=${restAllowed ? 'rest' : 'none'}',
      );
      if (!restAllowed) {
        _last = graphql.name;
        return first;
      }
    } else {
      log?.log(
        LogLevel.info,
        'direct',
        'op=$op via=graphql unavailable next=${restAllowed ? 'rest' : 'none'}',
      );
      if (!restAllowed) {
        // No request: the platform decides (page mode or a clean skip).
        _last = graphql.name;
        return Err<T>(SchemaChanged(missing));
      }
    }
    _last = rest.name;
    return body(rest);
  }

  @override
  Future<Result<UserProfile>> userByUsername(String username, IgCall call) =>
      _run('userByUsername', const [
        GraphqlQuery.posts,
        GraphqlQuery.profile,
      ], (t) => t.userByUsername(username, call));

  @override
  Future<Result<UserProfile>> userById(String userId, IgCall call) => _run(
    'userById',
    const [GraphqlQuery.profile],
    (t) => t.userById(userId, call),
  );

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  ) => _run('storyReels', const [
    GraphqlQuery.stories,
  ], (t) => t.storyReels(userIds, call));

  @override
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  }) => _run('timeline', [
    GraphqlQuery.posts,
    if (usernameHint == null) GraphqlQuery.profile,
  ], (t) => t.timeline(userId, call, usernameHint: usernameHint));

  @override
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  }) => _run(
    'timelinePage',
    [GraphqlQuery.posts, if (usernameHint == null) GraphqlQuery.profile],
    (t) => t.timelinePage(
      userId,
      call,
      cursor: cursor,
      usernameHint: usernameHint,
    ),
  );

  @override
  Future<Result<List<RemoteHighlight>>> highlights(
    String userId,
    IgCall call,
  ) => _run('highlights', const [
    GraphqlQuery.highlights,
  ], (t) => t.highlights(userId, call));

  @override
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  ) => _run('highlightItems', const [
    GraphqlQuery.stories,
  ], (t) => t.highlightItems(highlightIds, call));

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) => _run(
    'viewer',
    const [GraphqlQuery.profile],
    (t) => t.viewer(ownUserId, call),
  );
}
