import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/direct/rest_requests.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode over the REST candidates of TECH_SPEC 4.1 (IG-1 to IG-5).
///
/// **None of these was seen in the capture.** The shapes follow the candidate
/// table. Use this transport only where the live probe proved the calls
/// (`IgProbe`); otherwise use `GraphqlTransport`.
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

  // The REST candidates for paging and highlights were never observed, so
  // they are not guessed: the run goes to page mode.
  @override
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  }) async => const Err(SchemaChanged('rest_unsupported:timelinePage'));

  @override
  Future<Result<List<RemoteHighlight>>> highlights(
    String userId,
    IgCall call,
  ) async => const Err(SchemaChanged('rest_unsupported:highlights'));

  @override
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  ) async => const Err(SchemaChanged('rest_unsupported:highlightItems'));

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) =>
      callAndParse(call, RestRequests.currentUser(), mapper.restCurrentUser);
}
