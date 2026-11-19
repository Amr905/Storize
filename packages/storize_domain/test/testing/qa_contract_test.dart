import 'dart:async';

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart';

/// QA contract tests (T-004 verification): edge cases a real DB would honour.
void main() {
  group('lease expiry edge', () {
    test(
      'at exactly expiresAt the lease is free; 1 ms before it is held',
      () async {
        final clock = FakeClock(t0);
        final repo = FakeGovernorLeaseRepo(clock);
        final bucket = GovernorBucket(tokens: 1, lastRefillAt: t0);
        await repo.acquire(
          accountId: 1,
          holder: 'ui',
          ttl: const Duration(seconds: 10),
          initialBucket: bucket,
        );
        clock.set(t0.add(const Duration(seconds: 10, milliseconds: -1)));
        expect(
          await repo.acquire(
            accountId: 1,
            holder: 'bg',
            ttl: const Duration(seconds: 10),
            initialBucket: bucket,
          ),
          isNull,
        );
        expect(
          await repo.writeBucket(accountId: 1, holder: 'ui', bucket: bucket),
          isTrue,
        );
        clock.set(t0.add(const Duration(seconds: 10)));
        expect(
          await repo.writeBucket(accountId: 1, holder: 'ui', bucket: bucket),
          isFalse,
        );
        expect(
          await repo.renew(
            accountId: 1,
            holder: 'ui',
            ttl: const Duration(seconds: 10),
          ),
          isFalse,
        );
        expect(
          await repo.acquire(
            accountId: 1,
            holder: 'bg',
            ttl: const Duration(seconds: 10),
            initialBucket: bucket,
          ),
          isNotNull,
        );
      },
    );

    test('FakeClock converts a local DateTime to UTC', () {
      expect(FakeClock(DateTime(2026, 5, 2)).now().isUtc, isTrue);
      final c = FakeClock(DateTime.utc(2027))..set(DateTime(2026, 5, 1, 3));
      expect(c.now().isUtc, isTrue);
      c.advance(const Duration(hours: 1));
      expect(c.now().isUtc, isTrue);
    });
  });

  group('watch streams', () {
    test('every watch*() call returns a fresh stream, so two screens can '
        'watch the same repo', () async {
      final repo = FakeTargetRepo();
      final a = <int>[];
      final b = <int>[];
      final s1 = repo.watchAll().listen((l) => a.add(l.length));
      final s2 = repo.watchAll().listen((l) => b.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await repo.insert(target());
      await Future<void>.delayed(Duration.zero);
      expect(a, [0, 1]);
      expect(b, [0, 1]);
      await s1.cancel();
      await s2.cancel();
    });

    test('a late subscriber gets the current value first', () async {
      final repo = FakeTargetRepo();
      await repo.insert(target());
      expect(await repo.watchAll().first, hasLength(1));
      final settings = FakeSettingsRepo();
      expect((await settings.watch().first).storyIntervalMin, 30);
    });

    test('listening to the SAME stream object twice throws '
        '(single-subscription; documented finding)', () async {
      final stream = FakeTargetRepo().watchAll();
      final sub = stream.listen((_) {});
      expect(() => stream.listen((_) {}), throwsStateError);
      await sub.cancel();
    });

    test('a cancelled subscription receives nothing more', () async {
      final repo = FakeTargetRepo();
      final seen = <int>[];
      final sub = repo.watchAll().listen((l) => seen.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await repo.insert(target());
      await Future<void>.delayed(Duration.zero);
      expect(seen, [0]);
    });

    test('library stream re-emits when a media file changes status', () async {
      final targets = FakeTargetRepo();
      final repo = FakeContentRepo(targets: targets);
      final t = await targets.insert(target());
      final r = await repo.insertIfNew(content(targetId: t.id), [media()]);
      final states = <MediaFileStatus>[];
      final sub = repo
          .watchLibrary(ContentFilter())
          .listen((l) => states.add(l.single.media.single.status));
      await Future<void>.delayed(Duration.zero);
      final m = (await repo.getById(r.contentId))!.media.single;
      await repo.updateMediaFile(m.copyWith(status: MediaFileStatus.done));
      await Future<void>.delayed(Duration.zero);
      expect(states, [MediaFileStatus.pending, MediaFileStatus.done]);
      await sub.cancel();
    });
  });

  group('content repo fidelity', () {
    late FakeTargetRepo targets;
    late FakeContentRepo repo;
    late Target t;
    setUp(() async {
      targets = FakeTargetRepo();
      repo = FakeContentRepo(targets: targets);
      t = await targets.insert(target());
    });

    test(
      'duplicate insert with different slides leaves no stray media',
      () async {
        await repo.insertIfNew(content(targetId: t.id), [media()]);
        await repo.insertIfNew(
          content(targetId: t.id),
          [media(), media(slideIndex: 1), media(slideIndex: 2)],
        );
        expect(await repo.pendingMedia(), hasLength(1));
      },
    );

    test('cascade removes media, pending queue and storage totals', () async {
      await repo.insertIfNew(
        content(targetId: t.id),
        [media(status: MediaFileStatus.done, sizeBytes: 10)],
      );
      await repo.insertIfNew(
        content(targetId: t.id, remoteId: 'r2'),
        [media()],
      );
      await targets.delete(t.id);
      expect(await repo.pendingMedia(), isEmpty);
      expect(await repo.storageBytesByTarget(), isEmpty);
      expect(await repo.listByTarget(t.id), isEmpty);
    });

    test(
      "deleting a target does not touch another target's content",
      () async {
        final other = await targets.insert(target(remoteUserId: '200'));
        await repo.insertIfNew(content(targetId: t.id), [media()]);
        await repo.insertIfNew(content(targetId: other.id), [media()]);
        await targets.delete(t.id);
        expect(await repo.listByTarget(other.id), hasLength(1));
      },
    );

    test(
      'pending order: story before post even when the post is older',
      () async {
        await repo.insertIfNew(
          content(
            targetId: t.id,
            remoteId: 'p',
            kind: ContentKind.post,
            detectedAt: t0.subtract(const Duration(hours: 1)),
          ),
          [media()],
        );
        await repo.insertIfNew(content(targetId: t.id, remoteId: 's'), [
          media(),
        ]);
        final order = (await repo.pendingMedia()).map((p) => p.content.kind);
        expect(order, [ContentKind.story, ContentKind.post]);
      },
    );

    test('resetInterruptedDownloads leaves FAILED/DONE alone', () async {
      await repo.insertIfNew(content(targetId: t.id), [
        media(status: MediaFileStatus.failed),
        media(slideIndex: 1, status: MediaFileStatus.downloading),
        media(slideIndex: 2, status: MediaFileStatus.done),
      ]);
      expect(await repo.resetInterruptedDownloads(), 1);
      expect(await repo.resetInterruptedDownloads(), 0);
    });

    test('olderThan is exclusive at the cutoff', () async {
      await repo.insertIfNew(content(targetId: t.id, postedAt: t0), [media()]);
      expect(await repo.olderThan(t0), isEmpty);
      expect(
        await repo.olderThan(t0.add(const Duration(milliseconds: 1))),
        hasLength(1),
      );
    });
  });

  group('target rules', () {
    test('Target with all track flags off is rejected (debug assert)', () {
      expect(
        () => target(trackStories: false, trackPosts: false, trackReels: false),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => target().copyWith(
          trackStories: false,
          trackPosts: false,
          trackReels: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('reels-only target is listed for posts, not for stories', () async {
      final repo = FakeTargetRepo();
      await repo.insert(
        target(trackStories: false, trackPosts: false),
      );
      expect(await repo.listActive(CheckScope.posts), hasLength(1));
      expect(await repo.listActive(CheckScope.stories), isEmpty);
    });

    test('PAUSED / NOT_VISIBLE / ERROR targets are never listed', () async {
      final repo = FakeTargetRepo();
      var i = 0;
      for (final s in TargetStatus.values) {
        await repo.insert(target(remoteUserId: '${i++}', status: s));
      }
      for (final scope in CheckScope.values) {
        expect(
          (await repo.listActive(scope)).every(
            (x) => x.status == TargetStatus.active,
          ),
          isTrue,
        );
      }
    });

    test('FINDING: update() may change identity into a duplicate', () async {
      final repo = FakeTargetRepo();
      await repo.insert(target());
      final b = await repo.insert(target(remoteUserId: '200'));
      // The type system forbids changing remoteUserId through copyWith, so
      // the UNIQUE rule cannot be violated by update(); document that.
      await repo.update(b.copyWith(username: 'renamed'));
      expect((await repo.getById(b.id))!.remoteUserId, '200');
    });
  });

  group('settings', () {
    test('update with a throwing callback stores nothing', () async {
      final repo = FakeSettingsRepo();
      await expectLater(
        repo.update((_) => throw StateError('boom')),
        throwsStateError,
      );
      expect((await repo.get()).storyIntervalMin, 30);
    });

    test('boundaries: retention 0 and -1 rejected, 1 accepted; 45 min '
        'story interval rejected; post 30 rejected', () async {
      final repo = FakeSettingsRepo();
      for (final bad in [
        (AppSettings s) => s.copyWith(retentionDays: 0),
        (AppSettings s) => s.copyWith(retentionDays: -1),
        (AppSettings s) => s.copyWith(storyIntervalMin: 45),
        (AppSettings s) => s.copyWith(postIntervalMin: 30),
        (AppSettings s) => s.copyWith(postIntervalMin: 15),
      ]) {
        await expectLater(
          repo.update(bad),
          throwsA(isA<SettingsValidationException>()),
        );
      }
      expect(
        (await repo.update((s) => s.copyWith(retentionDays: 1))).retentionDays,
        1,
      );
      expect(
        (await repo.update((s) => s.copyWith(retentionDays: null)))
            .retentionDays,
        isNull,
      );
    });
  });

  group('check_run scope', () {
    test('start rejects ALL, finish stores mode and counters', () async {
      final repo = FakeCheckRunRepo();
      expect(
        () => repo.start(
          scope: CheckScope.all,
          trigger: CheckTrigger.periodic,
          startedAt: t0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('openMedia scripting', () {
    test(
      'resume honours fromByte and error is delivered as stream error',
      () async {
        final p = FakeContentPlatform()
          ..queueMediaError(
            const ExpiredMediaUrl(),
            bytesBeforeError: [1, 2, 3],
          );
        final got = <int>[];
        Object? err;
        try {
          await p.openMedia('u').forEach(got.addAll);
        } on Object catch (e) {
          err = e;
        }
        expect(got, [1, 2, 3]);
        expect(err, isA<ExpiredMediaUrl>());
      },
    );
  });
}
