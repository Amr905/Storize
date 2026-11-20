import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

Finder _tiles() => find.byType(StoryThumb);

void main() {
  group('kind switch and tiles (AC1, AC2)', () {
    testWidgets('shows unviewed counts and 9:16 story tiles', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);

      final switchWidget = t.widget<KindSwitch>(find.byType(KindSwitch));
      expect(switchWidget.storiesCount, 3);
      expect(switchWidget.postsCount, 2);
      expect(find.text('Stories'), findsWidgets);
      expect(_tiles(), findsNWidgets(9));
      final size = t.getSize(_tiles().first);
      expect(size.width / size.height, closeTo(9 / 16, 0.02));
      expect(find.byType(PostThumb), findsNothing);
      expect(find.text('0:12'), findsOneWidget);
      expect(find.text('3 new'), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Yesterday'), findsWidgets);
    });

    testWidgets('Posts shows square tiles with a carousel badge', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();

      expect(find.byType(PostThumb), findsNWidgets(4));
      final size = t.getSize(find.byType(PostThumb).first);
      expect(size.width / size.height, closeTo(1, 0.02));
      expect(find.byIcon(Icons.collections_rounded), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('0:15'), findsOneWidget);
    });

    testWidgets('route kind=post opens on Posts', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig, kind: ContentKind.post);
      await t.pumpAndSettle();
      expect(find.byType(PostThumb), findsNWidgets(4));
    });

    testWidgets('route target=ID filters to that account', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final nour = rig.byName['nour_k']!;
      await pumpLibrary(t, rig, targetId: nour.id);
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(3));
    });
  });

  group('tile semantics (AC2, AC10)', () {
    testWidgets('label has account, type, time and new / selected', (t) async {
      final handle = t.ensureSemantics();
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);

      expect(
        find.bySemanticsLabel(
          RegExp(r'^Story by nour_k, video, 0:12, Today 9:30.*, new$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('^Story by client_co, video, 0:21, Yesterday 12:00.*'),
        ),
        findsOneWidget,
      );
      // Viewed tiles do not say "new".
      expect(
        find.bySemanticsLabel(RegExp(r'^Story by brandx, photo,.*, new$')),
        findsNothing,
      );
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r', new, selected$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('post label names the carousel size', (t) async {
      final handle = t.ensureSemantics();
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig, kind: ContentKind.post);
      await t.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('^Post by nour_k, carousel, 4 items')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('sticky day header', () {
    testWidgets('the current day stays on top while scrolling', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      // More of yesterday, so its header can reach the top edge.
      for (var i = 0; i < 9; i++) {
        await rig.addContent(
          rig.byName['client_co']!,
          postedAt: DateTime(2026, 11, 19, 8, i),
        );
      }
      await pumpLibrary(t, rig, size: const Size(400, 400));
      double? topOf(String label) {
        final ys = [
          for (final e in find.text(label).evaluate())
            t.getTopLeft(find.byWidget(e.widget)).dy,
        ];
        return ys.isEmpty ? null : ys.reduce((a, b) => a < b ? a : b);
      }

      final list = find.byType(CustomScrollView);
      // At the top the inline "Today" header is the only one.
      expect(find.text('Today'), findsOneWidget);
      // Scroll past the start of today's group: the label is still on top.
      await t.drag(list, const Offset(0, -300));
      await t.pumpAndSettle();
      expect(topOf('Today'), lessThan(80));
      // Scroll into yesterday: the label changes.
      await t.drag(list, const Offset(0, -700));
      await t.pumpAndSettle();
      expect(topOf('Yesterday'), lessThan(80));
      // Back at the top the overlay is gone again.
      await t.drag(list, const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tapping a story opens the story viewer', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(_tiles().first);
      await t.pumpAndSettle();
      expect(find.textContaining('story '), findsOneWidget);
    });

    testWidgets('tapping a post opens the post viewer', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig, kind: ContentKind.post);
      await t.pumpAndSettle();
      await t.tap(find.byType(PostThumb).first);
      await t.pumpAndSettle();
      expect(find.textContaining('post '), findsOneWidget);
    });
  });

  group('filters (AC3)', () {
    testWidgets('account chip filters and All clears', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.textContaining('@brandx').first);
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(3));
      await t.tap(find.text('All').first);
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(9));
    });

    testWidgets('sheet: accounts, date, type, then Apply', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('filter-account-1')));
      await t.tap(find.byKey(const ValueKey('filter-date-today')));
      await t.tap(find.byKey(const ValueKey('filter-type-videos')));
      await t.pumpAndSettle();
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();

      // nour_k, today, video: exactly the 0:12 story.
      expect(_tiles(), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      // Active filters appear as removable chips.
      expect(find.byKey(const ValueKey('active-filter-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('active-filter-type')), findsOneWidget);

      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('active-filter-type')),
          matching: find.byTooltip('Remove filter'),
        ),
      );
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(3));
    });

    testWidgets('sheet kind chip mirrors the switch', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-kind-posts')));
      await t.pumpAndSettle();
      // Carousel and reel types exist for posts only.
      expect(
        find.byKey(const ValueKey('filter-type-carousels')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('filter-type-carousels')));
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(find.byType(PostThumb), findsOneWidget);
    });

    testWidgets('sheet type filter hides carousel and reel for stories', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('filter-type-carousels')), findsNothing);
      expect(find.byKey(const ValueKey('filter-type-reels')), findsNothing);
    });

    testWidgets('Clear resets the sheet', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-date-today')));
      await t.tap(find.text('Clear'));
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('active-filter-date')), findsNothing);
      expect(_tiles(), findsNWidgets(9));
    });

    testWidgets('custom range uses the picker and filters by day', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-date-custom')));
      await t.pumpAndSettle();
      // The picker opens with today as the last selectable day.
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await t.tap(find.text('19'));
      await t.pumpAndSettle();
      await t.tap(find.text('19'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      // Only yesterday's three client_co stories.
      expect(_tiles(), findsNWidgets(3));
    });

    testWidgets('the future cannot be picked', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-date-custom')));
      await t.pumpAndSettle();
      // Day 21 is after "today" (20 Nov): its button is disabled.
      final day21 = find.ancestor(
        of: find.text('21'),
        matching: find.byType(InkResponse),
      );
      if (day21.evaluate().isNotEmpty) {
        expect(t.widget<InkResponse>(day21.first).onTap, isNull);
      }
    });
  });

  group('selection, delete, share (AC4)', () {
    testWidgets('long press starts selection; tap toggles; close exits', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      // Tapping in selection mode does not navigate.
      expect(find.textContaining('story '), findsNothing);
      await t.tap(find.byTooltip('Cancel selection'));
      await t.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('system back leaves selection mode first', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('delete asks first, then removes rows and gallery files', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Delete (deletes from your gallery too)'));
      await t.pumpAndSettle();
      expect(find.text('Delete 2 items?'), findsOneWidget);
      expect(
        find.text(
          "They'll also be removed from your gallery. This can't be undone.",
        ),
        findsOneWidget,
      );
      // Cancel keeps everything.
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(9));
      expect(find.text('2 selected'), findsOneWidget);

      await t.tap(find.byTooltip('Delete (deletes from your gallery too)'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(7));
      expect(find.text('2 items deleted'), findsOneWidget);
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets('a gallery failure shows "N couldn\'t be deleted"', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      rig.gallery.failNextDelete(const GalleryPermissionDenied());
      await t.longPress(_tiles().at(0));
      await t.tap(_tiles().at(1));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Delete (deletes from your gallery too)'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text("1 deleted, 1 couldn't be deleted"), findsOneWidget);
      // The kept item is still in the library and still selected.
      expect(_tiles(), findsNWidgets(8));
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('share goes through ShareService with saved files', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().at(0));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Share'));
      await t.pumpAndSettle();
      expect(rig.share.calls, hasLength(1));
      expect(
        rig.share.calls.single.single.contentUri,
        startsWith('content://'),
      );
      expect(find.text('1 selected'), findsNothing);
    });

    testWidgets('share with nothing downloaded says so', (t) async {
      final rig = LibraryRig();
      final nour = await rig.addTarget('nour_k');
      await rig.addContent(
        nour,
        postedAt: DateTime(2026, 11, 20, 10),
        status: MediaFileStatus.pending,
        withUri: false,
      );
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Share'));
      await t.pumpAndSettle();
      expect(rig.share.calls, isEmpty);
      expect(
        find.text('Nothing to share yet. Files are still downloading.'),
        findsOneWidget,
      );
    });

    testWidgets('share failure is reported', (t) async {
      final rig = LibraryRig()..share.error = Exception('boom');
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Share'));
      await t.pumpAndSettle();
      expect(find.text("Couldn't share these items."), findsOneWidget);
    });

    testWidgets('a broken tile offers Remove from library', (t) async {
      final rig = LibraryRig();
      final nour = await rig.addTarget('nour_k');
      await rig.addContent(
        nour,
        postedAt: DateTime(2026, 11, 20, 10),
        status: MediaFileStatus.failed,
        withUri: false,
      );
      await pumpLibrary(t, rig);
      expect(find.text("Can't load"), findsOneWidget);
      await t.tap(_tiles().first);
      await t.pumpAndSettle();
      expect(find.text('This file is missing'), findsOneWidget);
      await t.tap(find.text('Remove from library'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNothing);
    });
  });

  group('pull-to-refresh (AC5)', () {
    testWidgets('runs check now, shows progress then the result', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final gate = Completer<CheckNowResult>();
      rig.checkNow.gate = () => gate.future;
      await pumpLibrary(t, rig, size: const Size(400, 800));

      await pullToRefresh(t);
      expect(rig.checkNow.calls, 1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      gate.complete(const CheckNowResult(newItems: 3));
      await t.pumpAndSettle();
      expect(find.text('Check finished. 3 new items.'), findsOneWidget);
    });

    testWidgets('a failed check says so', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      rig.checkNow.result = const CheckNowResult(failed: true);
      await pumpLibrary(t, rig, size: const Size(400, 800));
      await pullToRefresh(t);
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't check right now. Try again later."),
        findsOneWidget,
      );
    });

    testWidgets('the default action is a stub that completes', (t) async {
      expect(
        await const StubCheckNowAction()(),
        const CheckNowResult(),
      );
      await const NoOpShareService().share(const []);
    });
  });

  group('empty, loading and error states (AC6)', () {
    testWidgets('(a) no targets: Add account', (t) async {
      final rig = LibraryRig();
      await pumpLibrary(t, rig);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('Add an account to start archiving.'), findsOneWidget);
      await t.tap(find.text('Add account'));
      await t.pumpAndSettle();
      expect(find.text('add target'), findsOneWidget);
    });

    testWidgets('(b) waiting for stories with the last check time', (t) async {
      final rig = LibraryRig();
      await rig.addTarget(
        'nour_k',
        lastStoriesCheckAt: DateTime(2026, 11, 20, 10, 42).toUtc(),
      );
      await pumpLibrary(t, rig);
      expect(find.text('No stories yet'), findsOneWidget);
      expect(
        find.text('Waiting for new stories. Last check 10:42 AM.'),
        findsOneWidget,
      );
      await t.tap(find.text('Check now'));
      await t.pumpAndSettle();
      expect(rig.checkNow.calls, 1);
    });

    testWidgets('(b) posts without a last check', (t) async {
      final rig = LibraryRig();
      await rig.addTarget('nour_k');
      await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.text('Waiting for new posts.'), findsOneWidget);
    });

    testWidgets('(c) filters match nothing: Clear filters', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            c.read(libraryFiltersProvider).copyWith(type: TypeFilter.photos),
          );
      // A story filter that nothing passes: only client_co, today.
      final client = rig.byName['client_co']!;
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            c
                .read(libraryFiltersProvider)
                .copyWith(targetIds: {client.id}, date: DatePreset.today),
          );
      await t.pumpAndSettle();
      expect(find.text('No stories match these filters.'), findsOneWidget);
      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(9));
    });

    testWidgets('loading shows the skeleton grid', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final never = StreamController<List<ContentWithMedia>>();
      addTearDown(never.close);
      await pumpLibrary(
        t,
        rig,
        extra: [allContentProvider.overrideWith((ref) => never.stream)],
        settle: false,
      );
      await t.pump();
      expect(find.byType(SkeletonGrid), findsOneWidget);
    });

    testWidgets('error shows Retry, which reloads', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      var fail = true;
      await pumpLibrary(
        t,
        rig,
        extra: [
          allContentProvider.overrideWith((ref) {
            if (fail) return Stream.error(StateError('db'));
            return rig.content.watchLibrary(ContentFilter());
          }),
        ],
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(9));
    });

    testWidgets('unwired providers show the error state, not a crash', (
      t,
    ) async {
      final rig = LibraryRig()..unwiredContent = true;
      await pumpLibrary(t, rig);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  testWidgets('RTL: the page lays out without errors', (t) async {
    final rig = LibraryRig();
    await seedStandard(rig);
    await pumpLibrary(t, rig, direction: TextDirection.rtl);
    expect(_tiles(), findsNWidgets(9));
    expect(t.takeException(), isNull);
  });

  testWidgets('touch targets in the app bar are at least 48 dp', (t) async {
    final rig = LibraryRig();
    await seedStandard(rig);
    await pumpLibrary(t, rig);
    final size = t.getSize(find.byTooltip('Filters'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
