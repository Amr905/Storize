import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_model/storize_model.dart';

/// The contract for a remote content platform (TECH_SPEC §4.3, NFR-8).
///
/// Every method that talks to the network returns a [Result]; it never throws
/// for expected failures. Implementations route every call through the
/// request governor (ADR-9).
abstract interface class ContentPlatform {
  /// Which platform this adapter serves.
  PlatformId get id;

  /// Looks up a user by [username] (IG-1).
  Future<Result<RemoteUser>> resolveUser(String username);

  /// Reloads a user by the stable [remoteUserId] to detect a rename (IG-3).
  ///
  /// [lastUsername] is the username we stored, used as a fallback lookup.
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  );

  /// Fetches the current stories of [userIds] in one batch (IG-2).
  ///
  /// The map is keyed by user ID. A user with no stories maps to an empty list
  /// or is absent.
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds, {
    required ExtractionPolicy policy,
  });

  /// Fetches posts of [userId] newer than [watermark] (IG-5).
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark, {
    required ExtractionPolicy policy,
  });

  /// The publish time of the newest post of [userId], or null when there is
  /// none. It sets the watermark when a target is added (FR-63).
  Future<Result<DateTime?>> latestPostTime(String userId);

  /// Checks that the stored session works and returns the logged-in user
  /// (IG-4).
  Future<Result<RemoteUser>> verifySession();

  /// Streams the bytes of a CDN file, starting at [fromByte] (CDN-1).
  ///
  /// An expired signed URL (HTTP 403) is signalled by emitting an
  /// [ExpiredMediaUrl] error on the stream. Other transfer problems are
  /// emitted as [MediaStreamFailure]. The stream is single-subscription.
  Stream<List<int>> openMedia(String url, {int fromByte = 0});
}
