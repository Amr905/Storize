import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

/// NFR-12: 5,000 items open in under 1 s.
///
/// The test measures the wall-clock time from `pumpWidget` to the settled
/// first screen, in a debug-mode widget test, with the repo stream replaced by
/// a ready list (the DB query has its own perf test in T-005/T-006) and no
/// real image decoding (the thumb builder is a gradient).
///
/// The budget is the NFR itself (1 s). This measures only the widget side:
/// layout and build of the first screen from a ready in-memory list, in the
/// JIT of a widget test on the Claude workspace (about 150-250 ms there). It
/// does NOT measure the real drift `watchLibrary` query (the sort and the
/// media join), the thumbnail decoding, or a phone CPU. T-037 measures the
/// real path on a device. If CI proves flaky, raise [budget] rather than skip
/// the test. The rows are one flat lazy list with known extents, so the cost
/// does not grow with the item count or the number of days (see the QA perf
/// test); the other two tests check that only the visible tiles are built.
const Duration budget = Duration(milliseconds: 1000);

List<ContentWithMedia> _items(int count, List<Target> targets) {
  final base = DateTime(2026, 11, 20, 11);
  return [
    for (var i = 0; i < count; i++)
      ContentWithMedia(
        Content(
          id: i + 1,
          targetId: targets[i % targets.length].id,
          kind: ContentKind.story,
          remoteId: 'r$i',
          postedAt: base.subtract(Duration(minutes: 7 * i)).toUtc(),
          slideCount: 1,
          detectedAt: base.toUtc(),
          viewed: i % 3 != 0,
          status: ContentStatus.done,
        ),
        [
          MediaFile(
            id: i + 1,
            contentId: i + 1,
            slideIndex: 0,
            mediaType: i.isEven ? MediaType.photo : MediaType.video,
            sourceUrl: 'https://example.invalid/$i',
            status: MediaFileStatus.done,
            contentUri: 'content://fake/$i',
            thumbPath: '/thumbs/$i.webp',
            durationMs: i.isEven ? null : 9000,
          ),
        ],
      ),
  ];
}

Future<Duration> _open(WidgetTester t, int count) async {
  final rig = LibraryRig();
  final targets = [
    for (var i = 0; i < 20; i++) await rig.addTarget('account_$i'),
  ];
  final items = _items(count, targets);
  final sw = Stopwatch()..start();
  await pumpLibrary(
    t,
    rig,
    size: const Size(400, 800),
    extra: [allContentProvider.overrideWith((ref) => Stream.value(items))],
  );
  sw.stop();
  expect(find.byType(StoryThumb), findsWidgets);
  return sw.elapsed;
}

void main() {
  testWidgets('5,000 items open within the budget (NFR-12)', (t) async {
    // Warm up the JIT and the theme once, then measure.
    await _open(t, 50);
    await t.pumpWidget(const SizedBox());
    final elapsed = await _open(t, 5000);
    // ignore: avoid_print, the measured time is the evidence reported to QA.
    print(
      'NFR-12: 5000 items opened in ${elapsed.inMilliseconds} ms '
      '(budget ${budget.inMilliseconds} ms)',
    );
    expect(elapsed, lessThan(budget));
  });

  testWidgets('only the visible tiles are built', (t) async {
    await _open(t, 5000);
    // A phone screen shows a few dozen tiles, not 5,000.
    expect(find.byType(StoryThumb).evaluate().length, lessThan(60));
    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('scrolling a long list stays lazy', (t) async {
    await _open(t, 5000);
    await t.fling(find.byType(CustomScrollView), const Offset(0, -3000), 8000);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(StoryThumb).evaluate().length, lessThan(60));
  });
}
