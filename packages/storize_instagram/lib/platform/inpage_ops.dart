import 'package:storize_instagram/direct/direct_extractor.dart';
import 'package:storize_instagram/direct/username_cache.dart';
import 'package:storize_instagram/page/inpage_client.dart';
import 'package:storize_instagram/page/page_plan.dart';
import 'package:storize_instagram/platform/extraction_ops.dart';
import 'package:storize_model/storize_model.dart';

/// In-page fetching as an extraction mode (T-050): the primary transport of
/// every operation. One [InPageClient] session serves all operations of a
/// run (3 governor tokens for the page, 1 per query).
///
/// Each operation opens the session if needed ([InPageClient.ensureOpen]) and
/// then runs the shared `DirectExtractor` logic over an `InPageTransport`. If
/// the page cannot run queries (no module, no token, no WebView, kill
/// switch) the result is `UnknownFailure('inpage_unavailable')` and the
/// platform falls back to direct HTTP. Every other failure is final.
///
/// Not `final`: tests of the platform use fakes of it.
class InPageOps implements ExtractionOps, HistoryOps {
  /// Creates the mode. [extractor] must use an `InPageHttp` over [client].
  InPageOps({required this.client, required this.extractor, this.usernames});

  /// The page session.
  final InPageClient client;

  /// The shared extraction logic over the in-page transport.
  final DirectExtractor extractor;

  /// Where usernames are remembered after a profile page lookup.
  final UsernameCache? usernames;

  /// Closes the session (end of a run). Idempotent.
  Future<void> close() => client.close();

  static const Result<Never> _unavailable = Err(
    UnknownFailure(null, inPageUnavailableReason),
  );

  Future<Result<T>> _with<T>(Future<Result<T>> Function() body) async {
    final open = await client.ensureOpen();
    if (open is Err<bool>) return Err<T>(open.failure);
    client.takeUnavailable();
    final r = await body();
    if (client.takeUnavailable()) {
      await client.close();
      return _unavailable;
    }
    return r;
  }

  @override
  Future<Result<RemoteUser>> resolveUser(String username) => _with(() async {
    final clean = username.trim().replaceFirst(RegExp('^@'), '');
    final r = await extractor.resolveUser(username);
    final failure = r.failureOrNull;
    final noPosts =
        failure is UnknownFailure && failure.message == 'username_unresolvable';
    final shape =
        failure is SchemaChanged &&
        failure.where != 'page_tokens' &&
        failure.where != 'providers';
    if (client.takeUnavailable()) return _unavailable;
    if (!(noPosts || shape) || !pageUsernameShape.hasMatch(clean)) return r;
    // No posts (or an unreadable reply): the profile page, same session.
    final p = await client.loadProfile(clean);
    switch (p) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.user.username.toLowerCase() != clean.toLowerCase()) {
          return const Err(UnknownFailure(null, 'username_mismatch'));
        }
        try {
          await usernames?.remember(
            value.user.remoteUserId,
            value.user.username,
          );
        } on Object {
          // Only an optimisation.
        }
        return Ok(value.user);
    }
  });

  @override
  Future<Result<RemoteUser>> refreshUser(
    String remoteUserId,
    String lastUsername,
  ) async {
    if (lastUsername.trim().isEmpty) return const Err(TargetNotFound());
    final r = await resolveUser(lastUsername);
    return switch (r) {
      Ok(:final value) when value.remoteUserId != remoteUserId => const Err(
        TargetNotFound(),
      ),
      _ => r,
    };
  }

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) => _with(() => extractor.fetchStories(userIds));

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) => _with(() => extractor.fetchNewPosts(userId, watermark));

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) =>
      _with(() => extractor.latestPostTime(userId));

  @override
  Future<Result<PostPage>> fetchPostPage(String userId, {String? cursor}) =>
      _with(() => extractor.fetchPostPage(userId, cursor: cursor));

  @override
  Future<Result<List<RemoteHighlight>>> fetchHighlights(String userId) =>
      _with(() => extractor.fetchHighlights(userId));

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchHighlightItems(
    List<String> highlightIds, {
    int orderStart = 0,
  }) => _with(
    () => extractor.fetchHighlightItems(highlightIds, orderStart: orderStart),
  );
}
