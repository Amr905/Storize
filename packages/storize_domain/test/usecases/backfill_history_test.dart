import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

final DateTime now = DateTime.utc(2026, 11, 24, 12);

RemoteContent post(
  String id,
  DateTime at, {
  PostType type = PostType.photo,
  bool pinned = false,
}) => RemoteContent(
  remoteId: id,
  kind: ContentKind.post,
  shortcode: 'sc$id',
  postType: type,
  postedAt: at,
  extras: {if (pinned) 'pinned': true},
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

DateTime daysAgo(int d) => now.subtract(Duration(days: d));

final class H {
  final platform = FakeContentPlatform();
  final targets = FakeTargetRepo();
  final accounts = FakeAccountRepo();
  final settings = FakeSettingsRepo();
  final clock = FakeClock(now);
  late final FakeContentRepo content = FakeContentRepo(targets: targets);
  late final BackfillHistory backfill = BackfillHistory(
    platform: platform,
    targets: targets,
    content: content,
    accounts: accounts,
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

  Future<Target> add({
    bool posts = true,
    bool reels = true,
    String remoteUserId = '100',
    String username = 'alice',
  }) => targets.insert(
    s
        .target(remoteUserId: remoteUserId, username: username)
        .copyWith(trackPosts: posts, trackReels: reels),
  );

  Future<Target> get(int id) async => (await targets.getById(id))!;

  Future<int> stored(int id) async => (await content.listByTarget(id)).length;
}

void main() {
  late H h;
  late Target t;

  setUp(() async {
    h = H();
    await h.login();
    t = await h.add();
  });

  group('start, pause, resume, cancel', () {
    test('start sets the range and a running progress', () async {
      await h.backfill.start(t.id, HistoryRange.days7);
      final r = await h.get(t.id);
      expect(r.historyRange, HistoryRange.days7);
      expect(r.historyProgress?.state, HistoryState.running);
      expect(r.historyProgress?.fetched, 0);
      expect(r.historyProgress?.cursor, isNull);
    });

    test('since needs a past date', () async {
      await expectLater(
        h.backfill.start(t.id, HistoryRange.since),
        throwsArgumentError,
      );
      await expectLater(
        h.backfill.start(
          t.id,
          HistoryRange.since,
          since: now.add(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      await h.backfill.start(t.id, HistoryRange.since, since: daysAgo(3));
      expect((await h.get(t.id)).historySince, daysAgo(3));
    });

    test('pause stops steps; resume continues from the cursor', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
      );
      await h.backfill.step(t.id);
      await h.backfill.pause(t.id);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.paused);
      final skipped = await h.backfill.step(t.id);
      expect(skipped.outcome, BackfillOutcome.skipped);
      expect(h.platform.callsTo('fetchPostPage'), hasLength(1));

      await h.backfill.resume(t.id);
      h.platform.fetchPostPageResults.addOk(PostPage(items: const []));
      await h.backfill.step(t.id);
      expect(h.platform.callsTo('fetchPostPage').last.args[1], 'c1');
    });

    test('cancel sets none and idle, keeps stored posts', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
      );
      await h.backfill.step(t.id);
      await h.backfill.cancel(t.id);
      final r = await h.get(t.id);
      expect(r.historyRange, HistoryRange.none);
      expect(r.historyProgress?.state, HistoryState.idle);
      expect(r.historyProgress?.cursor, isNull);
      expect(await h.stored(t.id), 1);
      expect(
        (await h.backfill.step(t.id)).outcome,
        BackfillOutcome.skipped,
      );
    });

    test('start with none cancels', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      await h.backfill.start(t.id, HistoryRange.none);
      expect((await h.get(t.id)).historyRange, HistoryRange.none);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.idle);
    });
  });

  group('step', () {
    test('queues the page and saves cursor, count and oldest', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(
          items: [post('1', daysAgo(1)), post('2', daysAgo(2))],
          nextCursor: 'c1',
        ),
      );
      final r = await h.backfill.step(t.id);
      expect(r.outcome, BackfillOutcome.progressed);
      expect(r.newContentIds, hasLength(2));
      final p = (await h.get(t.id)).historyProgress!;
      expect(p.state, HistoryState.running);
      expect(p.cursor, 'c1');
      expect(p.fetched, 2);
      expect(p.oldestSeenAt, daysAgo(2));
      expect(h.platform.callsTo('fetchPostPage').single.args[1], isNull);
      for (final c in await h.content.listByTarget(t.id)) {
        expect(c.content.status, ContentStatus.pending);
        expect(c.media.single.status, MediaFileStatus.pending);
      }
    });

    test(
      'range cut-off: older items are not queued and it ends done',
      () async {
        await h.backfill.start(t.id, HistoryRange.days7);
        h.platform.fetchPostPageResults.addOk(
          PostPage(
            items: [
              post('1', daysAgo(1)),
              post('2', daysAgo(6)),
              post('3', daysAgo(8)),
              post('4', daysAgo(9)),
            ],
            nextCursor: 'c1',
          ),
        );
        final r = await h.backfill.step(t.id);
        expect(r.outcome, BackfillOutcome.done);
        expect(r.newContentIds, hasLength(2));
        final p = (await h.get(t.id)).historyProgress!;
        expect(p.state, HistoryState.done);
        expect(p.cursor, isNull);
        final ids = [
          for (final c in await h.content.listByTarget(t.id))
            c.content.remoteId,
        ];
        expect(ids, unorderedEquals(['1', '2']));
      },
    );

    test('no next cursor ends done', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(400))]),
      );
      expect((await h.backfill.step(t.id)).outcome, BackfillOutcome.done);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.done);
    });

    test('today range uses the start of the local day', () async {
      await h.backfill.start(t.id, HistoryRange.today);
      final l = now.toLocal();
      final midnight = DateTime(l.year, l.month, l.day).toUtc();
      h.platform.fetchPostPageResults.addOk(
        PostPage(
          items: [
            post('1', midnight.add(const Duration(minutes: 1))),
            post('2', midnight.subtract(const Duration(minutes: 1))),
          ],
          nextCursor: 'c',
        ),
      );
      final r = await h.backfill.step(t.id);
      expect(r.newContentIds, hasLength(1));
      expect(r.outcome, BackfillOutcome.done);
    });

    test('a pinned old post neither ends the range nor is queued', () async {
      await h.backfill.start(t.id, HistoryRange.days7);
      h.platform.fetchPostPageResults.addOk(
        PostPage(
          items: [
            post('pin', daysAgo(300), pinned: true),
            post('1', daysAgo(1)),
          ],
          nextCursor: 'c1',
        ),
      );
      final r = await h.backfill.step(t.id);
      expect(r.outcome, BackfillOutcome.progressed);
      expect(r.newContentIds, hasLength(1));
      expect((await h.get(t.id)).historyProgress?.oldestSeenAt, daysAgo(1));
    });

    test('respects the Posts and Reels toggles', () async {
      final noReels = await h.add(
        reels: false,
        remoteUserId: '200',
        username: 'bob',
      );
      await h.backfill.start(noReels.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(
          items: [
            post('p', daysAgo(1)),
            post('r', daysAgo(2), type: PostType.reel),
          ],
        ),
      );
      await h.backfill.step(noReels.id);
      expect(
        [
          for (final c in await h.content.listByTarget(noReels.id))
            c.content.remoteId,
        ],
        ['p'],
      );

      final noPosts = await h.add(
        posts: false,
        remoteUserId: '300',
        username: 'cy',
      );
      await h.backfill.start(noPosts.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(
          items: [
            post('p', daysAgo(1)),
            post('r', daysAgo(2), type: PostType.reel),
          ],
        ),
      );
      await h.backfill.step(noPosts.id);
      expect(
        [
          for (final c in await h.content.listByTarget(noPosts.id))
            c.content.remoteId,
        ],
        ['r'],
      );
    });

    test(
      'no duplicates: posts the checks stored already are skipped',
      () async {
        await h.backfill.start(t.id, HistoryRange.all);
        final page = PostPage(
          items: [post('1', daysAgo(1)), post('2', daysAgo(2))],
          nextCursor: 'c1',
        );
        h.platform.fetchPostPageResults
          ..addOk(page)
          ..addOk(page);
        await h.backfill.step(t.id);
        // The same page again (for example after a kill before the cursor).
        final again = await h.backfill.step(t.id);
        expect(again.newContentIds, isEmpty);
        expect(await h.stored(t.id), 2);
      },
    );

    test('a rate limit keeps running and resumes at the same cursor', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults
        ..addOk(
          PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
        )
        ..addFailure(const RateLimited(Duration(minutes: 5)))
        ..addOk(PostPage(items: [post('2', daysAgo(2))]));
      await h.backfill.step(t.id);
      final limited = await h.backfill.step(t.id);
      expect(limited.outcome, BackfillOutcome.rateLimited);
      expect(limited.retryAfter, const Duration(minutes: 5));
      final p = (await h.get(t.id)).historyProgress!;
      expect(p.state, HistoryState.running);
      expect(p.cursor, 'c1');
      expect(p.fetched, 1);

      final done = await h.backfill.step(t.id);
      expect(done.outcome, BackfillOutcome.done);
      expect(h.platform.callsTo('fetchPostPage').last.args[1], 'c1');
      expect(await h.stored(t.id), 2);
    });

    test('a session failure flags the account and keeps running', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addFailure(
        const SessionInvalid(SessionReason.loginRequired),
      );
      final r = await h.backfill.step(t.id);
      expect(r.outcome, BackfillOutcome.sessionInvalid);
      expect(r.sessionStatus, AccountStatus.needsRelogin);
      expect(
        (await h.accounts.getActive())?.status,
        isNot(AccountStatus.active),
      );
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.running);
      expect(await h.stored(t.id), 0);
    });

    test('an inactive session makes no call', () async {
      final h2 = H();
      await h2.login(AccountStatus.needsRelogin);
      final t2 = await h2.add();
      await h2.backfill.start(t2.id, HistoryRange.all);
      final r = await h2.backfill.step(t2.id);
      expect(r.outcome, BackfillOutcome.sessionInactive);
      expect(h2.platform.calls, isEmpty);
    });

    test('a network failure keeps running', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addFailure(const NetworkFailure());
      final r = await h.backfill.step(t.id);
      expect(r.outcome, BackfillOutcome.network);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.running);
    });

    test(
      'T-047: a missing doc_id, tokens or page mode defer, not fail',
      () async {
        await h.backfill.start(t.id, HistoryRange.all);
        for (final f in const <Failure>[
          SchemaChanged('doc_id:PolarisProfilePostsQuery'),
          SchemaChanged('page_tokens'),
          SchemaChanged('providers'),
          UnknownFailure(null, 'page_mode_background_disabled'),
        ]) {
          h.platform.fetchPostPageResults.addFailure(f);
          final r = await h.backfill.step(t.id);
          expect(r.outcome, BackfillOutcome.deferred);
          expect(r.stillRunning, isTrue);
          expect(
            (await h.get(t.id)).historyProgress?.state,
            HistoryState.running,
          );
        }
        // The next run retries and can finish.
        h.platform.fetchPostPageResults.addOk(
          PostPage(items: [post('1', daysAgo(1))]),
        );
        expect((await h.backfill.step(t.id)).outcome, BackfillOutcome.done);
      },
    );

    test(
      'T-047: a real response-shape change, not found, not visible fail',
      () async {
        for (final f in const <Failure>[
          SchemaChanged('data.user'),
          TargetNotFound(),
          TargetNotVisible(),
        ]) {
          await h.backfill.start(t.id, HistoryRange.all);
          h.platform.fetchPostPageResults.addFailure(f);
          expect((await h.backfill.step(t.id)).outcome, BackfillOutcome.failed);
          expect(
            (await h.get(t.id)).historyProgress?.state,
            HistoryState.failed,
          );
        }
      },
    );

    test('QA T-047: deferred keeps cursor and fetched; runDue is one call '
        'per target and not a failure', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
      );
      await h.backfill.step(t.id);
      final before = (await h.get(t.id)).historyProgress!;
      h.platform.fetchPostPageResults.addFailure(
        const SchemaChanged('page_tokens'),
      );
      final pass = await h.backfill.runDue();
      final after = (await h.get(t.id)).historyProgress!;
      expect(after.state, HistoryState.running);
      expect(after.cursor, before.cursor);
      expect(after.fetched, before.fetched);
      expect(pass.running, 1);
      expect(pass.deferred, isTrue);
      expect(pass.network, isFalse);
      expect(pass.rateLimited, isFalse);
      expect(
        h.platform.calls.where((c) => c.method == 'fetchPostPage'),
        hasLength(2),
      );
    });

    test('not_implemented and other hard failures end as failed', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addFailure(
        const UnknownFailure(null, 'not_implemented'),
      );
      expect((await h.backfill.step(t.id)).outcome, BackfillOutcome.failed);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.failed);
      // Resume retries.
      await h.backfill.resume(t.id);
      expect((await h.get(t.id)).historyProgress?.state, HistoryState.running);
    });

    test('a pause during the call is kept', () async {
      await h.backfill.start(t.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
      );
      // Pause lands while the fetch is in flight (before the page is stored).
      final pending = h.backfill.step(t.id);
      await h.backfill.pause(t.id);
      await pending;
      final p = (await h.get(t.id)).historyProgress!;
      expect(p.state, HistoryState.paused);
      expect(p.cursor, 'c1');
    });
  });

  group('runDue', () {
    test('one page per running target; paused and idle are left', () async {
      final b = await h.add(remoteUserId: '200', username: 'bob');
      final c = await h.add(remoteUserId: '300', username: 'cy');
      await h.backfill.start(t.id, HistoryRange.all);
      await h.backfill.start(b.id, HistoryRange.all);
      await h.backfill.pause(b.id);
      expect(c.historyProgress, isNull);
      h.platform.fetchPostPageResults.addOk(
        PostPage(items: [post('1', daysAgo(1))], nextCursor: 'c1'),
      );
      final r = await h.backfill.runDue();
      expect(h.platform.callsTo('fetchPostPage'), hasLength(1));
      expect(r.running, 1);
      expect(r.newContentIds, hasLength(1));
    });

    test('stops at a rate limit', () async {
      final b = await h.add(remoteUserId: '200', username: 'bob');
      await h.backfill.start(t.id, HistoryRange.all);
      await h.backfill.start(b.id, HistoryRange.all);
      h.platform.fetchPostPageResults.addFailure(
        const RateLimited(Duration(minutes: 1)),
      );
      final r = await h.backfill.runDue();
      expect(r.rateLimited, isTrue);
      expect(r.running, 2);
      expect(h.platform.callsTo('fetchPostPage'), hasLength(1));
    });
  });
}
