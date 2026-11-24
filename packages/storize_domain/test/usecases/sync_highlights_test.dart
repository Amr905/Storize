import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

final DateTime now = DateTime.utc(2026, 11, 24, 12);
DateTime daysAgo(int d) => now.subtract(Duration(days: d));

RemoteContent item(String id, DateTime at, {int slides = 1}) => RemoteContent(
  remoteId: id,
  kind: ContentKind.story,
  postedAt: at,
  slides: [
    for (var i = 0; i < slides; i++)
      RemoteMedia(
        index: i,
        type: MediaType.photo,
        url: 'https://example.invalid/h/$id',
        width: 10,
        height: 10,
      ),
  ],
);

String dn({
  required String username,
  required DateTime postedAt,
  required String remoteId,
  required String ext,
  int? slideIndex,
}) => '${username}_$remoteId.$ext';

String relDir(String username) => username.replaceAll(' ', '_');

void main() {
  late FakeContentPlatform platform;
  late FakeTargetRepo targets;
  late FakeAccountRepo accounts;
  late FakeClock clock;
  late FakeContentRepo content;
  late SyncHighlights sync;
  late Target t;

  setUp(() async {
    platform = FakeContentPlatform();
    targets = FakeTargetRepo();
    accounts = FakeAccountRepo();
    clock = FakeClock(now);
    content = FakeContentRepo(targets: targets);
    sync = SyncHighlights(
      platform: platform,
      targets: targets,
      content: content,
      accounts: accounts,
      settings: FakeSettingsRepo(),
      clock: clock,
    );
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
    t = await targets.insert(s.target().copyWith(highlightsEnabled: true));
  });

  Future<List<Content>> stored() async => [
    for (final c in await content.listByTarget(t.id)) c.content,
  ];

  group('SyncHighlights', () {
    test('new highlights: items stored as highlight with extras', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
          RemoteHighlight(id: 'h2', title: 'Food', latestItemAt: daysAgo(3)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(5)), item('b', daysAgo(2))],
          'h2': [item('c', daysAgo(3))],
        });
      final r = await sync.run(t.id);
      expect(r.outcome, HighlightsOutcome.synced);
      expect(r.newContentIds, hasLength(3));
      final all = await stored();
      expect(all.every((c) => c.kind == ContentKind.highlight), isTrue);
      final a = all.firstWhere((c) => c.remoteId == 'a');
      expect(a.extras, {
        HighlightExtras.id: 'h1',
        HighlightExtras.title: 'Trip',
        HighlightExtras.order: 0,
      });
      final c = all.firstWhere((c) => c.remoteId == 'c');
      expect(c.extras[HighlightExtras.order], 1);
      expect(c.status, ContentStatus.pending);
      expect(platform.callsTo('fetchHighlightItems').single.args.first, [
        'h1',
        'h2',
      ]);
    });

    test('unchanged highlights are not fetched again', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(5)), item('b', daysAgo(2))],
        });
      await sync.run(t.id);
      platform.fetchHighlightsResults.addOk([
        RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
      ]);
      final r = await sync.run(t.id);
      expect(r.newContentIds, isEmpty);
      expect(platform.callsTo('fetchHighlightItems'), hasLength(1));
    });

    test('a changed highlight fetches items and stores only the new', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
          RemoteHighlight(id: 'h2', title: 'Food', latestItemAt: daysAgo(3)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(2))],
          'h2': [item('c', daysAgo(3))],
        });
      await sync.run(t.id);
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: now),
          RemoteHighlight(id: 'h2', title: 'Food', latestItemAt: daysAgo(3)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(2)), item('d', now)],
        });
      final r = await sync.run(t.id);
      expect(platform.callsTo('fetchHighlightItems').last.args.first, ['h1']);
      expect(r.newContentIds, hasLength(1));
      expect(
        (await stored()).map((c) => c.remoteId),
        containsAll(['a', 'c', 'd']),
      );
      expect(await stored(), hasLength(3));
    });

    test('same item twice in one reply is stored once', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
          RemoteHighlight(id: 'h2', title: 'More', latestItemAt: daysAgo(2)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(2))],
          'h2': [item('a', daysAgo(2))],
        });
      await sync.run(t.id);
      expect(await stored(), hasLength(1));
    });

    test('highlights off or paused target: no call', () async {
      final off = await targets.insert(
        s.target(remoteUserId: '2', username: 'off'),
      );
      expect((await sync.run(off.id)).outcome, HighlightsOutcome.skipped);
      await targets.update(
        (await targets.getById(t.id))!.copyWith(status: TargetStatus.paused),
      );
      expect((await sync.run(t.id)).outcome, HighlightsOutcome.skipped);
      expect(platform.calls, isEmpty);
    });

    test('a rate limit on the tray stores nothing', () async {
      platform.fetchHighlightsResults.addFailure(
        const RateLimited(Duration(minutes: 1)),
      );
      final r = await sync.run(t.id);
      expect(r.outcome, HighlightsOutcome.rateLimited);
      expect(await stored(), isEmpty);
    });

    test('a failure on the items keeps the next run able to retry', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
        ])
        ..fetchHighlightItemsResults.addFailure(const NetworkFailure());
      expect((await sync.run(t.id)).outcome, HighlightsOutcome.network);
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(id: 'h1', title: 'Trip', latestItemAt: daysAgo(2)),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(2))],
        });
      expect((await sync.run(t.id)).newContentIds, hasLength(1));
    });

    test('session failure flags the account', () async {
      platform.fetchHighlightsResults.addFailure(
        const SessionInvalid(SessionReason.challenge),
      );
      final r = await sync.run(t.id);
      expect(r.outcome, HighlightsOutcome.sessionInvalid);
      expect(r.sessionStatus, AccountStatus.needsRelogin);
    });

    test('inactive session: no call', () async {
      final a = (await accounts.getActive())!;
      await accounts.setStatus(a.id, AccountStatus.needsRelogin);
      expect((await sync.run(t.id)).outcome, HighlightsOutcome.sessionInactive);
      expect(platform.calls, isEmpty);
    });

    test('runDue syncs only targets with highlights on', () async {
      await targets.insert(s.target(remoteUserId: '2', username: 'off'));
      platform.fetchHighlightsResults.addOk(const []);
      await sync.runDue();
      expect(platform.callsTo('fetchHighlights'), hasLength(1));
      expect(platform.callsTo('fetchHighlights').single.args.first, '100');
    });
  });

  group('gallery path', () {
    test('Highlights/<sanitized title> under the username', () async {
      platform
        ..fetchHighlightsResults.addOk([
          RemoteHighlight(
            id: 'h1',
            title: 'Trip: 2026/Rome?',
            latestItemAt: daysAgo(2),
          ),
        ])
        ..fetchHighlightItemsResults.addOk({
          'h1': [item('a', daysAgo(2))],
        });
      await sync.run(t.id);

      final cache = FakeMediaCache();
      final gallery = FakeGalleryStore(cache: cache);
      platform.queueMedia(List<int>.filled(5, 7));
      final dl = DownloadPending(
        content: content,
        targets: targets,
        activity: FakeActivityRepo(clock),
        platform: platform,
        cache: cache,
        gallery: gallery,
        storage: FakeStorageInfo(),
        clock: clock,
        leases: FakeGovernorLeaseRepo(clock),
        displayName: dn,
        // The real builder sanitizes one segment; this stand-in mimics it.
        relativeDir: (u) => u.replaceAll(RegExp('[:/?]'), '_'),
      );
      final r = await dl.run();
      expect(r.totalFiles, 1);
      expect(
        gallery.files.single.relativePath,
        'alice/Highlights/Trip_ 2026_Rome_',
      );
    });
  });
}
