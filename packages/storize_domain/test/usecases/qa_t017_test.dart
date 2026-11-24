import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;
import 'run_check_test.dart' show H, post, story;

/// Delegates to the fake but throws from `fetchNewPosts` for [badUser].
final class ThrowingPlatform implements ContentPlatform {
  ThrowingPlatform(this.inner, this.badUser);
  final FakeContentPlatform inner;
  final String badUser;

  @override
  PlatformId get id => inner.id;
  @override
  Future<Result<RemoteUser>> resolveUser(String u) => inner.resolveUser(u);
  @override
  Future<Result<RemoteUser>> refreshUser(String a, String b) =>
      inner.refreshUser(a, b);
  @override
  Future<Result<Map<String, List<RemoteContent>>>> fetchStories(
    List<String> ids, {
    required ExtractionPolicy policy,
  }) => inner.fetchStories(ids, policy: policy);
  @override
  Future<Result<List<RemoteContent>>> fetchNewPosts(
    String userId,
    DateTime since, {
    required ExtractionPolicy policy,
  }) {
    if (userId == badUser) throw StateError('boom');
    return inner.fetchNewPosts(userId, since, policy: policy);
  }

  @override
  Future<Result<DateTime?>> latestPostTime(String u) => inner.latestPostTime(u);
  @override
  Future<Result<RemoteUser>> verifySession() => inner.verifySession();
  @override
  Stream<List<int>> openMedia(String url, {int fromByte = 0}) =>
      inner.openMedia(url, fromByte: fromByte);
}

final class ThrowingSettings implements SettingsRepo {
  @override
  Stream<AppSettings> watch() => const Stream.empty();
  @override
  Future<AppSettings> get() => throw StateError('settings down');
  @override
  Future<AppSettings> update(AppSettings Function(AppSettings) change) =>
      throw StateError('settings down');
}

RemoteContent badSlides(String id, int minutes) => RemoteContent(
  remoteId: id,
  kind: ContentKind.post,
  postType: PostType.photo,
  postedAt: s.t0.add(Duration(minutes: minutes)),
  slides: const [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://x.invalid/a',
      width: 1,
      height: 1,
    ),
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://x.invalid/b',
      width: 1,
      height: 1,
    ),
  ],
);

void main() {
  late H h;
  setUp(() async {
    h = H();
    await h.login();
  });

  Future<int> stored(Target t) async =>
      (await h.content.listByTarget(t.id)).length;

  group('1 watermark safety', () {
    test('failed call leaves watermark and check stamp alone', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const NetworkFailure());
      await h.go(CheckScope.posts);
      final after = (await h.targets.getById(t.id))!;
      expect(after.postsWatermarkAt, t.postsWatermarkAt);
      expect(after.lastPostsCheckAt, t.lastPostsCheckAt);
    });

    test(
      'partial insert failure keeps watermark; rerun has no dupes',
      () async {
        final t = await h.add('1');
        h.platform.fetchNewPostsResults.addOk([
          post('a', 10),
          badSlides('b', 20),
        ]);
        final r = await h.go(CheckScope.posts);
        expect(r.result, isNot(CheckResult.ok));
        expect(
          (await h.targets.getById(t.id))!.postsWatermarkAt,
          t.postsWatermarkAt,
        );
        h.platform.fetchNewPostsResults.addOk([post('a', 10), post('b', 20)]);
        await h.go(CheckScope.posts);
        expect(await stored(t), 2);
        expect(
          (await h.targets.getById(t.id))!.postsWatermarkAt,
          s.t0.add(const Duration(minutes: 20)),
        );
      },
    );

    test(
      'old pinned post does not hide new posts; mark = max of all',
      () async {
        final t = await h.add('1');
        h.platform.fetchNewPostsResults.addOk([
          post('pinned', -60 * 24 * 30),
          post('n1', 5),
          post('n2', 50),
          post('n3', 20),
        ]);
        await h.go(CheckScope.posts);
        expect(await stored(t), 3);
        expect(
          (await h.targets.getById(t.id))!.postsWatermarkAt,
          s.t0.add(const Duration(minutes: 50)),
        );
      },
    );

    test('watermark follows filtered reels too (reels untracked)', () async {
      final t = await h.add('1', reels: false);
      h.platform.fetchNewPostsResults.addOk([
        post('p', 5),
        post('r', 90, type: PostType.reel),
      ]);
      await h.go(CheckScope.posts);
      expect(await stored(t), 1);
      expect(
        (await h.targets.getById(t.id))!.postsWatermarkAt,
        s.t0.add(const Duration(minutes: 90)),
      );
    });

    test('equal timestamps: both stored once, rerun adds nothing', () async {
      final t = await h.add('1');
      final batch = [post('a', 30), post('b', 30)];
      h.platform.fetchNewPostsResults.addOk(batch);
      await h.go(CheckScope.posts);
      expect(await stored(t), 2);
      h.platform.fetchNewPostsResults.addOk(batch);
      final r = await h.go(CheckScope.posts);
      expect(r.newContentIds, isEmpty);
      expect(await stored(t), 2);
    });

    test('watermark never moves backwards', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addOk([post('a', 40)]);
      await h.go(CheckScope.posts);
      h.platform.fetchNewPostsResults.addOk([post('old', -5)]);
      await h.go(CheckScope.posts);
      expect(
        (await h.targets.getById(t.id))!.postsWatermarkAt,
        s.t0.add(const Duration(minutes: 40)),
      );
    });
  });

  group('2 stories diff', () {
    test('rerun is idempotent; expired story is kept (BR-4)', () async {
      final t = await h.add('1', posts: false, reels: false);
      h.platform.fetchStoriesResults.addOk({
        '1': [story('s1'), story('s2')],
      });
      await h.go(CheckScope.stories);
      h.platform.fetchStoriesResults.addOk({
        '1': [story('s2')],
      });
      final r = await h.go(CheckScope.stories);
      expect(r.newContentIds, isEmpty);
      expect(await stored(t), 2);
      h.platform.fetchStoriesResults.addOk({'1': []});
      await h.go(CheckScope.stories);
      expect(await stored(t), 2);
    });

    test('45 targets: batch 2 fails, batch 1 and 3 are stamped', () async {
      final ts = [
        for (var i = 0; i < 45; i++)
          await h.add('$i', posts: false, reels: false),
      ];
      h.platform.fetchStoriesResults
        ..addOk({})
        ..addFailure(const NetworkFailure())
        ..addOk({});
      final r = await h.go(CheckScope.stories);
      expect(r.result, CheckResult.partial);
      final stamped = [
        for (final t in ts) (await h.targets.getById(t.id))!.lastStoriesCheckAt,
      ];
      expect(stamped.take(20).every((e) => e != null), isTrue);
      expect(stamped.skip(20).take(20).every((e) => e == null), isTrue);
      expect(stamped.skip(40).every((e) => e != null), isTrue);
    });
  });

  group('3 BR-7', () {
    for (final st in [
      AccountStatus.needsRelogin,
      AccountStatus.restricted,
      AccountStatus.loggedOut,
    ]) {
      for (final scope in [CheckScope.stories, CheckScope.posts]) {
        test('$st / $scope makes zero platform calls', () async {
          h = H();
          await h.login(st);
          await h.add('1');
          final r = await h.go(scope, trigger: CheckTrigger.manualAll);
          expect(r.result, CheckResult.skippedSession);
          expect(h.platform.calls, isEmpty);
          expect(h.checkRuns.runs.single.finishedAt, isNotNull);
        });
      }
    }
  });

  group('4 isolation', () {
    test('platform throwing for one target does not abort the rest', () async {
      final plat = ThrowingPlatform(h.platform, '2');
      final run = RunCheck(
        platform: plat,
        signals: h.signals,
        targets: h.targets,
        content: h.content,
        accounts: h.accounts,
        checkRuns: h.checkRuns,
        activity: h.activity,
        settings: h.settings,
        clock: h.clock,
      );
      final a = await h.add('1');
      await h.add('2');
      final c = await h.add('3');
      h.platform.fetchNewPostsResults
        ..addOk([post('a', 5)])
        ..addOk([post('c', 5)]);
      final r = await run(
        scope: CheckScope.posts,
        trigger: CheckTrigger.periodic,
      );
      expect(r.result, CheckResult.partial);
      expect(await stored(a), 1);
      expect(await stored(c), 1);
    });

    test('one target insert exception does not stop later targets', () async {
      await h.add('1');
      final b = await h.add('2');
      h.platform.fetchNewPostsResults
        ..addOk([badSlides('x', 5)])
        ..addOk([post('b', 5)]);
      await h.go(CheckScope.posts);
      expect(await stored(b), 1);
    });

    test('check_run is finished even when the run throws', () async {
      final run = RunCheck(
        platform: h.platform,
        signals: h.signals,
        targets: h.targets,
        content: h.content,
        accounts: h.accounts,
        checkRuns: h.checkRuns,
        activity: h.activity,
        settings: ThrowingSettings(),
        clock: h.clock,
      );
      await h.add('1');
      final r = await run(
        scope: CheckScope.posts,
        trigger: CheckTrigger.periodic,
      );
      expect(r.result, CheckResult.failed);
      expect(h.checkRuns.runs.single.finishedAt, isNotNull);
    });
  });

  group('5 carry-over fairness', () {
    test('posts: budget 3 of 7 per run, all checked within 3 runs', () async {
      final ts = [for (var i = 0; i < 7; i++) await h.add('$i')];
      final seen = <String>{};
      for (var run = 0; run < 3; run++) {
        h.clock.advance(const Duration(minutes: 30));
        for (var k = 0; k < 3; k++) {
          h.platform.fetchNewPostsResults.addOk([]);
        }
        h.platform.fetchNewPostsResults.addFailure(const RateLimited(null));
        final before = h.platform.callsTo('fetchNewPosts').length;
        final r = await h.go(CheckScope.posts);
        expect(r.result, run < 2 ? CheckResult.rateLimited : isNotNull);
        for (final c in h.platform.callsTo('fetchNewPosts').skip(before)) {
          seen.add(c.args.first! as String);
        }
        // drain leftovers so the next run starts clean
        while (h.platform.fetchNewPostsResults.queued > 0) {
          h.platform.fetchNewPostsResults.take('x');
        }
      }
      expect(seen, {for (final t in ts) t.remoteUserId});
    });

    test('stories: one batch per run, 3 batches covered in 3 runs', () async {
      for (var i = 0; i < 45; i++) {
        await h.add('$i', posts: false, reels: false);
      }
      final seen = <String>{};
      for (var run = 0; run < 3; run++) {
        h.clock.advance(const Duration(minutes: 30));
        h.platform.fetchStoriesResults
          ..addOk({})
          ..addFailure(const RateLimited(null));
        final before = h.platform.callsTo('fetchStories').length;
        await h.go(CheckScope.stories);
        for (final c in h.platform.callsTo('fetchStories').skip(before)) {
          seen.addAll((c.args.first! as List).cast<String>());
        }
        while (h.platform.fetchStoriesResults.queued > 0) {
          h.platform.fetchStoriesResults.take('x');
        }
      }
      expect(seen, hasLength(45));
    });
  });

  group('6 EC-3..EC-6 transitions', () {
    for (final busy in [const NetworkFailure()]) {
      test('network/busy failure changes no status', () async {
        final t = await h.add('1');
        h.platform.fetchNewPostsResults.addFailure(busy);
        await h.go(CheckScope.posts);
        final a = (await h.targets.getById(t.id))!;
        expect(a.status, TargetStatus.active);
        expect(a.statusReason, t.statusReason);
        expect(await h.eventsOf(ActivityType.targetStatus), isEmpty);
      });
    }

    test('not visible / not found change only that target', () async {
      final a = await h.add('1');
      final b = await h.add('2');
      final c = await h.add('3');
      h.platform.fetchNewPostsResults
        ..addFailure(const TargetNotVisible())
        ..addFailure(const TargetNotFound())
        ..addOk([]);
      await h.go(CheckScope.posts);
      expect((await h.targets.getById(a.id))!.status, TargetStatus.notVisible);
      expect((await h.targets.getById(b.id))!.status, TargetStatus.unavailable);
      expect((await h.targets.getById(c.id))!.status, TargetStatus.active);
    });
  });

  group('7 track flags', () {
    test(
      'reels-only target: photo ignored, reel stored; paused skipped',
      () async {
        final t = await h.add('1', posts: false);
        await h.add('2', status: TargetStatus.paused);
        h.platform.fetchNewPostsResults.addOk([
          post('p', 5),
          post('r', 6, type: PostType.reel),
        ]);
        await h.go(CheckScope.posts);
        final rows = await h.content.listByTarget(t.id);
        expect([for (final c in rows) c.content.remoteId], ['r']);
        expect(h.platform.callsTo('fetchNewPosts'), hasLength(1));
      },
    );
  });
}
