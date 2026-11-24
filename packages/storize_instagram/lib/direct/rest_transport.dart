import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_requests.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode over the REST candidates of TECH_SPEC 4.1 (IG-1 to IG-5).
///
/// The shapes follow the candidate table plus the web client's v1 endpoints
/// (feed/user paging, highlights tray, reels_media for highlights); device
/// verification is D5. `FallbackTransport` uses it when GraphQL cannot run.
final class RestTransport implements IgTransport {
  /// Creates the transport.
  const RestTransport({
    this.mapper = const EnvelopeMapper(),
    this.postCount = 12,
  });

  /// The envelope mapper.
  final EnvelopeMapper mapper;

  /// The `count` of IG-5.
  final int postCount;

  @override
  String get name => 'rest';

  @override
  Future<Result<UserProfile>> userByUsername(
    String username,
    IgCall call,
  ) async => profileOrNotFound(
    await callAndParse(
      call,
      RestRequests.webProfileInfo(username),
      mapper.restWebProfile,
    ),
  );

  @override
  Future<Result<UserProfile>> userById(String userId, IgCall call) =>
      callAndParse(call, RestRequests.userInfo(userId), mapper.restUserInfo);

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  ) => callAndParse(call, RestRequests.reelsMedia(userIds), mapper.restReels);

  @override
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  }) => callAndParse(
    call,
    RestRequests.userFeed(userId, count: postCount),
    mapper.restFeed,
  );

  @override
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  }) => callAndParse(
    call,
    RestRequests.userFeedPage(userId, maxId: cursor, count: postCount),
    mapper.restFeed,
  );

  @override
  Future<Result<List<RemoteHighlight>>> highlights(
    String userId,
    IgCall call,
  ) => callAndParse(
    call,
    RestRequests.highlightsTray(userId),
    mapper.restHighlights,
  );

  @override
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  ) => callAndParse(
    call,
    RestRequests.highlightReels(highlightIds),
    (body) => mapper.restHighlightItems(body, highlightIds),
  );

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) =>
      callAndParse(call, RestRequests.currentUser(), mapper.restCurrentUser);
}
