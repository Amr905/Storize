import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

RemoteContent _post(String id, DateTime at) => RemoteContent(
  remoteId: id,
  kind: ContentKind.post,
  shortcode: 'sc$id',
  postType: PostType.photo,
  postedAt: at,
  slides: const [
    RemoteMedia(
      index: 0,
      type: MediaType.photo,
      url: 'https://example.invalid/p',
      width: 1,
      height: 1,
    ),
  ],
);

void main() {
  // Run with TZ=UTC and with TZ=Africa/Cairo / America/Los_Angeles: the
  // expectations are derived from the device-local day.
  group('range cut-off (QA)', () {
    late FakeContentPlatform platform;
    late FakeTargetRepo targets;
    late FakeContentRepo content;
    late FakeClock clock;
    late BackfillHistory backfill;
    late Target t;

    Future<void> setUpFor(DateTime now) async {
      platform = FakeContentPlatform();
      targets = FakeTargetRepo();
      content = FakeContentRepo(targets: targets);
      clock = FakeClock(now);
      final accounts = FakeAccountRepo();
      await accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'me',
          username: 'me',
          status: AccountStatus.active,
          connectedAt: s.t0,
        ),
      );
      backfill = BackfillHistory(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: clock,
      );
      t = await targets.insert(s.target());
    }

    Future<Set<String>> run(
      HistoryRange range,
      List<RemoteContent> items, {
      DateTime? since,
    }) async {
      await backfill.start(t.id, range, since: since);
      platform.fetchPostPageResults.addOk(
        PostPage(items: items, nextCursor: 'more'),
      );
      await backfill.step(t.id);
      return {
        for (final c in await content.listByTarget(t.id)) c.content.remoteId,
      };
    }

    test('today: the local midnight is the inclusive boundary', () async {
      // 22:30 UTC is already the next day in zones east of UTC+1:30.
      final now = DateTime.utc(2026, 11, 24, 22, 30);
      await setUpFor(now);
      final l = now.toLocal();
      final midnight = DateTime(l.year, l.month, l.day).toUtc();
      final got = await run(HistoryRange.today, [
        _post('in', midnight),
        _post('out', midnight.subtract(const Duration(seconds: 1))),
      ]);
      expect(got, {'in'});
      expect(
        (await targets.getById(t.id))!.historyProgress?.state,
        HistoryState.done,
      );
    });

    test('days7 and days30 count back from now, start inclusive', () async {
      final now = DateTime.utc(2026, 11, 24, 12);
      await setUpFor(now);
      var got = await run(HistoryRange.days7, [
        _post('a', now.subtract(const Duration(days: 7))),
        _post('b', now.subtract(const Duration(days: 7, seconds: 1))),
      ]);
      expect(got, {'a'});
      await setUpFor(now);
      got = await run(HistoryRange.days30, [
        _post('a', now.subtract(const Duration(days: 30))),
        _post('b', now.subtract(const Duration(days: 30, seconds: 1))),
      ]);
      expect(got, {'a'});
    });

    test('since: inclusive start, then done', () async {
      final now = DateTime.utc(2026, 11, 24, 12);
      await setUpFor(now);
      final since = DateTime.utc(2026, 6);
      final got = await run(HistoryRange.since, [
        _post('a', since),
        _post('b', since.subtract(const Duration(milliseconds: 1))),
      ], since: since);
      expect(got, {'a'});
      expect(
        (await targets.getById(t.id))!.historyProgress?.state,
        HistoryState.done,
      );
    });

    test('all: never stops on age; ends only on a null cursor', () async {
      final now = DateTime.utc(2026, 11, 24, 12);
      await setUpFor(now);
      final got = await run(HistoryRange.all, [
        _post('old', DateTime.utc(2010)),
      ]);
      expect(got, {'old'});
      expect(
        (await targets.getById(t.id))!.historyProgress?.state,
        HistoryState.running,
      );
      platform.fetchPostPageResults.addOk(PostPage(items: const []));
      final r = await backfill.step(t.id);
      expect(r.outcome, BackfillOutcome.done);
    });

    test('a cancel during the call keeps the cancel and stores nothing '
        'new in the progress', () async {
      final now = DateTime.utc(2026, 11, 24, 12);
      await setUpFor(now);
      await backfill.start(t.id, HistoryRange.all);
      platform.fetchPostPageResults.addOk(
        PostPage(items: [_post('1', now)], nextCursor: 'c'),
      );
      final f = backfill.step(t.id);
      await backfill.cancel(t.id);
      await f;
      final r = (await targets.getById(t.id))!;
      expect(r.historyRange, HistoryRange.none);
      expect(r.historyProgress?.state, HistoryState.idle);
    });
  });

  group('highlights (QA)', () {
    test('an unchanged tray with no dates is not refetched', () async {
      final platform = FakeContentPlatform();
      final targets = FakeTargetRepo();
      final content = FakeContentRepo(targets: targets);
      final accounts = FakeAccountRepo();
      await accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'me',
          username: 'me',
          status: AccountStatus.active,
          connectedAt: s.t0,
        ),
      );
      final sync = SyncHighlights(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: FakeClock(DateTime.utc(2026, 11, 24)),
      );
      final t = await targets.insert(
        s.target().copyWith(highlightsEnabled: true),
      );
      final at = DateTime.utc(2026, 11);
      platform
        ..fetchHighlightsResults.addOk([
          const RemoteHighlight(id: 'h', title: '../x'),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h': [
            RemoteContent(
              remoteId: 'i1',
              kind: ContentKind.story,
              postedAt: at,
              slides: _post('p', at).slides,
            ),
          ],
        })
        ..fetchHighlightsResults.addOk([
          const RemoteHighlight(id: 'h', title: '../x'),
        ]);
      await sync.run(t.id);
      await sync.run(t.id);
      expect(platform.callsTo('fetchHighlightItems'), hasLength(1));
      final all = await content.listByTarget(t.id);
      expect(all, hasLength(1));
      // The raw title is kept in extras; the folder is sanitized at download.
      expect(all.single.content.extras[HighlightExtras.title], '../x');
    });
  });
}
