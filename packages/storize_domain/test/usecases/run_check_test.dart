import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

RemoteContent story(String id, {DateTime? at}) => RemoteContent(
  remoteId: id,
  kind: ContentKind.story,
  postedAt: at ?? s.t0.add(const Duration(hours: 1)),
  expiresAt: s.t0.add(const Duration(hours: 25)),
  slides: const [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://example.invalid/s',
      width: 10,
      height: 10,
    ),
  ],
);

RemoteContent post(
  String id,
  int minutes, {
  PostType type = PostType.photo,
}) => RemoteContent(
  remoteId: id,
  kind: ContentKind.post,
  shortcode: 'sc$id',
  postType: type,
  postedAt: s.t0.add(Duration(minutes: minutes)),
  slides: const [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://example.invalid/p',
      width: 10,
      height: 10,
    ),
  ],
);

RemoteUser ruser(
  String id,
  String name, {
  bool priv = false,
  bool followed = true,
  bool blocked = false,
}) => RemoteUser(
  remoteUserId: id,
  username: name,
  followedByViewer: followed,
  blockedByViewer: blocked,
  isPrivate: priv,
);

/// Signals that appear during the next platform call: the use case takes
/// once before the call (a reset) and once after it.
final class DuringCallSignals implements ContentSignals {
  final List<ContentSignalsSnapshot> _afterCall = [];
  bool _nextIsBefore = true;

  void duringNextCall({int skipped = 0, int pageUses = 0}) => _afterCall.add(
    ContentSignalsSnapshot(skippedMalformed: skipped, pageModeUses: pageUses),
  );

  @override
  ContentSignalsSnapshot takeSignals() {
    final before = _nextIsBefore;
    _nextIsBefore = !_nextIsBefore;
    if (before || _afterCall.isEmpty) return const ContentSignalsSnapshot();
    return _afterCall.removeAt(0);
  }
}

final class H {
  final platform = FakeContentPlatform();
  final signals = DuringCallSignals();
  final targets = FakeTargetRepo();
  final accounts = FakeAccountRepo();
  final checkRuns = FakeCheckRunRepo();
  final settings = FakeSettingsRepo();
  final clock = FakeClock(s.t0.add(const Duration(days: 1)));
  late final FakeContentRepo content = FakeContentRepo(targets: targets);
  late final FakeActivityRepo activity = FakeActivityRepo(clock);
  late final RunCheck run = RunCheck(
    platform: platform,
    signals: signals,
    targets: targets,
    content: content,
    accounts: accounts,
    checkRuns: checkRuns,
    activity: activity,
    settings: settings,
    clock: clock,
  );

  Future<void> login([AccountStatus status = AccountStatus.active]) => accounts
      .upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'me',
          username: 'me',
          status: status,
          connectedAt: s.t0,
        ),
      )
      .then((_) {});

  Future<Target> add(
    String id, {
    TargetStatus status = TargetStatus.active,
    bool stories = true,
    bool posts = true,
    bool reels = true,
    DateTime? lastStories,
    DateTime? lastPosts,
  }) => targets.insert(
    s
        .target(remoteUserId: id, username: 'u$id', status: status)
        .copyWith(
          trackStories: stories,
          trackPosts: posts,
          trackReels: reels,
          lastStoriesCheckAt: lastStories,
          lastPostsCheckAt: lastPosts ?? clock.now(),
        ),
  );

  Future<List<ActivityEvent>> events() => activity.watchRecent().first;
  Future<List<ActivityEvent>> eventsOf(ActivityType t) async => [
    for (final e in await events())
      if (e.type == t) e,
  ];

  Future<CheckRunResult> go(
    CheckScope scope, {
    CheckTrigger trigger = CheckTrigger.periodic,
    int? targetId,
    DateTime? deadline,
  }) => run(
    scope: scope,
    trigger: trigger,
    targetId: targetId,
    deadline: deadline,
  );
}

void main() {
  late H h;
  setUp(() async {
    h = H();
    await h.login();
  });

  group('AC1 scope and eligibility', () {
    test('stories checks only active targets with trackStories', () async {
      await h.add('1');
      await h.add('2', stories: false);
      await h.add('3', status: TargetStatus.paused);
      h.platform.fetchStoriesResults.addOk({'1': []});
      await h.go(CheckScope.stories);
      expect(h.platform.callsTo('fetchStories').single.args.first, ['1']);
    });

    test('posts checks trackPosts or trackReels, skips paused', () async {
      await h.add('1', stories: false, posts: false);
      await h.add('2', reels: false);
      await h.add('3', status: TargetStatus.paused);
      await h.add('4', posts: false, reels: false);
      h.platform.fetchNewPostsResults.fallback = const Ok([]);
      await h.go(CheckScope.posts);
      expect(
        [for (final c in h.platform.callsTo('fetchNewPosts')) c.args.first],
        unorderedEquals(['1', '2']),
      );
    });

    test('scope all is rejected', () {
      expect(
        () => h.go(CheckScope.all),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('targetId limits a manual check to one target', () async {
      await h.add('1');
      final two = await h.add('2');
      h.platform.fetchStoriesResults.addOk({});
      await h.go(
        CheckScope.stories,
        trigger: CheckTrigger.manualOne,
        targetId: two.id,
      );
      expect(h.platform.callsTo('fetchStories').single.args.first, ['2']);
    });
  });

  group('AC2 BR-7 session', () {
    test('needs-relogin session records SKIPPED_SESSION, no calls', () async {
      h = H();
      await h.login(AccountStatus.needsRelogin);
      await h.add('1');
      final r = await h.go(CheckScope.stories);
      expect(r.result, CheckResult.skippedSession);
      expect(h.platform.calls, isEmpty);
      expect(h.checkRuns.runs.single.result, CheckResult.skippedSession);
      expect(h.checkRuns.runs.single.mode, isNull);
    });

    test('no account at all also skips', () async {
      h = H();
      await h.add('1');
      final r = await h.go(CheckScope.posts);
      expect(r.result, CheckResult.skippedSession);
      expect(h.platform.calls, isEmpty);
    });

    test('SessionInvalid stops the run and flags the account', () async {
      await h.add('1');
      await h.add('2');
      h.platform.fetchNewPostsResults.addFailure(
        const SessionInvalid(SessionReason.challenge),
      );
      final r = await h.go(CheckScope.posts);
      expect(r.result, CheckResult.failed);
      expect(h.platform.callsTo('fetchNewPosts'), hasLength(1));
      final acc = (await h.accounts.getActive())!;
      expect(acc.status, AccountStatus.needsRelogin);
      expect(acc.statusReason, 'challenge');
      expect(await h.eventsOf(ActivityType.sessionProblem), hasLength(1));
    });

    test('AccountRestricted marks the account RESTRICTED', () async {
      await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const AccountRestricted());
      await h.go(CheckScope.posts);
      expect(
        (await h.accounts.getActive())!.status,
        AccountStatus.restricted,
      );
    });
  });

  group('AC3 stories', () {
    test('batches of at most 20', () async {
      for (var i = 0; i < 45; i++) {
        await h.add('$i');
      }
      h.platform.fetchStoriesResults.fallback = const Ok({});
      await h.go(CheckScope.stories);
      final sizes = [
        for (final c in h.platform.callsTo('fetchStories'))
          (c.args.first! as List).length,
      ];
      expect(sizes, [20, 20, 5]);
    });

    test('diffs by remote_id and stores PENDING media', () async {
      final t = await h.add('1');
      await h.content.insertIfNew(
        s.content(targetId: t.id, remoteId: 'old'),
        [s.media()],
      );
      h.platform.fetchStoriesResults.addOk({
        '1': [story('old'), story('new')],
      });
      final r = await h.go(CheckScope.stories);
      expect(r.newContentIds, hasLength(1));
      final stored = (await h.content.getById(r.newContentIds.single))!;
      expect(stored.content.remoteId, 'new');
      expect(stored.content.status, ContentStatus.pending);
      expect(stored.media.single.status, MediaFileStatus.pending);
      expect(r.run.newItems, 1);
      final again = h.platform.fetchStoriesResults
        ..addOk({
          '1': [story('new')],
        });
      expect(again.queued, 1);
      final r2 = await h.go(CheckScope.stories);
      expect(r2.newContentIds, isEmpty);
    });

    test('extras are persisted', () async {
      await h.add('1');
      final c = RemoteContent(
        remoteId: 'x',
        kind: ContentKind.story,
        postedAt: s.t0,
        slides: story('x').slides,
        extras: const {'unsupported_stream': 'dash'},
      );
      h.platform.fetchStoriesResults.addOk({
        '1': [c],
      });
      final r = await h.go(CheckScope.stories);
      final stored = (await h.content.getById(r.newContentIds.single))!;
      expect(stored.content.extras['unsupported_stream'], 'dash');
    });

    test('target check time and last new story are stamped', () async {
      final t = await h.add('1');
      h.platform.fetchStoriesResults.addOk({
        '1': [story('a')],
      });
      await h.go(CheckScope.stories);
      final after = (await h.targets.getById(t.id))!;
      expect(after.lastStoriesCheckAt, h.clock.now());
      expect(after.lastNewStoryAt, h.clock.now());
    });
  });

  group('AC3 posts', () {
    test('stores new posts, advances watermark to the max of all', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addOk([
        post('a', 10),
        post('pinned', 99),
        post('older', -5), // before the watermark: ignored
      ]);
      final r = await h.go(CheckScope.posts);
      expect(r.newContentIds, hasLength(2));
      expect(
        (await h.targets.getById(t.id))!.postsWatermarkAt,
        s.t0.add(const Duration(minutes: 99)),
      );
      expect(
        h.platform.callsTo('fetchNewPosts').single.args[1],
        s.t0,
      );
    });

    test('FR-67 reels follow trackReels, others follow trackPosts', () async {
      final a = await h.add('1', reels: false);
      final b = await h.add('2', posts: false);
      h.platform.fetchNewPostsResults
        ..addOk([
          post('p1', 1),
          post('r1', 2, type: PostType.reel),
        ])
        ..addOk([
          post('p2', 1),
          post('r2', 2, type: PostType.reel),
        ]);
      await h.go(CheckScope.posts);
      Future<Set<String>> ids(Target t) async => {
        for (final c in await h.content.listByTarget(t.id)) c.content.remoteId,
      };
      expect(await ids(a), {'p1'});
      expect(await ids(b), {'r2'});
      // the watermark still follows the filtered reel
      expect(
        (await h.targets.getById(a.id))!.postsWatermarkAt,
        s.t0.add(const Duration(minutes: 2)),
      );
    });

    test('unique key: a repeated post is not stored twice', () async {
      await h.add('1');
      h.platform.fetchNewPostsResults
        ..addOk([post('a', 5)])
        ..addOk([post('a', 5)]);
      await h.go(CheckScope.posts);
      // second run sees the same post again (e.g. watermark lost)
      final t = (await h.targets.listActive(CheckScope.posts)).single;
      await h.targets.update(t.copyWith(postsWatermarkAt: s.t0));
      final r = await h.go(CheckScope.posts);
      expect(r.newContentIds, isEmpty);
      expect(await h.content.listByTarget(t.id), hasLength(1));
    });

    test('watermark does not advance after a failed call', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const NetworkFailure());
      await h.go(CheckScope.posts);
      final after = (await h.targets.getById(t.id))!;
      expect(after.postsWatermarkAt, s.t0);
    });
  });

  group('AC4 target status', () {
    test('EC-3 TargetNotVisible from posts -> NOT_VISIBLE', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const TargetNotVisible());
      await h.go(CheckScope.posts);
      final after = (await h.targets.getById(t.id))!;
      expect(after.status, TargetStatus.notVisible);
      expect(await h.eventsOf(ActivityType.targetStatus), hasLength(1));
    });

    test('EC-3 private and no longer followed (daily refresh)', () async {
      final t = await h.add('1', lastPosts: s.t0);
      h.platform.fetchNewPostsResults.addOk([]);
      h.platform.refreshUserResults.addOk(
        ruser('1', 'u1', priv: true, followed: false),
      );
      await h.go(CheckScope.posts);
      expect(
        (await h.targets.getById(t.id))!.status,
        TargetStatus.notVisible,
      );
    });

    test('EC-4 blocked -> NOT_VISIBLE', () async {
      final t = await h.add('1', lastPosts: s.t0);
      h.platform.fetchNewPostsResults.addOk([]);
      h.platform.refreshUserResults.addOk(ruser('1', 'u1', blocked: true));
      await h.go(CheckScope.posts);
      final after = (await h.targets.getById(t.id))!;
      expect(after.status, TargetStatus.notVisible);
      expect(after.statusReason, 'blocked');
    });

    test('EC-5 rename refreshes the username, keeps tracking', () async {
      final t = await h.add('1', lastPosts: s.t0);
      h.platform.fetchNewPostsResults.addOk([]);
      h.platform.refreshUserResults.addOk(ruser('1', 'new_name'));
      await h.go(CheckScope.posts);
      final after = (await h.targets.getById(t.id))!;
      expect(after.username, 'new_name');
      expect(after.status, TargetStatus.active);
    });

    test('refresh happens once per UTC day', () async {
      await h.add('1');
      h.platform.fetchNewPostsResults.fallback = const Ok([]);
      await h.go(CheckScope.posts);
      expect(h.platform.callsTo('refreshUser'), isEmpty);
    });

    test('EC-6 TargetNotFound -> UNAVAILABLE', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const TargetNotFound());
      await h.go(CheckScope.posts);
      expect(
        (await h.targets.getById(t.id))!.status,
        TargetStatus.unavailable,
      );
    });

    test('stories batch with TargetNotVisible is retried one by one', () async {
      final a = await h.add('1', posts: false, reels: false);
      final b = await h.add('2', posts: false, reels: false);
      h.platform.fetchStoriesResults
        ..addFailure(const TargetNotVisible())
        ..addOk({
          '1': [story('x')],
        })
        ..addFailure(const TargetNotVisible());
      h.platform.refreshUserResults.fallback = Ok(ruser('0', 'x'));
      final r = await h.go(CheckScope.stories);
      expect(r.newContentIds, hasLength(1));
      expect((await h.targets.getById(a.id))!.status, TargetStatus.active);
      expect(
        (await h.targets.getById(b.id))!.status,
        TargetStatus.notVisible,
      );
    });

    test('busy governor (NetworkFailure) changes no status', () async {
      final t = await h.add('1');
      h.platform.fetchNewPostsResults.addFailure(const NetworkFailure());
      final r = await h.go(CheckScope.posts);
      expect((await h.targets.getById(t.id))!.status, TargetStatus.active);
      expect(r.result, CheckResult.failed);
      expect(r.run.errorCode, 'network');
    });
  });

  group('AC5 round-robin carry-over', () {
    test('rate limit stops the run; leftovers go first next time', () async {
      final a = await h.add('1', lastPosts: s.t0);
      final b = await h.add('2', lastPosts: s.t0.add(const Duration(hours: 1)));
      final c = await h.add('3', lastPosts: s.t0.add(const Duration(hours: 2)));
      h.platform.fetchNewPostsResults
        ..addOk([])
        ..addFailure(const RateLimited(Duration(minutes: 15)));
      h.platform.refreshUserResults.fallback = Ok(ruser('1', 'u1'));
      final r = await h.go(CheckScope.posts);
      expect(r.result, CheckResult.rateLimited);
      expect(h.platform.callsTo('fetchNewPosts'), hasLength(2));
      expect(await h.eventsOf(ActivityType.rateLimited), hasLength(1));

      h.clock.advance(const Duration(hours: 3));
      h.platform.fetchNewPostsResults.fallback = const Ok([]);
      h.platform.refreshUserResults.fallback = Ok(ruser('1', 'u1'));
      await h.go(CheckScope.posts);
      final order = [
        for (final call in h.platform.callsTo('fetchNewPosts')) call.args.first,
      ].skip(2).toList();
      // b (rate limited, unstamped) and c (never reached) before a (stamped)
      expect(order, [b.remoteUserId, c.remoteUserId, a.remoteUserId]);
    });

    test('deadline leaves the rest for the next run as PARTIAL', () async {
      await h.add('1');
      await h.add('2');
      h.platform.fetchNewPostsResults.fallback = const Ok([]);
      final r = await h.go(
        CheckScope.posts,
        deadline: h.clock.now().subtract(const Duration(seconds: 1)),
      );
      expect(r.result, CheckResult.partial);
      expect(h.platform.callsTo('fetchNewPosts'), isEmpty);
    });
  });

  group('AC6 check_run and activity', () {
    test('writes scope, mode DIRECT and CHECK_DONE', () async {
      await h.add('1');
      h.platform.fetchStoriesResults.addOk({
        '1': [story('a')],
      });
      final r = await h.go(
        CheckScope.stories,
        trigger: CheckTrigger.manualAll,
      );
      final row = h.checkRuns.runs.single;
      expect(row.scope, CheckScope.stories);
      expect(row.trigger, CheckTrigger.manualAll);
      expect(row.mode, ExtractionMode.direct);
      expect(row.result, CheckResult.ok);
      expect(row.targetsChecked, 1);
      expect(row.newItems, 1);
      expect(r.run, row);
      final done = await h.eventsOf(ActivityType.checkDone);
      expect(done.single.count, 1);
      expect(done.single.checkRunId, row.id);
    });

    test('page-mode signals set mode PAGE and PAGE_MODE_USED', () async {
      await h.add('1');
      h.platform.fetchStoriesResults.addOk({});
      h.signals.duringNextCall(pageUses: 2);
      await h.go(CheckScope.stories);
      expect(h.checkRuns.runs.single.mode, ExtractionMode.page);
      expect(await h.eventsOf(ActivityType.pageModeUsed), hasLength(1));
    });

    test('policy: periodic is direct-only unless allowed', () async {
      await h.add('1');
      h.platform.fetchStoriesResults.fallback = const Ok({});
      await h.go(CheckScope.stories);
      await h.go(CheckScope.stories, trigger: CheckTrigger.manualAll);
      await h.settings.update(
        (c) => const AppSettings(pageModeInBackground: true),
      );
      await h.go(CheckScope.stories);
      expect(
        [for (final c in h.platform.callsTo('fetchStories')) c.args[1]],
        [
          ExtractionPolicy.directOnly,
          ExtractionPolicy.directThenPage,
          ExtractionPolicy.directThenPage,
        ],
      );
    });

    test('EC-14 skipped malformed edges raise PLATFORM_CHANGED', () async {
      await h.add('1');
      h.platform.fetchNewPostsResults.addOk([post('a', 1)]);
      h.signals.duringNextCall(skipped: 3);
      await h.go(CheckScope.posts);
      final ev = await h.eventsOf(ActivityType.platformChanged);
      expect(ev.single.count, 3);
      expect(ev.single.severity, Severity.warn);
    });

    test('SchemaChanged records PLATFORM_CHANGED once', () async {
      await h.add('1');
      await h.add('2');
      h.platform.fetchNewPostsResults.fallback = const Err(
        SchemaChanged('timeline'),
      );
      final r = await h.go(CheckScope.posts);
      expect(r.run.errorCode, 'schema_changed');
      expect(await h.eventsOf(ActivityType.platformChanged), hasLength(1));
    });
  });

  group('AC7 isolation', () {
    test('one failing target does not abort the run', () async {
      await h.add('1');
      final b = await h.add('2');
      h.platform.fetchNewPostsResults
        ..addFailure(const UnknownFailure(500, 'boom'))
        ..addOk([post('a', 3)]);
      final r = await h.go(CheckScope.posts);
      expect(r.result, CheckResult.partial);
      expect(r.run.targetsChecked, 1);
      expect(await h.content.listByTarget(b.id), hasLength(1));
    });

    test('a throwing platform call is contained', () async {
      await h.add('1');
      await h.add('2');
      // no scripted result for the first call makes the fake throw
      h.platform.fetchNewPostsResults.addOk([post('a', 3)]);
      final r = await h.go(CheckScope.posts);
      expect(r.result, CheckResult.partial);
      expect(h.checkRuns.runs.single.isFinished, isTrue);
    });
  });

  group('rotation after SchemaChanged', () {
    test(
      'posts: failing targets go to the back, the rest get a turn',
      () async {
        final old = s.t0.add(const Duration(hours: 1));
        for (final id in ['1', '2', '3', '4']) {
          await h.add(id, lastPosts: old);
        }
        h.platform.fetchNewPostsResults.fallback = const Err(
          SchemaChanged('timeline'),
        );
        final r = await h.go(CheckScope.posts);
        expect(r.run.errorCode, 'schema_changed');

        final order = await h.targets.listActive(CheckScope.posts);
        expect(order.first.remoteUserId, '4');
        // The watermark did not move: nothing is skipped.
        for (final t in order) {
          expect(t.postsWatermarkAt, isNot(h.clock.now()));
        }
      },
    );

    test('stories: a single failing target is rotated', () async {
      final old = s.t0.add(const Duration(hours: 1));
      final a = await h.add('1', lastStories: old);
      h.platform.fetchStoriesResults.fallback = const Err(
        SchemaChanged('stories'),
      );
      await h.go(CheckScope.stories);
      final t = await h.targets.getById(a.id);
      expect(t!.lastStoriesCheckAt, h.clock.now());
    });

    test(
      'stories: a batch cannot say whose fault it is, none rotated',
      () async {
        final old = s.t0.add(const Duration(hours: 1));
        final a = await h.add('1', lastStories: old);
        await h.add('2', lastStories: old);
        h.platform.fetchStoriesResults.fallback = const Err(
          SchemaChanged('stories'),
        );
        await h.go(CheckScope.stories);
        expect((await h.targets.getById(a.id))!.lastStoriesCheckAt, old);
      },
    );
  });
}
