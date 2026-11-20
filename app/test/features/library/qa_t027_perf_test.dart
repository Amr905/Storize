import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

// QA perf checks for T-027 (NFR-12): many distinct days, and the real
// in-memory repo stream instead of a ready list.

ContentWithMedia _item(int i, int targetId, DateTime posted) =>
    ContentWithMedia(
      Content(
        id: i + 1,
        targetId: targetId,
        kind: ContentKind.story,
        remoteId: 'r$i',
        postedAt: posted.toUtc(),
        slideCount: 1,
        detectedAt: posted.toUtc(),
        viewed: i % 3 != 0,
        status: ContentStatus.done,
      ),
      [
        MediaFile(
          id: i + 1,
          contentId: i + 1,
          slideIndex: 0,
          mediaType: MediaType.photo,
          sourceUrl: 'https://example.invalid/$i',
          status: MediaFileStatus.done,
          contentUri: 'content://fake/$i',
          thumbPath: '/thumbs/$i.webp',
        ),
      ],
    );

void main() {
  // The first pump in a test process pays for JIT compilation and font and
  // theme setup (about 1 s here). That cost is not the library's, so warm up
  // once before the measured tests.
  testWidgets('warm-up (not measured)', (t) async {
    final rig = LibraryRig();
    final target = await rig.addTarget('warm');
    await rig.addContent(target, postedAt: DateTime(2026, 11, 20, 9));
    await pumpLibrary(t, rig, size: const Size(400, 800));
    expect(find.byType(StoryThumb), findsOneWidget);
  });

  for (final perDay in [25, 5, 2, 1]) {
    testWidgets('5000 items, $perDay per day, open time and built widgets', (
      t,
    ) async {
      final rig = LibraryRig();
      final targets = [
        for (var i = 0; i < 20; i++) await rig.addTarget('account_$i'),
      ];
      final base = DateTime(2026, 11, 20, 11);
      final items = [
        for (var i = 0; i < 5000; i++)
          _item(
            i,
            targets[i % 20].id,
            DateTime(base.year, base.month, base.day - i ~/ perDay, 11),
          ),
      ];
      final sw = Stopwatch()..start();
      await pumpLibrary(
        t,
        rig,
        size: const Size(400, 800),
        extra: [allContentProvider.overrideWith((ref) => Stream.value(items))],
      );
      sw.stop();
      final headers = find.byType(DateHeader).evaluate().length;
      final tiles = find.byType(StoryThumb).evaluate().length;
      // ignore: avoid_print, evidence for the QA report.
      print(
        'QA-PERF perDay=$perDay: ${sw.elapsedMilliseconds} ms, '
        'date headers built=$headers, tiles built=$tiles',
      );
      expect(tiles, lessThan(60));
      expect(headers, lessThan(60));
      // F4 fixed: the rows are one flat lazy list, so the open time does
      // not depend on how many distinct days there are.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  }

  testWidgets('5000 items through the real in-memory repo stream', (t) async {
    final rig = LibraryRig();
    final targets = [
      for (var i = 0; i < 20; i++) await rig.addTarget('account_$i'),
    ];
    final base = DateTime(2026, 11, 20, 11);
    final seed = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      await rig.addContent(
        targets[i % 20],
        postedAt: base.subtract(Duration(minutes: 7 * i)),
      );
    }
    seed.stop();
    final sw = Stopwatch()..start();
    await pumpLibrary(t, rig, size: const Size(400, 800));
    sw.stop();
    // ignore: avoid_print, evidence for the QA report.
    print(
      'QA-PERF real fake-repo stream: ${sw.elapsedMilliseconds} ms '
      '(seeding took ${seed.elapsedMilliseconds} ms), '
      'tiles=${find.byType(StoryThumb).evaluate().length}',
    );
    expect(find.byType(StoryThumb).evaluate().length, lessThan(60));
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });
}
