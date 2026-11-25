import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// Runs [hook] before every delete (not just the first).
final class EveryDeleteGallery implements GalleryStore {
  EveryDeleteGallery(this.inner, this.hook);

  final GalleryStore inner;
  final Future<void> Function() hook;

  @override
  Future<bool> delete(String contentUri) async {
    await hook();
    return inner.delete(contentUri);
  }

  @override
  Future<bool> exists(String u) => inner.exists(u);

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => inner.save(
    sourcePath: sourcePath,
    relativeDir: relativeDir,
    displayName: displayName,
    mime: mime,
  );

  @override
  Future<int?> size(String u) => inner.size(u);
}

void main() {
  late Harness h;
  late Target t;
  late DateTime now;
  const n = 7;
  const day = Duration(days: 1);

  setUp(() async {
    h = Harness();
    now = h.clock.now();
    t = await h.addTarget();
    await h.settings.update((s) => s.copyWith(retentionDays: n));
  });

  DateTime cutoff() => now.subtract(const Duration(days: n));

  group('retention eligibility never widens (round 2 F1)', () {
    test('matrix: deleted iff postedAt, detectedAt, downloadedAt all < cutoff '
        'and none in the future; deleted is a subset of olderThan', () async {
      final offsets = <Duration>[
        -const Duration(milliseconds: 1),
        Duration.zero,
        const Duration(milliseconds: 1),
        -day * 3,
        day * 2,
      ]; // relative to the cutoff
      final expected = <int, bool>{};
      var k = 0;
      for (final p in offsets) {
        for (final d in offsets) {
          for (final dl in <Duration?>[null, ...offsets]) {
            final posted = cutoff().add(p);
            final detected = cutoff().add(d);
            final downloaded = dl == null ? null : cutoff().add(dl);
            final id = await h.addContent(
              t,
              remoteId: 'm${k++}',
              postedAt: posted,
              detectedAt: detected,
              downloadedAt: downloaded,
            );
            final future =
                detected.isAfter(now) || (downloaded?.isAfter(now) ?? false);
            expected[id] =
                !future &&
                posted.isBefore(cutoff()) &&
                detected.isBefore(cutoff()) &&
                (downloaded?.isBefore(cutoff()) ?? true);
          }
        }
      }
      final olderIds = {
        for (final i in await h.content.olderThan(cutoff())) i.content.id,
      };
      final r = await h.retention();
      final deleted = r.deletion!.deletedContentIds.toSet();
      expect(deleted.difference(olderIds), isEmpty, reason: 'widened');
      for (final e in expected.entries) {
        expect(deleted.contains(e.key), e.value, reason: 'id ${e.key}');
        expect(await h.content.getById(e.key) == null, e.value);
      }
    });

    test(
      'one fresh slide keeps the whole multi-slide item and all its files',
      () async {
        final id = await h.addContent(
          t,
          remoteId: 'carousel',
          slides: 3,
          postedAt: now.subtract(day * 30),
          downloadedAt: now.subtract(day * 30),
        );
        // Re-download of slide 2 yesterday.
        final item = (await h.content.getById(id))!;
        await h.content.updateMediaFile(
          item.media[2].copyWith(downloadedAt: now.subtract(day)),
        );
        final r = await h.retention();
        expect(r.deletion!.deletedContentIds, isEmpty);
        expect(h.gallery.files, hasLength(3));
      },
    );
  });

  group('future-dated exclusion is safe (round 2 F2)', () {
    test(
      'future detectedAt on an old post: file and row kept, counted',
      () async {
        final id = await h.addContent(
          t,
          remoteId: 'f',
          postedAt: now.subtract(day * 60),
          detectedAt: now.add(day),
        );
        final r = await h.retention();
        expect(r.skippedFutureDated, 1);
        expect(r.deletion!.deletedContentIds, isEmpty);
        expect(await h.content.getById(id), isNotNull);
        expect(h.spy.deletes, isEmpty);
      },
    );

    test('future downloadedAt on one slide excludes the whole item', () async {
      final id = await h.addContent(
        t,
        remoteId: 'f2',
        slides: 2,
        postedAt: now.subtract(day * 60),
        downloadedAt: now.subtract(day * 60),
      );
      final item = (await h.content.getById(id))!;
      await h.content.updateMediaFile(
        item.media[1].copyWith(downloadedAt: now.add(day)),
      );
      final r = await h.retention();
      expect(r.skippedFutureDated, 1);
      expect(h.gallery.files, hasLength(2));
    });

    test('future-dated items do not bypass rules 1 and 3', () async {
      await h.addContent(t, remoteId: 'ok', postedAt: now.subtract(day * 60));
      final run = await h.checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: now.add(const Duration(hours: 1)),
      );
      await h.checkRuns.finish(
        run.id,
        finishedAt: now.add(const Duration(hours: 1)),
        result: CheckResult.ok,
      );
      final r = await h.retention();
      expect(r.skipped, RetentionSkip.clockSkew);
      expect(h.spy.deletes, isEmpty);
    });
  });

  group('RemoveTarget loop (round 2 F4)', () {
    RemoveTarget build(GalleryStore g) => RemoveTarget(
      targets: h.targets,
      content: h.content,
      deleteContent: DeleteContent(
        content: h.content,
        gallery: g,
        cache: h.cache,
      ),
    );

    test('a failed item whose rows stay is never cascaded: only failure, '
        'target kept, file intact', () async {
      final bad = await h.addContent(t, remoteId: 'bad');
      h.gallery.failNextDelete(const GalleryPermissionDenied());
      final r = await h.removeTarget(t.id, deleteMedia: true);
      expect(r.targetRemoved, isFalse);
      expect(await h.targets.getById(t.id), isNotNull);
      expect(await h.content.getById(bad), isNotNull);
      expect(h.gallery.files, hasLength(1));
    });

    test('failure in pass 1 then new content in pass 2: new content deleted, '
        'target and failed rows kept', () async {
      final bad = await h.addContent(t, remoteId: 'bad');
      final other = await h.addContent(t, remoteId: 'other');
      var added = false;
      final g = EveryDeleteGallery(h.spy, () async {
        if (!added) {
          added = true;
          await h.addContent(t, remoteId: 'late');
        }
      });
      h.gallery.failNextDelete(const GalleryPermissionDenied());
      final r = await build(g)(t.id, deleteMedia: true);
      // listByTarget is newest first, so 'other' is the first (failing) item.
      final failedId = r.deletion!.failures.single.contentId;
      expect(failedId, other);
      expect(r.targetRemoved, isFalse);
      expect(await h.content.getById(other), isNotNull);
      expect(await h.content.getById(bad), isNull);
      expect((await h.content.listByTarget(t.id)).map((i) => i.content.id), [
        other,
      ]);
      expect(h.gallery.files, hasLength(1));
    });

    test('a failing item is attempted once per call (no spin)', () async {
      await h.addContent(t, remoteId: 'bad');
      var calls = 0;
      final g = EveryDeleteGallery(h.spy, () async => calls++);
      // Permission denied every time.
      final failing = _AlwaysDenied(g);
      final r = await build(failing)(t.id, deleteMedia: true);
      expect(r.targetRemoved, isFalse);
      expect(calls, 1);
    });

    test('maxPasses exhausted never deletes the target', () async {
      await h.addContent(t, remoteId: 'a');
      var i = 0;
      final g = EveryDeleteGallery(h.spy, () async {
        await h.addContent(t, remoteId: 'x${i++}');
      });
      final r = await build(g)(t.id, deleteMedia: true);
      expect(r.targetRemoved, isFalse);
      expect(await h.targets.getById(t.id), isNotNull);
      expect(r.isComplete, isFalse);
    });

    test('keep media is unchanged: one target delete, no file calls', () async {
      await h.addContent(t, remoteId: 'a');
      final r = await h.removeTarget(t.id, deleteMedia: false);
      expect(r.targetRemoved, isTrue);
      expect(r.deletion, isNull);
      expect(h.spy.deletes, isEmpty);
    });
  });
}

final class _AlwaysDenied implements GalleryStore {
  _AlwaysDenied(this.inner);

  final GalleryStore inner;

  @override
  Future<bool> delete(String contentUri) async {
    await (inner as EveryDeleteGallery).hook();
    throw const GalleryPermissionDenied();
  }

  @override
  Future<bool> exists(String u) => inner.exists(u);

  @override
  Future<GalleryFile> save({
    required String sourcePath,
    required String relativeDir,
    required String displayName,
    required String mime,
  }) => inner.save(
    sourcePath: sourcePath,
    relativeDir: relativeDir,
    displayName: displayName,
    mime: mime,
  );

  @override
  Future<int?> size(String u) => inner.size(u);
}
