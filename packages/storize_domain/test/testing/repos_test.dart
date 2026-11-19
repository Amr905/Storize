import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  group('FakeTargetRepo', () {
    late FakeTargetRepo repo;
    setUp(() => repo = FakeTargetRepo());

    test('insert assigns ids and finds by remote user id', () async {
      final a = await repo.insert(target(remoteUserId: '1'));
      final b = await repo.insert(target(remoteUserId: '2', username: 'bob'));
      expect(a.id, isNot(b.id));
      expect(await repo.getById(a.id), a);
      expect(
        await repo.getByRemoteUserId(PlatformId.instagram, '2'),
        b,
      );
      expect(await repo.getByRemoteUserId(PlatformId.instagram, '3'), isNull);
    });

    test('duplicate platform and remote user id is rejected (EC-16)', () async {
      await repo.insert(target(remoteUserId: '1'));
      await expectLater(
        repo.insert(target(remoteUserId: '1', username: 'renamed')),
        throwsA(isA<DuplicateEntityException>()),
      );
      expect(await repo.watchAll().first, hasLength(1));
    });

    test('watchAll emits on insert, update and delete', () async {
      final events = <List<String>>[];
      final sub = repo.watchAll().listen(
        (l) => events.add(l.map((t) => t.username).toList()),
      );
      await pumpEventQueue();
      final a = await repo.insert(target(remoteUserId: '1', username: 'zed'));
      await repo.insert(target(remoteUserId: '2', username: 'Amy'));
      await repo.update(a.copyWith(username: 'bob'));
      await repo.delete(a.id);
      await pumpEventQueue();
      await sub.cancel();
      expect(events, [
        <String>[],
        ['zed'],
        ['Amy', 'zed'],
        ['Amy', 'bob'],
        ['Amy'],
      ]);
    });

    test('watchById emits the row, then null after delete', () async {
      final a = await repo.insert(target());
      final events = <Target?>[];
      final sub = repo.watchById(a.id).listen(events.add);
      await pumpEventQueue();
      await repo.update(a.copyWith(note: 'n'));
      await repo.delete(a.id);
      await pumpEventQueue();
      await sub.cancel();
      expect(events, [a, a.copyWith(note: 'n'), null]);
    });

    test('update of a missing row throws', () async {
      await expectLater(repo.update(target(id: 99)), throwsStateError);
    });

    test('listActive filters by scope, status and flags', () async {
      final both = await repo.insert(target(remoteUserId: '1'));
      final storiesOnly = await repo.insert(
        target(remoteUserId: '2', trackPosts: false, trackReels: false),
      );
      final reelsOnly = await repo.insert(
        target(remoteUserId: '3', trackStories: false, trackPosts: false),
      );
      await repo.insert(target(remoteUserId: '4', status: TargetStatus.paused));
      expect(
        (await repo.listActive(CheckScope.stories)).map((t) => t.id),
        [both.id, storiesOnly.id],
      );
      expect(
        (await repo.listActive(CheckScope.posts)).map((t) => t.id),
        [both.id, reelsOnly.id],
      );
      expect(await repo.listActive(CheckScope.all), hasLength(3));
    });

    test('listActive orders least recently checked first (ADR-9)', () async {
      final late = await repo.insert(
        target(remoteUserId: '1', lastStoriesCheckAt: t0),
      );
      final never = await repo.insert(target(remoteUserId: '2'));
      final early = await repo.insert(
        target(
          remoteUserId: '3',
          lastStoriesCheckAt: t0.subtract(const Duration(hours: 1)),
        ),
      );
      expect(
        (await repo.listActive(CheckScope.stories)).map((t) => t.id),
        [never.id, early.id, late.id],
      );
    });
  });

  group('FakeContentRepo', () {
    late FakeTargetRepo targets;
    late FakeContentRepo repo;
    late int targetId;

    setUp(() async {
      targets = FakeTargetRepo();
      repo = FakeContentRepo(targets: targets);
      targetId = (await targets.insert(target())).id;
    });

    test('insertIfNew stores content with media and reports new', () async {
      final r = await repo.insertIfNew(
        content(targetId: targetId),
        [media(sizeBytes: 5)],
      );
      expect(r.isNew, isTrue);
      final stored = (await repo.getById(r.contentId))!;
      expect(stored.content.id, r.contentId);
      expect(stored.media.single.contentId, r.contentId);
      expect(stored.media.single.id, isNot(MediaFile.unsavedId));
    });

    test(
      'UNIQUE duplicate insert reports not new and writes nothing',
      () async {
        final first = await repo.insertIfNew(
          content(targetId: targetId),
          [media()],
        );
        final again = await repo.insertIfNew(
          content(targetId: targetId),
          [media(), media(slideIndex: 1)],
        );
        expect(again.isNew, isFalse);
        expect(again.contentId, first.contentId);
        expect((await repo.getById(first.contentId))!.media, hasLength(1));
        expect(await repo.pendingMedia(), hasLength(1));
      },
    );

    test('the same remote id as another kind or target is new', () async {
      final other = (await targets.insert(target(remoteUserId: '2'))).id;
      await repo.insertIfNew(content(targetId: targetId), [media()]);
      expect(
        (await repo.insertIfNew(
          content(targetId: targetId, kind: ContentKind.post),
          [media()],
        )).isNew,
        isTrue,
      );
      expect(
        (await repo.insertIfNew(content(targetId: other), [media()])).isNew,
        isTrue,
      );
    });

    test('duplicate slide indexes are rejected atomically', () async {
      await expectLater(
        repo.insertIfNew(content(targetId: targetId), [media(), media()]),
        throwsArgumentError,
      );
      expect(
        await repo.existingRemoteIds(targetId, ContentKind.story, ['r1']),
        isEmpty,
      );
    });

    test('existingRemoteIds returns only stored ids of that kind', () async {
      await repo.insertIfNew(content(targetId: targetId, remoteId: 'a'), [
        media(),
      ]);
      expect(
        await repo.existingRemoteIds(targetId, ContentKind.story, ['a', 'b']),
        {'a'},
      );
      expect(
        await repo.existingRemoteIds(targetId, ContentKind.post, ['a']),
        isEmpty,
      );
    });

    test(
      'watchLibrary emits on insert, update, mark viewed and delete',
      () async {
        final events = <List<bool>>[];
        final sub = repo
            .watchLibrary(ContentFilter())
            .listen(
              (l) => events.add(l.map((c) => c.content.viewed).toList()),
            );
        await pumpEventQueue();
        final r = await repo.insertIfNew(content(targetId: targetId), [
          media(),
        ]);
        final stored = (await repo.getById(r.contentId))!;
        await repo.updateContent(
          stored.content.copyWith(status: ContentStatus.done),
        );
        await repo.markViewed([r.contentId]);
        await repo.deleteByIds([r.contentId]);
        await pumpEventQueue();
        await sub.cancel();
        expect(events, [
          <bool>[],
          [false],
          [false],
          [true],
          <bool>[],
        ]);
      },
    );

    test('watchLibrary applies the filter and sorts newest first', () async {
      final other = (await targets.insert(target(remoteUserId: '2'))).id;
      Future<void> add(
        int t,
        String id,
        ContentKind k,
        int day, {
        MediaType type = MediaType.photo,
      }) => repo.insertIfNew(
        content(
          targetId: t,
          remoteId: id,
          kind: k,
          postedAt: DateTime.utc(2026, 11, day),
        ),
        [media(type: type)],
      );
      await add(targetId, 'old', ContentKind.story, 1);
      await add(targetId, 'new', ContentKind.story, 9);
      await add(other, 'post', ContentKind.post, 5, type: MediaType.video);
      List<String> ids(List<ContentWithMedia> l) =>
          l.map((c) => c.content.remoteId).toList();

      expect(ids(await repo.watchLibrary(ContentFilter()).first), [
        'new',
        'post',
        'old',
      ]);
      expect(
        ids(
          await repo.watchLibrary(ContentFilter(kind: ContentKind.story)).first,
        ),
        ['new', 'old'],
      );
      expect(
        ids(await repo.watchLibrary(ContentFilter(targetIds: {other})).first),
        ['post'],
      );
      expect(
        ids(
          await repo
              .watchLibrary(
                ContentFilter(
                  from: DateTime.utc(2026, 11, 2),
                  to: DateTime.utc(2026, 11, 9),
                ),
              )
              .first,
        ),
        ['post'],
      );
      expect(
        ids(
          await repo
              .watchLibrary(ContentFilter(mediaType: MediaType.video))
              .first,
        ),
        ['post'],
      );
    });

    test('library items carry slides in slide order', () async {
      await repo.insertIfNew(
        content(targetId: targetId, kind: ContentKind.post),
        [media(slideIndex: 2), media(), media(slideIndex: 1)],
      );
      final item = (await repo.watchLibrary(ContentFilter()).first).single;
      expect(item.media.map((m) => m.slideIndex), [0, 1, 2]);
    });

    test(
      'pendingMedia orders stories first, then detection, then slide',
      () async {
        Future<void> add(
          String id,
          ContentKind k,
          int hour,
          List<MediaFile> m,
        ) => repo.insertIfNew(
          content(
            targetId: targetId,
            remoteId: id,
            kind: k,
            detectedAt: DateTime.utc(2026, 11, 19, hour),
          ),
          m,
        );
        await add('post-early', ContentKind.post, 1, [media()]);
        await add('story-late', ContentKind.story, 9, [media()]);
        await add('story-early', ContentKind.story, 2, [media()]);
        await add('carousel', ContentKind.post, 3, [
          media(slideIndex: 1),
          media(),
        ]);
        final pending = await repo.pendingMedia();
        expect(
          pending.map((p) => '${p.content.remoteId}:${p.file.slideIndex}'),
          [
            'story-early:0',
            'story-late:0',
            'post-early:0',
            'carousel:0',
            'carousel:1',
          ],
        );
        expect(await repo.pendingMedia(limit: 2), hasLength(2));
      },
    );

    test(
      'updateMediaFile leaves pending; resetInterrupted undoes DOWNLOADING',
      () async {
        final r = await repo.insertIfNew(content(targetId: targetId), [
          media(),
        ]);
        final file = (await repo.getById(r.contentId))!.media.single;
        await repo.updateMediaFile(
          file.copyWith(status: MediaFileStatus.downloading),
        );
        expect(await repo.pendingMedia(), isEmpty);
        expect(await repo.resetInterruptedDownloads(), 1);
        expect(await repo.resetInterruptedDownloads(), 0);
        expect(await repo.pendingMedia(), hasLength(1));
        await expectLater(
          repo.updateMediaFile(file.copyWith(id: 999)),
          throwsStateError,
        );
      },
    );

    test(
      'deleteByIds removes content and media; unknown ids are ignored',
      () async {
        final r = await repo.insertIfNew(content(targetId: targetId), [
          media(),
        ]);
        await repo.deleteByIds([r.contentId, 12345]);
        expect(await repo.getById(r.contentId), isNull);
        expect(await repo.pendingMedia(), isEmpty);
      },
    );

    test('deleting a target cascades to content and media (BR-6)', () async {
      await repo.insertIfNew(content(targetId: targetId), [media()]);
      await targets.delete(targetId);
      expect(await repo.listByTarget(targetId), isEmpty);
      expect(await repo.pendingMedia(), isEmpty);
    });

    test('olderThan selects by postedAt, oldest first', () async {
      for (final d in [3, 1, 20]) {
        await repo.insertIfNew(
          content(
            targetId: targetId,
            remoteId: 'd$d',
            postedAt: DateTime.utc(2026, 11, d),
          ),
          [media()],
        );
      }
      final old = await repo.olderThan(DateTime.utc(2026, 11, 10));
      expect(old.map((c) => c.content.remoteId), ['d1', 'd3']);
    });

    test('storageBytesByTarget sums DONE files per target', () async {
      final other = (await targets.insert(target(remoteUserId: '2'))).id;
      await repo.insertIfNew(
        content(targetId: targetId, kind: ContentKind.post),
        [
          media(status: MediaFileStatus.done, sizeBytes: 10),
          media(slideIndex: 1, status: MediaFileStatus.done, sizeBytes: 5),
          media(slideIndex: 2, sizeBytes: 100),
        ],
      );
      await repo.insertIfNew(
        content(targetId: other),
        [media(status: MediaFileStatus.done, sizeBytes: 7)],
      );
      expect(await repo.storageBytesByTarget(), {targetId: 15, other: 7});
    });

    test('getByIds skips missing ids; listByTarget is newest first', () async {
      final a = await repo.insertIfNew(
        content(
          targetId: targetId,
          remoteId: 'a',
          postedAt: DateTime.utc(2026),
        ),
        [media()],
      );
      final b = await repo.insertIfNew(
        content(
          targetId: targetId,
          remoteId: 'b',
          postedAt: DateTime.utc(2027),
        ),
        [media()],
      );
      expect((await repo.getByIds([a.contentId, 77])).length, 1);
      expect(
        (await repo.listByTarget(targetId)).map((c) => c.content.id),
        [b.contentId, a.contentId],
      );
    });
  });

  group('FakeAccountRepo', () {
    LoginAccount account({
      String remote = '9',
      String name = 'me',
      DateTime? at,
    }) => LoginAccount(
      id: LoginAccount.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: remote,
      username: name,
      status: AccountStatus.active,
      connectedAt: at ?? t0,
    );

    test('upsert inserts then updates by remoteUserId', () async {
      final repo = FakeAccountRepo();
      final a = await repo.upsert(account());
      final b = await repo.upsert(account(name: 'renamed'));
      expect(b.id, a.id);
      expect((await repo.getActive())!.username, 'renamed');
    });

    test('watchActive emits null, the account, then status changes', () async {
      final repo = FakeAccountRepo();
      final events = <AccountStatus?>[];
      final sub = repo.watchActive().listen((a) => events.add(a?.status));
      await pumpEventQueue();
      final a = await repo.upsert(account());
      await repo.setStatus(a.id, AccountStatus.needsRelogin, reason: 'expired');
      await pumpEventQueue();
      await sub.cancel();
      expect(events, [null, AccountStatus.active, AccountStatus.needsRelogin]);
      final stored = (await repo.getActive())!;
      expect(stored.statusReason, 'expired');
      await repo.setStatus(a.id, AccountStatus.active, lastSuccessAt: t0);
      final back = (await repo.getActive())!;
      expect(back.statusReason, isNull);
      expect(back.lastSuccessAt, t0);
    });

    test('the active account is the latest connected', () async {
      final repo = FakeAccountRepo();
      await repo.upsert(account(remote: '1', at: t0));
      final newer = await repo.upsert(
        account(remote: '2', at: t0.add(const Duration(days: 1))),
      );
      expect((await repo.getActive())!.id, newer.id);
    });

    test('setStatus of a missing account throws', () async {
      await expectLater(
        FakeAccountRepo().setStatus(5, AccountStatus.active),
        throwsStateError,
      );
    });
  });

  group('FakeActivityRepo', () {
    late FakeClock clock;
    late FakeActivityRepo repo;
    setUp(() {
      clock = FakeClock(t0);
      repo = FakeActivityRepo(clock);
    });

    ActivityEvent event(ActivityType type, DateTime at) =>
        ActivityEvent(id: ActivityEvent.unsavedId, at: at, type: type);

    test(
      'watchRecent covers 7 days, newest first, with a type filter',
      () async {
        await repo.add(
          event(ActivityType.checkDone, t0.subtract(const Duration(days: 8))),
        );
        await repo.add(
          event(ActivityType.checkDone, t0.subtract(const Duration(days: 6))),
        );
        await repo.add(
          event(ActivityType.gap, t0.subtract(const Duration(hours: 1))),
        );
        final all = await repo.watchRecent().first;
        expect(all.map((e) => e.type), [
          ActivityType.gap,
          ActivityType.checkDone,
        ]);
        final gaps = await repo.watchRecent(types: {ActivityType.gap}).first;
        expect(gaps, hasLength(1));
      },
    );

    test('watchRecent emits on add and prune', () async {
      final counts = <int>[];
      final sub = repo.watchRecent().listen((l) => counts.add(l.length));
      await pumpEventQueue();
      await repo.add(event(ActivityType.gap, t0));
      expect(await repo.pruneOlderThan(t0.add(const Duration(hours: 1))), 1);
      expect(await repo.pruneOlderThan(t0), 0);
      await pumpEventQueue();
      await sub.cancel();
      expect(counts, [0, 1, 0]);
    });

    test('add assigns ids', () async {
      final a = await repo.add(event(ActivityType.gap, t0));
      final b = await repo.add(event(ActivityType.gap, t0));
      expect(a.id, isNot(b.id));
    });
  });

  group('FakeCheckRunRepo', () {
    test('start, finish and lastFinished per scope', () async {
      final repo = FakeCheckRunRepo();
      final r1 = await repo.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: t0,
      );
      expect(await repo.lastFinished(CheckScope.stories), isNull);
      await repo.finish(
        r1.id,
        finishedAt: t0,
        result: CheckResult.ok,
        mode: ExtractionMode.direct,
        targetsChecked: 3,
        newItems: 1,
      );
      final r2 = await repo.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.manualAll,
        startedAt: t0.add(const Duration(hours: 1)),
      );
      expect((await repo.lastFinished(CheckScope.stories))!.id, r1.id);
      final done = await repo.finish(
        r2.id,
        finishedAt: t0,
        result: CheckResult.partial,
        errorCode: 'e',
      );
      expect(done.errorCode, 'e');
      expect((await repo.lastFinished(CheckScope.stories))!.id, r2.id);
      expect(await repo.lastFinished(CheckScope.posts), isNull);
    });

    test('scope ALL is rejected; finishing an unknown run throws', () async {
      final repo = FakeCheckRunRepo();
      await expectLater(
        repo.start(
          scope: CheckScope.all,
          trigger: CheckTrigger.periodic,
          startedAt: t0,
        ),
        throwsArgumentError,
      );
      await expectLater(repo.lastFinished(CheckScope.all), throwsArgumentError);
      await expectLater(
        repo.finish(9, finishedAt: t0, result: CheckResult.ok),
        throwsStateError,
      );
    });
  });

  group('FakeSettingsRepo', () {
    late FakeSettingsRepo repo;
    setUp(() => repo = FakeSettingsRepo());

    test('starts with the defaults', () async {
      expect(await repo.get(), const AppSettings());
    });

    test('accepts every allowed interval', () async {
      for (final m in AppSettings.storyIntervalOptions) {
        expect(
          (await repo.update((s) => s.copyWith(storyIntervalMin: m)))
              .storyIntervalMin,
          m,
        );
      }
      for (final m in AppSettings.postIntervalOptions) {
        expect(
          (await repo.update((s) => s.copyWith(postIntervalMin: m)))
              .postIntervalMin,
          m,
        );
      }
    });

    test(
      'rejects a 10 minute story interval and a 30 minute post interval',
      () async {
        await expectLater(
          repo.update((s) => s.copyWith(storyIntervalMin: 10)),
          throwsA(isA<SettingsValidationException>()),
        );
        await expectLater(
          repo.update((s) => s.copyWith(postIntervalMin: 30)),
          throwsA(
            isA<SettingsValidationException>().having(
              (e) => e.problems,
              'problems',
              hasLength(1),
            ),
          ),
        );
        expect(await repo.get(), const AppSettings());
      },
    );

    test(
      'an invalid update changes nothing, even with other valid changes',
      () async {
        await expectLater(
          repo.update((s) => s.copyWith(wifiOnly: true, storyIntervalMin: 7)),
          throwsA(isA<SettingsValidationException>()),
        );
        expect((await repo.get()).wifiOnly, isFalse);
      },
    );

    test('watch emits the current value and every accepted update', () async {
      final events = <bool>[];
      final sub = repo.watch().listen((s) => events.add(s.wifiOnly));
      await pumpEventQueue();
      await repo.update((s) => s.copyWith(wifiOnly: true));
      await repo
          .update((s) => s.copyWith(storyIntervalMin: 5))
          .catchError((_) => const AppSettings());
      await pumpEventQueue();
      await sub.cancel();
      expect(events, [false, true]);
    });

    test('an invalid initial value is rejected', () {
      expect(
        () => FakeSettingsRepo(const AppSettings(storyIntervalMin: 1)),
        throwsA(isA<SettingsValidationException>()),
      );
    });
  });

  group('FakeGovernorLeaseRepo', () {
    late FakeClock clock;
    late FakeGovernorLeaseRepo repo;
    late GovernorBucket bucket;
    const ttl = Duration(seconds: 30);

    setUp(() {
      clock = FakeClock(t0);
      repo = FakeGovernorLeaseRepo(clock);
      bucket = GovernorBucket(tokens: 5, lastRefillAt: t0);
    });

    Future<GovernorLease?> acquire(String holder) => repo.acquire(
      accountId: 1,
      holder: holder,
      ttl: ttl,
      initialBucket: bucket,
    );

    test('a second holder is refused while the lease is live', () async {
      expect((await acquire('ui'))!.holder, 'ui');
      expect(await acquire('bg'), isNull);
      expect(await acquire('ui'), isNotNull);
    });

    test('an expired lease can be taken over and keeps the bucket', () async {
      await acquire('ui');
      expect(
        await repo.writeBucket(
          accountId: 1,
          holder: 'ui',
          bucket: GovernorBucket(tokens: 1, lastRefillAt: t0),
        ),
        isTrue,
      );
      clock.advance(ttl);
      final taken = await acquire('bg');
      expect(taken!.holder, 'bg');
      expect(taken.bucket.tokens, 1);
    });

    test('renew extends the lease and fails after expiry', () async {
      await acquire('ui');
      clock.advance(const Duration(seconds: 20));
      expect(await repo.renew(accountId: 1, holder: 'ui', ttl: ttl), isTrue);
      clock.advance(const Duration(seconds: 20));
      expect(await acquire('bg'), isNull);
      clock.advance(const Duration(seconds: 10));
      expect(await repo.renew(accountId: 1, holder: 'ui', ttl: ttl), isFalse);
      expect(await repo.renew(accountId: 2, holder: 'ui', ttl: ttl), isFalse);
    });

    test(
      'release frees the lease for others but only for its holder',
      () async {
        await acquire('ui');
        await repo.release(accountId: 1, holder: 'bg');
        expect(await acquire('bg'), isNull);
        await repo.release(accountId: 1, holder: 'ui');
        expect(await acquire('bg'), isNotNull);
      },
    );

    test('writeBucket needs a live lease owned by the holder', () async {
      await acquire('ui');
      final next = GovernorBucket(
        tokens: 2,
        lastRefillAt: t0,
        backoffUntil: t0,
        backoffMultiplier: 2,
      );
      expect(
        await repo.writeBucket(accountId: 1, holder: 'bg', bucket: next),
        isFalse,
      );
      expect(
        await repo.writeBucket(accountId: 1, holder: 'ui', bucket: next),
        isTrue,
      );
      expect((await repo.read(1))!.bucket, next);
      clock.advance(ttl);
      expect(
        await repo.writeBucket(accountId: 1, holder: 'ui', bucket: bucket),
        isFalse,
      );
      expect((await repo.read(1))!.bucket, next);
      expect(await repo.read(2), isNull);
    });
  });
}
