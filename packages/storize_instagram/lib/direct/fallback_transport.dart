import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/direct/graphql_transport.dart';
import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_transport.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode that uses GraphQL when it can and REST otherwise, per call
/// (T-044, ADR-0003 amendment).
///
/// - GraphQL is tried first only when the `doc_id` of every query the op
///   needs and the page tokens are available right now. Otherwise the op goes
///   straight to REST (no wasted request).
/// - A GraphQL `SchemaChanged` is retried **once** on REST.
/// - What REST answers is returned as it is, so a `SchemaChanged` or
///   `UnknownFailure` still lets the platform fall back to page mode.
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

  /// Where the fallback decisions are logged (types only), or null.
  final DiagnosticLog? log;

  String _last = 'fallback';

  /// The transport that answered the latest call (`graphql` or `rest`).
  @override
  String get name => _last;

  Future<bool> _graphqlReady(List<GraphqlQuery> queries) async {
    for (final q in queries) {
      final id = await docIds.docIdFor(q);
      if (id == null || id.isEmpty) return false;
    }
    return await tokens.tokens() != null;
  }

  Future<Result<T>> _run<T>(
    String op,
    List<GraphqlQuery> queries,
    Future<Result<T>> Function(IgTransport t) body,
  ) async {
    if (await _graphqlReady(queries)) {
      final first = await body(graphql);
      if (first is! Err<T> || first.failure is! SchemaChanged) {
        _last = graphql.name;
        return first;
      }
      log?.log(
        LogLevel.info,
        'direct',
        'op=$op via=graphql failure=SchemaChanged next=rest',
      );
    } else {
      log?.log(
        LogLevel.info,
        'direct',
        'op=$op via=graphql unavailable next=rest',
      );
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
