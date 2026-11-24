import 'package:storize_instagram/direct/ig_http.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Sends one request through the governor and returns the JSON object of a
/// successful reply, or the failure from the failure map. Built by the
/// extractor; a transport must call it **sequentially** (one `await` at a
/// time), never from inside another governed call.
typedef IgCall = Future<Result<Map<String, Object?>>> Function(
  IgRequest request,
);

/// One way of asking Instagram: the protocol half of direct mode.
///
/// `RestTransport` speaks the REST candidates IG-1 to IG-5 (unverified until
/// the live probe); `GraphqlTransport` speaks the observed GraphQL queries.
/// Both give the same neutral values, built with the shared mappers, so the
/// extractor above them does not care which one runs.
abstract interface class IgTransport {
  /// `rest` or `graphql`, for logs.
  String get name;

  /// Looks a user up by username. A missing user is `Err(TargetNotFound)`.
  Future<Result<UserProfile>> userByUsername(String username, IgCall call);

  /// Looks a user up by id. A missing user is `Err(TargetNotFound)`.
  Future<Result<UserProfile>> userById(String userId, IgCall call);

  /// The story reels of [userIds] (at most 20 per call, the extractor chunks).
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  );

  /// The first page of posts of [userId]. [usernameHint] saves a lookup for a
  /// transport that needs the username.
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  });

  /// One page of posts of [userId]. [cursor] is Instagram's `end_cursor` of
  /// the previous page (null: the first page). The [Timeline] carries
  /// `endCursor` and `hasNextPage`. A transport that cannot page answers
  /// `SchemaChanged`.
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  });

  /// The highlights tray of [userId], in tray order.
  Future<Result<List<RemoteHighlight>>> highlights(String userId, IgCall call);

  /// The items of the highlights [highlightIds] (plain ids, at most 20 per
  /// call), keyed by highlight id.
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  );

  /// Who the session belongs to. [ownUserId] is the stored `ds_user_id`.
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call);
}

/// Sends [request] with [call] and parses the JSON object with [parse].
/// A [SchemaException] inside [parse] becomes `Err(SchemaChanged(where))`.
Future<Result<R>> callAndParse<R>(
  IgCall call,
  IgRequest request,
  R Function(Node body) parse,
) async {
  final reply = await call(request);
  return switch (reply) {
    Err<Map<String, Object?>>(:final failure) => Err<R>(failure),
    Ok<Map<String, Object?>>(:final value) => guardMapping(
      () => parse(Node.root(value, 'response')),
    ),
  };
}

/// `Ok(profile)` or `Err(TargetNotFound)` for a null profile.
Result<UserProfile> profileOrNotFound(Result<UserProfile?> result) =>
    switch (result) {
      Err<UserProfile?>(:final failure) => Err(failure),
      Ok<UserProfile?>(:final value) =>
        value == null ? const Err(TargetNotFound()) : Ok(value),
    };
