import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_app/debug/tools/dev_tools_actions.dart';
import 'package:storize_data/log/rotating_log_file.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_instagram/probe/probe.dart';
import 'package:storize_model/storize_model.dart';

/// Direct mode that always answers "schema changed" without any request, so
/// `InstagramPlatform` takes its real fallback into page mode. Everything else
/// is never called by the dev tools.
final class _NoDirect implements DirectOps {
  const _NoDirect();

  static const _changed = SchemaChanged('dev_tools_force_page');

  @override
  Future<Result<RemoteUser>> resolveUser(String username) async =>
      const Err(_changed);

  @override
  Future<Result<RemoteUser>> refreshUser(String id, String last) async =>
      const Err(_changed);

  @override
  Future<Result<RemoteUser>> verifySession() async => const Err(_changed);

  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> userIds,
  ) async => const Err(_changed);

  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime watermark,
  ) async => const Err(_changed);

  @override
  Future<Result<DateTime?>> latestPostTime(String userId) async =>
      const Err(_changed);
}

/// Builds a platform for the active account whose only difference from the
/// production one is the stub direct mode. Page mode is the real
/// `PageExtractor`: same governor, a `GovernorWebViewLease` on the shared lease
/// table, the seen-mutation block hook and the persisted seen breaker.
Future<InstagramPlatform> buildPageOnlyPlatform(
  AppComposition c,
  int accountId,
) async {
  final parts = c.parts;
  final log = parts.log;
  final hook = await parts.hookSource();
  final lease = GovernorWebViewLease(
    repo: c.leases,
    clock: c.clock,
    instanceId: '${c.holder}-devtools',
    log: log,
  );
  final guard = SeenGuard(store: parts.seenStore, log: log);
  final names = TargetRepoUsernameCache(c.targets);
  final discovery = PageDiscovery(clock: c.clock);
  final opens = PageOpenCounter();
  final driver = CountingPageDriver(
    LeaseHoldingPageDriver(parts.pageDriver, lease),
    opens,
  );
  final page = PageExtractor(
    accountId: accountId,
    governor: c.governor,
    sessions: parts.sessions,
    driver: driver,
    hookSource: hook,
    log: log,
    discovery: discovery,
    usernames: names,
    webViewLease: lease,
    seenGuard: guard,
    classifier: FailureClassifier(maxRetryAfter: c.governor.config.maxPause),
  );
  return InstagramPlatform(
    direct: const _NoDirect(),
    page: PageExtractorOps(page, counter: opens),
    media: CdnMediaOpener(http: parts.cdnHttp, log: log),
    seenGuard: guard,
    log: log,
    clock: c.clock,
    usernames: names,
  );
}

/// Counts the `instagram.com` cookies of the WebView store. Reads only the
/// length of the list.
Future<int> countInstagramCookies() async {
  final cookies = await CookieManager.instance().getCookies(
    url: WebUri('https://www.instagram.com/'),
  );
  return cookies.length;
}

/// Reads the last [count] lines of the rotating log files (newest last).
Future<List<String>> readLogTail(RotatingLogFile files, int count) async {
  final out = <String>[];
  // Files are newest first; collect lines backwards until enough.
  for (final file in files.files) {
    final lines = const LineSplitter().convert(
      await file.readAsString(),
    );
    out.insertAll(0, lines);
    if (out.length >= count) break;
  }
  return out.length <= count ? out : out.sublist(out.length - count);
}

/// The real actions over the production composition [c].
DevToolsActions buildDevToolsActions(AppComposition c, RotatingLogFile logs) {
  Future<int> activeId() async {
    final account = await c.accounts.getActive();
    if (account == null) throw StateError('no_active_account');
    return account.id;
  }

  InstagramPlatform? pageOnly;
  return DevToolsActions(
    scheduler: c.scheduler,
    targets: c.targets,
    content: c.content,
    clock: c.clock,
    cookieCount: countInstagramCookies,
    logTail: (n) => readLogTail(logs, n),
    pageStories: (remoteUserId) async {
      pageOnly ??= await buildPageOnlyPlatform(c, await activeId());
      return pageOnly!.fetchStories([
        remoteUserId,
      ], policy: ExtractionPolicy.directThenPage);
    },
    probe: ({required username, required userId}) async {
      final probe = IgProbe(
        accountId: await activeId(),
        governor: c.governor,
        sessions: c.parts.sessions,
        http: c.parts.igHttp,
        log: c.log,
      );
      final report = await probe.run(username: username, userId: userId);
      // The CDN check needs the media of a real story, fetched through the
      // governed direct path. The URLs are used for the request only.
      final stories = await c.platform.fetchStories([
        userId,
      ], policy: ExtractionPolicy.directOnly);
      final files = <String, RemoteMedia>{};
      if (stories case Ok(:final value)) {
        var i = 0;
        for (final item in value.values.expand((l) => l)) {
          for (final m in item.slides) {
            if (i < 2) files['story_${i++}'] = m;
          }
        }
      }
      if (files.isEmpty) return report;
      return report.withCdn(await probe.checkCdn(files));
    },
  );
}
