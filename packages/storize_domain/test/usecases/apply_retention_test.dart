import 'package:storize_domain/src/usecases/apply_retention.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  const n = 30;
  const window = Duration(days: n);
  late Harness h;
  late Target t;
  late DateTime now;

  setUp(() async {
    h = Harness();
    now = h.clock.now();
    t = await h.addTarget();
    await h.settings.update((s) => s.copyWith(retentionDays: n));
  });

  Future<bool> exists(int id) async => await h.content.getById(id) != null;

  test('AC3: off when retentionDays is null (default)', () async {
    final hh = Harness();
    final tt = await hh.addTarget();
    final id = await hh.addContent(
      tt,
      remoteId: 'old',
      postedAt: hh.clock.now().subtract(const Duration(days: 4000)),
    );

    final result = await hh.retention();

    expect(result.skipped, RetentionSkip.disabled);
    expect(await hh.content.getById(id), isNotNull);
    expect(hh.gallery.files, hasLength(1));
  });

  test('AC3 boundaries: N-1ms kept, exactly N kept, N+1ms deleted', () async {
    final younger = await h.addContent(
      t,
      remoteId: 'y',
      postedAt: now.subtract(window - const Duration(milliseconds: 1)),
    );
    final exact = await h.addContent(
      t,
      remoteId: 'e',
      postedAt: now.subtract(window),
    );
    final older = await h.addContent(
      t,
      remoteId: 'o',
      postedAt: now.subtract(window + const Duration(milliseconds: 1)),
    );

    final result = await h.retention();

    expect(await exists(younger), isTrue);
    expect(await exists(exact), isTrue);
    expect(await exists(older), isFalse);
    expect(result.deletion!.deletedContentIds, [older]);
    expect(h.gallery.files, hasLength(2));
  });

  test('AC3: deletes the gallery files first, then rows', () async {
    await h.addContent(
      t,
      remoteId: 'o',
      slides: 2,
      postedAt: now.subtract(window * 2),
    );

    await h.retention();

    expect(h.spy.deletes, hasLength(2));
    expect(h.spy.deletes.every((d) => d.rowStillThere), isTrue);
    expect(h.gallery.files, isEmpty);
  });

  test(
    'AC3: a failing item stays, the rest goes, and the next run retries',
    () async {
      final ids = [
        for (var i = 0; i < 5; i++)
          await h.addContent(
            t,
            remoteId: 'o$i',
            postedAt: now.subtract(Duration(days: 40 + i)),
          ),
      ];
      // olderThan is oldest first, so o4 is processed first.
      h.gallery.failNextDelete(const GalleryPermissionDenied());

      final first = await h.retention();

      expect(first.deletion!.failures.map((f) => f.contentId), [ids[4]]);
      expect(first.deletion!.deletedContentIds, hasLength(4));
      expect(await exists(ids[4]), isTrue);

      final second = await h.retention();
      expect(second.deletion!.isComplete, isTrue);
      expect(await exists(ids[4]), isFalse);
      expect(h.gallery.files, isEmpty);
    },
  );

  test('AC3: works in chunks for a larger library (chunkSize 2)', () async {
    for (var i = 0; i < 7; i++) {
      await h.addContent(
        t,
        remoteId: 'o$i',
        postedAt: now.subtract(Duration(days: 100 + i)),
      );
    }
    final result = await h.retention();
    expect(result.deletion!.deletedContentIds, hasLength(7));
    expect(h.gallery.files, isEmpty);
  });

  test('AC3: idempotent when nothing is left', () async {
    await h.addContent(t, remoteId: 'o', postedAt: now.subtract(window * 2));
    await h.retention();
    final again = await h.retention();
    expect(again.deletion!.deletedContentIds, isEmpty);
    expect(again.deletion!.isComplete, isTrue);
  });

  test('AC3: a huge N does not overflow DateTime', () async {
    await h.settings.update((s) => s.copyWith(retentionDays: 1 << 40));
    final id = await h.addContent(t, remoteId: 'o', postedAt: now);
    final result = await h.retention();
    expect(result.deletion!.deletedContentIds, isEmpty);
    expect(await exists(id), isTrue);
  });

  group('clock-skew guard', () {
    Future<void> finishedRun(DateTime at) async {
      final run = await h.checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: at,
      );
      await h.checkRuns.finish(run.id, finishedAt: at, result: CheckResult.ok);
    }

    late int old;
    setUp(() async {
      old = await h.addContent(
        t,
        remoteId: 'o',
        postedAt: now.subtract(window * 2),
      );
    });

    test('clock behind the last finished check run: nothing deleted', () async {
      await finishedRun(now.add(const Duration(hours: 1)));
      final r = await h.retention();
      expect(r.skipped, RetentionSkip.clockSkew);
      expect(await exists(old), isTrue);
      expect(h.spy.deletes, isEmpty);
    });

    test(
      'clock jumped far forward since the last run: nothing deleted',
      () async {
        await finishedRun(now.subtract(const Duration(days: 31)));
        final r = await h.retention();
        expect(r.skipped, RetentionSkip.clockSkew);
        expect(await exists(old), isTrue);
      },
    );

    test('a normal recent check run lets retention proceed', () async {
      await finishedRun(now.subtract(const Duration(days: 29)));
      final r = await h.retention();
      expect(r.skipped, isNull);
      expect(await exists(old), isFalse);
    });

    test('the guard recovers once a fresh run finishes', () async {
      await finishedRun(now.subtract(const Duration(days: 60)));
      expect((await h.retention()).skipped, RetentionSkip.clockSkew);
      await finishedRun(now);
      expect((await h.retention()).skipped, isNull);
      expect(await exists(old), isFalse);
    });

    test(
      'F2: future-dated content is excluded and counted, the rest goes',
      () async {
        final fut = await h.addContent(
          t,
          remoteId: 'f',
          postedAt: now.subtract(window * 2),
          detectedAt: now.add(const Duration(days: 400)),
        );
        final r = await h.retention();
        expect(r.skipped, isNull);
        expect(r.skippedFutureDated, 1);
        expect(await exists(fut), isTrue);
        expect(await exists(old), isFalse);
      },
    );

    test(
      'F2: media downloaded in the future is excluded and counted',
      () async {
        final fut = await h.addContent(
          t,
          remoteId: 'f',
          postedAt: now.subtract(window * 2),
          downloadedAt: now.add(const Duration(minutes: 5)),
        );
        final r = await h.retention();
        expect(r.skippedFutureDated, 1);
        expect(await exists(fut), isTrue);
        expect(await exists(old), isFalse);
      },
    );
  });

  group('F1: age is how long Storize has had the item', () {
    test(
      'posted long ago but detected and downloaded recently: kept',
      () async {
        final id = await h.addContent(
          t,
          remoteId: 'late',
          kind: ContentKind.post,
          postedAt: now.subtract(window * 2),
          detectedAt: now,
          downloadedAt: now,
        );
        final r = await h.retention();
        expect(r.deletion!.deletedContentIds, isEmpty);
        expect(await exists(id), isTrue);
      },
    );

    test('detected long ago but one slide downloaded recently: kept', () async {
      final id = await h.addContent(
        t,
        remoteId: 'redl',
        postedAt: now.subtract(window * 2),
        detectedAt: now.subtract(window * 2),
        downloadedAt: now.subtract(const Duration(days: 1)),
      );
      await h.retention();
      expect(await exists(id), isTrue);
    });

    test(
      'isRetentionEligible: boundaries and narrowing of olderThan',
      () async {
        final cutoff = now.subtract(window);
        var seq = 0;
        Future<ContentWithMedia> item({
          required DateTime posted,
          required DateTime detected,
          DateTime? downloaded,
        }) async {
          final id = await h.addContent(
            t,
            remoteId: 'x${seq++}',
            postedAt: posted,
            detectedAt: detected,
            downloadedAt: downloaded,
          );
          return (await h.content.getById(id))!;
        }

        const ms = Duration(milliseconds: 1);
        final old = cutoff.subtract(ms);
        expect(
          isRetentionEligible(await item(posted: old, detected: old), cutoff),
          isTrue,
        );
        expect(
          isRetentionEligible(
            await item(posted: cutoff, detected: cutoff, downloaded: cutoff),
            cutoff,
          ),
          isFalse,
        );
        expect(
          isRetentionEligible(
            await item(posted: old, detected: old, downloaded: cutoff),
            cutoff,
          ),
          isFalse,
        );
        expect(
          isRetentionEligible(
            await item(posted: old, detected: cutoff),
            cutoff,
          ),
          isFalse,
        );
        // postedAt newer than the cutoff is never eligible.
        expect(
          isRetentionEligible(
            await item(posted: cutoff, detected: old),
            cutoff,
          ),
          isFalse,
        );
      },
    );
  });

  test('BR-4: expiry and remote removal never delete anything', () async {
    // Expired long ago, removed remotely, but still within retention.
    final expired = await h.addContent(
      t,
      remoteId: 'e',
      postedAt: now.subtract(const Duration(days: 2)),
      expiresAt: now.subtract(const Duration(days: 1)),
    );
    final gone = await h.addContent(
      t,
      remoteId: 'g',
      kind: ContentKind.post,
      postedAt: now.subtract(const Duration(days: 3)),
    );
    final c = (await h.content.getById(gone))!.content;
    await h.content.updateContent(
      c.copyWith(status: ContentStatus.removedBeforeDownload),
    );
    await h.targets.update(
      (await h.targets.getById(t.id))!
          .copyWith(status: TargetStatus.notVisible),
    );

    final r = await h.retention();

    expect(r.deletion!.deletedContentIds, isEmpty);
    expect(await exists(expired), isTrue);
    expect(await exists(gone), isTrue);
    expect(h.gallery.files, hasLength(2));
    expect(h.spy.deletes, isEmpty);
  });
}
