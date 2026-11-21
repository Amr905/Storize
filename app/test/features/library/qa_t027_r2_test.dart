// QA evidence file: long diagnostic strings and step-by-step router calls.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/library/library_tile.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

// QA round 2 for T-027: F3 adversarial probes and F4 sticky/lazy probes.

Finder _tiles() => find.byType(StoryThumb);
const _deleteTip = 'Delete (deletes from your gallery too)';

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

/// [count] items, one per day, newest first.
List<ContentWithMedia> _daily(int count, List<Target> targets) {
  final base = DateTime(2026, 11, 20, 11);
  return [
    for (var i = 0; i < count; i++)
      _item(
        i,
        targets[i % targets.length].id,
        DateTime(base.year, base.month, base.day - i, 11),
      ),
  ];
}

void main() {
  group('F3 probes', () {
    testWidgets('selection survives leaving the page; ghosts are dropped', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), {1, 2});
      final router = GoRouter.of(t.element(find.byType(LibraryPage)));
      router.go('/account');
      await t.pumpAndSettle();
      expect(find.byType(LibraryPage), findsNothing);
      // While the page is away another part of the app removes row 1.
      await rig.content.deleteByIds([1]);
      await t.pump();
      router.go('/');
      await t.pumpAndSettle();
      // The selection provider outlived the page. It must not claim a row
      // that is gone.
      final sel = c.read(librarySelectionProvider);
      final bar = find.textContaining(' selected');
      // ignore: avoid_print, evidence for the report.
      print(
        'QA-R2 after remount: selection=$sel bar=${t.widgetList<Text>(bar).map((e) => e.data).toList()}',
      );
      expect(sel.contains(1), isFalse, reason: 'ghost id 1 still selected');
    });

    testWidgets('a deep link to another kind ends the selection', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.pumpAndSettle();
      final router = GoRouter.of(t.element(find.byType(LibraryPage)));
      router.go('/');
      await t.pumpAndSettle();
      c.read(libraryKindProvider.notifier).select(LibraryKind.posts);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
    });

    testWidgets('data change mid-delete: kept ids and the bar stay honest', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.tap(_tiles().at(1));
      await t.tap(_tiles().at(2));
      await t.pumpAndSettle();
      rig.gallery.failNextDelete(const GalleryPermissionDenied());
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      // Another part of the app removes content 3 while the dialog is open.
      await rig.content.deleteByIds([3]);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), {1, 2});
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      final sel = c.read(librarySelectionProvider);
      // One failed (kept selected), one deleted; nothing outside the screen.
      final all = await rig.content.getByIds([1, 2, 3]);
      final present = {for (final i in all) i.content.id};
      expect(sel.difference(present), isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('a filter change during a running delete', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.pumpAndSettle();
      rig.gallery.failNextDelete(const GalleryPermissionDenied());
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      // The user taps an account chip right away (chips are not disabled).
      await t.tap(find.textContaining('@nour_k').first, warnIfMissed: false);
      await t.pumpAndSettle();
      // ignore: avoid_print, evidence for the report.
      print(
        'QA-R2 filter-mid-delete: selection=${c.read(librarySelectionProvider)} '
        'filters=${c.read(libraryFiltersProvider).targetIds}',
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('pull-to-refresh during selection keeps the selection', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig, size: const Size(400, 800));
      await t.longPress(_tiles().at(0));
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      final gate = Completer<CheckNowResult>();
      rig.checkNow.gate = () => gate.future;
      await pullToRefresh(t);
      expect(rig.checkNow.calls, 1);
      expect(c.read(librarySelectionProvider), {1, 2});
      // New content arrives during the check.
      await rig.addContent(
        rig.byName['nour_k']!,
        postedAt: DateTime(2026, 11, 20, 11, 30),
      );
      gate.complete(const CheckNowResult(newItems: 1));
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), {1, 2});
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.textContaining('Check finished'), findsOneWidget);
    });

    testWidgets('an item that blinks out and back is not selected again', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final all = await rig.content.getByIds([for (var i = 1; i <= 13; i++) i]);
      final ctrl = StreamController<List<ContentWithMedia>>();
      addTearDown(ctrl.close);
      ctrl.onListen = () => ctrl.add(all);
      final c = await pumpLibrary(
        t,
        rig,
        extra: [allContentProvider.overrideWith((ref) => ctrl.stream)],
      );
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      final firstId = c.read(librarySelectionProvider).single;
      // The list loses the item, then gets it back.
      ctrl.add([
        for (final i in all)
          if (i.content.id != firstId) i,
      ]);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
      ctrl.add(all);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
      expect(find.textContaining(' selected'), findsNothing);
    });

    testWidgets('an empty emission mid-selection ends it cleanly', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final all = await rig.content.getByIds([for (var i = 1; i <= 13; i++) i]);
      final ctrl = StreamController<List<ContentWithMedia>>();
      addTearDown(ctrl.close);
      ctrl.onListen = () => ctrl.add(all);
      final c = await pumpLibrary(
        t,
        rig,
        extra: [allContentProvider.overrideWith((ref) => ctrl.stream)],
      );
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      ctrl.add(const []);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
      expect(t.takeException(), isNull);
    });
  });

  group('F4 probes', () {
    Future<List<Target>> targets(LibraryRig rig) async => [
      for (var i = 0; i < 5; i++) await rig.addTarget('account_$i'),
    ];

    String labelFor(WidgetTester t, int id, DateTime now) {
      final ctx = t.element(find.byType(LibraryPage));
      final base = DateTime(2026, 11, 20);
      final day = DateTime(base.year, base.month, base.day - (id - 1));
      return libraryDayLabel(ctx, day, now);
    }

    /// The sticky overlay must name the day of the first tile under it.
    void expectStickyMatches(WidgetTester t, {required String where}) {
      final top = t.getTopLeft(find.byType(Scaffold).first).dy + kToolbarHeight;
      // First tile whose bottom is below the overlay's bottom edge.
      LibraryTile? first;
      var best = double.infinity;
      for (final e in find.byType(LibraryTile).evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        if (r.bottom > top + 1 && r.top < best) {
          best = r.top;
          first = e.widget as LibraryTile;
        }
      }
      expect(first, isNotNull, reason: where);
      final id = first!.item.content.id;
      final want = labelFor(t, id, first.now);
      final headers = t.widgetList<DateHeader>(find.byType(DateHeader)).where((
        h,
      ) {
        final r = t.getRect(find.byWidget(h));
        return (r.top - top).abs() < 1;
      }).toList();
      expect(headers, isNotEmpty, reason: '$where: no overlay at the top');
      expect(headers.last.label, want, reason: '$where: tile id $id');
    }

    for (final (scale, dir) in [
      (1.0, TextDirection.ltr),
      (2.0, TextDirection.ltr),
      (3.0, TextDirection.rtl),
    ]) {
      testWidgets('sticky day: scale $scale ${dir.name}, jumps and drags', (
        t,
      ) async {
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final rig = LibraryRig();
        final ts = await targets(rig);
        final items = _daily(3000, ts);
        await pumpLibrary(
          t,
          rig,
          direction: dir,
          size: const Size(400, 800),
          extra: [
            allContentProvider.overrideWith((ref) => Stream.value(items)),
          ],
        );
        expect(t.takeException(), isNull);
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        final pos = scroll.position;
        for (final frac in [0.0, 0.01, 0.37, 0.9, 0.5, 1.0, 0.0001]) {
          pos.jumpTo(
            (pos.maxScrollExtent * frac).clamp(0, pos.maxScrollExtent),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'frac $frac');
          if (frac * pos.maxScrollExtent > 200) {
            expectStickyMatches(t, where: 'scale $scale frac $frac');
          }
          expect(find.byType(LibraryTile).evaluate().length, lessThan(60));
        }
        pos.jumpTo(50000);
        await t.pumpAndSettle();
        await t.drag(find.byType(Scrollable).first, const Offset(0, -137));
        await t.pumpAndSettle();
        expectStickyMatches(t, where: 'after drag');
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('50,000 items: open, built widgets, per-frame cost', (
      t,
    ) async {
      final rig = LibraryRig();
      final ts = await targets(rig);
      final items = [
        for (var i = 0; i < 50000; i++)
          _item(
            i,
            ts[i % 5].id,
            DateTime(2026, 11, 20, 11).subtract(Duration(hours: 7 * i)),
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
      // ignore: avoid_print, evidence for the report.
      print(
        'QA-R2 50k open: ${sw.elapsedMilliseconds} ms, tiles '
        '${find.byType(LibraryTile).evaluate().length}, '
        'headers ${find.byType(DateHeader).evaluate().length}',
      );
      expect(find.byType(LibraryTile).evaluate().length, lessThan(60));
      expect(find.byType(DateHeader).evaluate().length, lessThan(30));
      // Per-frame cost while scrolling: 60 small drags.
      final scroll = find.byType(Scrollable).first;
      final frames = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        await t.drag(scroll, const Offset(0, -40));
        await t.pump(const Duration(milliseconds: 16));
      }
      frames.stop();
      // ignore: avoid_print, evidence for the report.
      print('QA-R2 50k: 60 scroll frames in ${frames.elapsedMilliseconds} ms');
      expect(find.byType(LibraryTile).evaluate().length, lessThan(60));
    });

    for (final n in [500, 500, 5000, 50000, 150000]) {
      testWidgets('per-frame scroll cost with $n items', (t) async {
        final rig = LibraryRig();
        final ts = await targets(rig);
        final items = [
          for (var i = 0; i < n; i++)
            _item(
              i,
              ts[i % 5].id,
              DateTime(2026, 11, 20, 11).subtract(Duration(hours: 7 * i)),
            ),
        ];
        final open = Stopwatch()..start();
        await pumpLibrary(
          t,
          rig,
          size: const Size(400, 800),
          extra: [
            allContentProvider.overrideWith((ref) => Stream.value(items)),
          ],
        );
        open.stop();
        final scroll = find.byType(Scrollable).first;
        final frames = Stopwatch()..start();
        for (var i = 0; i < 200; i++) {
          await t.drag(scroll, const Offset(0, -40));
          await t.pump(const Duration(milliseconds: 16));
        }
        frames.stop();
        // ignore: avoid_print, evidence for the report.
        print(
          'QA-R2 n=$n: open ${open.elapsedMilliseconds} ms, '
          '200 frames ${frames.elapsedMilliseconds} ms',
        );
      });
    }
  });
}
