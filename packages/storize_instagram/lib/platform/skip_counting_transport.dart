import 'package:storize_instagram/direct/ig_transport.dart';
import 'package:storize_instagram/mapper/mapper.dart';
import 'package:storize_instagram/platform/platform_signals.dart';
import 'package:storize_model/storize_model.dart';

/// Wraps an [IgTransport] and reports `Timeline.skippedMalformed` to
/// [PlatformSignals] (T-013 N3), so the count reaches the caller although
/// `DirectExtractor` only logs it. Every other call passes straight through.
final class SkipCountingTransport implements IgTransport, LinkTransport {
  /// Wraps [inner].
  const SkipCountingTransport(this.inner, this.signals);

  /// The real transport.
  final IgTransport inner;

  /// Where the counts go.
  final PlatformSignals signals;

  @override
  String get name => inner.name;

  @override
  Future<Result<Timeline>> timeline(
    String userId,
    IgCall call, {
    String? usernameHint,
  }) async {
    final result = await inner.timeline(
      userId,
      call,
      usernameHint: usernameHint,
    );
    if (result is Ok<Timeline>) {
      signals.addSkippedMalformed(result.value.skippedMalformed);
    }
    return result;
  }

  @override
  Future<Result<Timeline>> timelinePage(
    String userId,
    IgCall call, {
    String? cursor,
    String? usernameHint,
  }) async {
    final result = await inner.timelinePage(
      userId,
      call,
      cursor: cursor,
      usernameHint: usernameHint,
    );
    if (result is Ok<Timeline>) {
      signals.addSkippedMalformed(result.value.skippedMalformed);
    }
    return result;
  }

  @override
  Future<Result<List<RemoteHighlight>>> highlights(
    String userId,
    IgCall call,
  ) => inner.highlights(userId, call);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> highlightItems(
    List<String> highlightIds,
    IgCall call,
  ) => inner.highlightItems(highlightIds, call);

  @override
  Future<Result<UserProfile>> userById(String userId, IgCall call) =>
      inner.userById(userId, call);

  @override
  Future<Result<UserProfile>> userByUsername(String username, IgCall call) =>
      inner.userByUsername(username, call);

  @override
  Future<Result<Map<String, StoryReel>>> storyReels(
    List<String> userIds,
    IgCall call,
  ) => inner.storyReels(userIds, call);

  @override
  Future<Result<Viewer>> viewer(String ownUserId, IgCall call) =>
      inner.viewer(ownUserId, call);

  @override
  Future<Result<(UserProfile, RemoteContent)?>> postByShortcode(
    String shortcode,
    IgCall call,
  ) async {
    if (inner case final LinkTransport i) {
      return i.postByShortcode(shortcode, call);
    }
    return const Err(_unsupported);
  }

  @override
  Future<Result<(UserProfile, List<RemoteContent>)?>> highlightWithOwner(
    String highlightId,
    IgCall call,
  ) async {
    if (inner case final LinkTransport i) {
      return i.highlightWithOwner(highlightId, call);
    }
    return const Err(_unsupported);
  }

  static const Failure _unsupported = UnknownFailure(
    null,
    'inpage_unsupported',
  );
}
