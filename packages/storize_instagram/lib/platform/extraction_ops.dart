import 'package:storize_instagram/direct/direct_extractor.dart';
import 'package:storize_instagram/page/page_extractor.dart';
import 'package:storize_instagram/platform/page_open_counter.dart';
import 'package:storize_model/storize_model.dart';

/// The operations both extraction modes offer, as `InstagramPlatform` uses
/// them (named `...Ops` so it does not clash with the `ExtractionMode` enum of
/// `storize_model`). `DirectExtractor` and `PageExtractor` are final classes,
/// so tests of the mode selection use fakes of this interface instead.
abstract interface class ExtractionOps {
  /// Looks up a user by username.
  Future<Result<RemoteUser>> resolveUser(String username);

  /// Reloads a user by id (rename detection).
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  );

  /// The current stories of [userIds].
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  );

  /// Posts of [userId] newer than [watermark].
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  );

  /// The time of the newest post of [userId], or null.
  Future<Result<DateTime?>> latestPostTime(String userId);
}

/// The history operations (T-041), kept apart from [ExtractionOps] so
/// existing implementers (the dev tools stub) keep compiling. The platform
/// answers `UnknownFailure('not_implemented')` for a mode that lacks them.
abstract interface class HistoryOps {
  /// One page of posts of [userId] (see `PostCursor` for the cursor).
  Future<Result<PostPage>> fetchPostPage(String userId, {String? cursor});

  /// The highlights tray of [userId].
  Future<Result<List<RemoteHighlight>>> fetchHighlights(String userId);

  /// The items of [highlightIds] by highlight id. [orderStart] is added to
  /// each `highlightOrder`.
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    int orderStart = 0,
  });
}

/// Direct mode: adds the session check that only direct mode can do.
abstract interface class DirectOps implements ExtractionOps {
  /// Checks the stored session and returns the logged-in user.
  Future<Result<RemoteUser>> verifySession();
}

/// Page mode: the WebView fallback.
abstract interface class PageOps implements ExtractionOps {
  /// How many WebView sessions this mode has opened so far, or null when it
  /// does not know. The platform compares the value before and after a call
  /// to tell "page mode ran" from "page mode was refused before loading".
  int? get pagesOpened;
}

/// [DirectOps] over a [DirectExtractor].
final class DirectExtractorOps implements DirectOps, HistoryOps {
  /// Wraps [extractor].
  const DirectExtractorOps(this.extractor);

  /// The wrapped extractor.
  final DirectExtractor extractor;

  @override
  Future<Result<RemoteUser>> resolveUser(String username) =>
      extractor.resolveUser(username);

  @override
  Future<Result<RemoteUser>> refreshUser(String id, String lastUsername) =>
      extractor.refreshUser(id, lastUsername);

  @override
  Future<Result<RemoteUser>> verifySession() => extractor.verifySession();

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => extractor.fetchStories(userIds);

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => extractor.fetchNewPosts(userId, watermark);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      extractor.latestPostTime(userId);

  @override
  Future<Result<PostPage>> fetchPostPage(String userId, {String? cursor}) =>
      extractor.fetchPostPage(userId, cursor: cursor);

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(String userId) =>
      extractor.fetchHighlights(userId);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    int orderStart = 0,
  }) => extractor.fetchHighlightItems(highlightIds, orderStart: orderStart);
}

/// [PageOps] over a [PageExtractor].
final class PageExtractorOps implements PageOps, HistoryOps {
  /// Wraps [extractor]. Give the [counter] that the page driver of
  /// [extractor] reports to (see `CountingPageDriver`).
  const PageExtractorOps(this.extractor, {this.counter});

  /// The wrapped extractor.
  final PageExtractor extractor;

  /// Counts the sessions the driver opened, or null if not counted.
  final PageOpenCounter? counter;

  @override
  int? get pagesOpened => counter?.opened;

  @override
  Future<Result<RemoteUser>> resolveUser(String username) =>
      extractor.resolveUser(username);

  @override
  Future<Result<RemoteUser>> refreshUser(String id, String lastUsername) =>
      extractor.refreshUser(id, lastUsername);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => extractor.fetchStories(userIds);

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => extractor.fetchNewPosts(userId, watermark);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      extractor.latestPostTime(userId);

  @override
  Future<Result<PostPage>> fetchPostPage(String userId, {String? cursor}) =>
      extractor.fetchPostPage(userId, cursor: cursor);

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(String userId) =>
      extractor.fetchHighlights(userId);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    int orderStart = 0,
  }) => extractor.fetchHighlightItems(highlightIds, orderStart: orderStart);
}
