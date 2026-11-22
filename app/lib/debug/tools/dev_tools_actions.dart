import 'package:storize_domain/storize_domain.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

/// Loads the stories of one remote user through page mode (the real
/// `InstagramPlatform` page path: WebView lease, governor, seen-mutation
/// block hook). Wired in `dev_tools_wiring.dart`.
typedef PageStoryLoad =
    Future<Result<Map<String, List<RemoteContent>>>> Function(
      String remoteUserId,
    );

/// Counts the `instagram.com` cookies in the WebView cookie store. Only the
/// count: names and values are never read out of the store.
typedef CookieCount = Future<int> Function();

/// Runs the live probe (through the governor) and the CDN check for one
/// target. Returns the already-sanitized report.
typedef ProbeRun = Future<ProbeReport> Function({
  required String username,
  required String userId,
});

/// The last diagnostic log lines (already sanitized by the logger).
typedef LogTail = Future<List<String>> Function(int count);

/// What the dev tools can do. Every member is a port or a thin function over
/// a port, so tests use fakes.
final class DevToolsActions {
  /// Creates the actions.
  DevToolsActions({
    required this.scheduler,
    required this.targets,
    required this.content,
    required this.pageStories,
    required this.cookieCount,
    required this.probe,
    required this.logTail,
    required this.clock,
  });

  /// Background registration (the real WorkManager scheduler in production).
  final Scheduler scheduler;

  /// Targets.
  final TargetRepo targets;

  /// Content.
  final ContentRepo content;

  /// Page-mode story load.
  final PageStoryLoad pageStories;

  /// Cookie counter.
  final CookieCount cookieCount;

  /// Probe.
  final ProbeRun probe;

  /// Log reader.
  final LogTail logTail;

  /// The clock.
  final Clock clock;

  /// Remote id prefix of every synthetic row.
  static const String seedPrefix = 'seed_';

  /// Remote user id of the synthetic target that owns the seeded rows.
  static const String seedTargetRemoteId = 'seed_target';

  /// Username of the synthetic target.
  static const String seedUsername = 'seed_user';

  /// Default number of seeded rows.
  static const int defaultSeedCount = 2000;

  /// Log lines shown by [recentLog].
  static const int logLines = 50;

  /// 1. Enqueues the expedited one-off check for all targets (runs in the
  /// WorkManager isolate, also after the app closes).
  Future<String> runCheckNow() async {
    try {
      await scheduler.checkNow();
      return 'check_now enqueued scope=all';
    } on Object catch (error) {
      return 'check_now failed type=${error.runtimeType}';
    }
  }

  /// 2. One page-mode stories load for [target]. A busy or rate-limited answer
  /// is shown, never retried.
  Future<String> loadStoriesInPageMode(Target target) async {
    try {
      final result = await pageStories(target.remoteUserId);
      switch (result) {
        case Ok(:final value):
          final items = value.values.fold<int>(0, (n, l) => n + l.length);
          return 'page_stories ok users=${value.length} items=$items';
        case Err(:final failure):
          return 'page_stories ${describeFailure(failure)}';
      }
    } on Object catch (error) {
      return 'page_stories failed type=${error.runtimeType}';
    }
  }

  /// 3. The number of `instagram.com` cookies in the WebView store.
  Future<String> countCookies() async {
    try {
      return 'webview_cookies count=${await cookieCount()}';
    } on Object catch (error) {
      return 'webview_cookies failed type=${error.runtimeType}';
    }
  }

  /// 4. The probe report for [target], as the probe wrote it.
  Future<String> runProbe(Target target) async {
    try {
      final report = await probe(
        username: target.username,
        userId: target.remoteUserId,
      );
      return report.render();
    } on Object catch (error) {
      return 'probe failed type=${error.runtimeType}';
    }
  }

  /// 5. Inserts [count] synthetic rows (placeholder media, no network) under
  /// a synthetic target. Returns how many were new.
  Future<String> seedLibrary([int count = defaultSeedCount]) async {
    try {
      final target = await _seedTarget(create: true);
      final now = clock.now().toUtc();
      var added = 0;
      for (var i = 0; i < count; i++) {
        final remoteId = '$seedPrefix$i';
        final result = await content.insertIfNew(
          Content(
            id: Content.unsavedId,
            targetId: target!.id,
            kind: ContentKind.story,
            remoteId: remoteId,
            postedAt: now.subtract(Duration(minutes: i * 7)),
            slideCount: 1,
            detectedAt: now,
            status: ContentStatus.done,
            viewed: true,
          ),
          [
            MediaFile(
              id: MediaFile.unsavedId,
              contentId: MediaFile.unsavedContentId,
              slideIndex: 0,
              mediaType: MediaType.photo,
              sourceUrl: 'placeholder://seed/$i',
              status: MediaFileStatus.done,
              displayName: '$remoteId.jpg',
              width: 1080,
              height: 1920,
              sizeBytes: 1,
              downloadedAt: now,
            ),
          ],
        );
        if (result.isNew) added++;
      }
      return 'seed added=$added requested=$count';
    } on Object catch (error) {
      return 'seed failed type=${error.runtimeType}';
    }
  }

  /// 5b. Removes only the seeded rows (remote id prefix [seedPrefix], under
  /// the synthetic target), then the synthetic target itself.
  Future<String> clearSeed() async {
    try {
      final target = await _seedTarget(create: false);
      if (target == null) return 'seed_cleared removed=0';
      final rows = await content.listByTarget(target.id);
      final ids = [
        for (final r in rows)
          if (r.content.remoteId.startsWith(seedPrefix)) r.content.id,
      ];
      if (ids.isNotEmpty) await content.deleteByIds(ids);
      final left = await content.listByTarget(target.id);
      // Only delete the synthetic target when nothing else hangs on it.
      if (left.isEmpty) await targets.delete(target.id);
      return 'seed_cleared removed=${ids.length}';
    } on Object catch (error) {
      return 'seed_clear failed type=${error.runtimeType}';
    }
  }

  /// 6. The last [logLines] log lines.
  Future<List<String>> recentLog() => logTail(logLines);

  /// A failure as one safe line: the type, plus a short label for busy and
  /// rate-limited. Never the message or payload.
  static String describeFailure(Failure failure) => switch (failure) {
    RateLimited() => 'rate_limited (not retried)',
    NetworkFailure() => 'busy_or_network (not retried)',
    final f => 'failed type=${f.runtimeType}',
  };

  Future<Target?> _seedTarget({required bool create}) async {
    final existing = await targets.getByRemoteUserId(
      PlatformId.instagram,
      seedTargetRemoteId,
    );
    if (existing != null || !create) return existing;
    final now = clock.now().toUtc();
    return targets.insert(
      Target(
        id: Target.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: seedTargetRemoteId,
        username: seedUsername,
        category: TargetCategory.public,
        postsWatermarkAt: now,
        addedAt: now,
        // Paused: a scheduled check never touches the synthetic target.
        status: TargetStatus.paused,
      ),
    );
  }
}
