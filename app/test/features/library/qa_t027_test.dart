import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/library/library_view.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

// QA tests for T-027 (independent verification). Tests named "FINDING" pin
// the behaviour found by QA; they describe what the code does today and must
// be updated when the finding is fixed (see docs/05-reviews/T-027.md).

Finder _tiles() => find.byType(StoryThumb);
const _deleteTip = 'Delete (deletes from your gallery too)';

/// Records every gallery delete and can hold them.
class SpyGallery implements GalleryStore {
  SpyGallery(this.inner);

  final FakeGalleryStore inner;
  final List<String> deletes = [];
  Completer<void>? gate;

  @override
  Future<bool> delete(String contentUri) async {
    deletes.add(contentUri);
    final g = gate;
    if (g != null) await g.future;
    return inner.delete(contentUri);
  }

  @override
  Future<bool> exists(String contentUri) => inner.exists(contentUri);

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
  Future<int?> size(String contentUri) => inner.size(contentUri);
}

/// Fails the gallery delete for the listed URIs.
class SelectiveGallery extends SpyGallery {
  SelectiveGallery(super.inner, this.failing);

  final Set<String> failing;

  @override
  Future<bool> delete(String contentUri) async {
    if (failing.contains(contentUri)) {
      deletes.add(contentUri);
      throw const GalleryPermissionDenied();
    }
    return super.delete(contentUri);
  }
}

Future<Set<int>> _remainingIds(LibraryRig rig) async {
  final found = await rig.content.getByIds([for (var i = 1; i <= 40; i++) i]);
  return {for (final c in found) c.content.id};
}

Future<void> _selectTiles(WidgetTester t, List<int> indexes) async {
  await t.longPress(_tiles().at(indexes.first));
  await t.pumpAndSettle();
  for (final i in indexes.skip(1)) {
    await t.tap(_tiles().at(i));
    await t.pumpAndSettle();
  }
}

/// A rig whose gallery is [spy].
class _SpyRig extends LibraryRig {
  _SpyRig();
  late SpyGallery spy;

  @override
  List<Override> get overrides => [
    targetRepoProvider.overrideWithValue(targets),
    contentRepoProvider.overrideWithValue(content),
    accountRepoProvider.overrideWithValue(accounts),
    galleryStoreProvider.overrideWithValue(spy),
    mediaCacheProvider.overrideWithValue(cache),
    clockProvider.overrideWithValue(clock),
    shareServiceProvider.overrideWithValue(share),
    checkNowActionProvider.overrideWithValue(checkNow),
    libraryThumbBuilderProvider.overrideWithValue(fakeThumb),
  ];
}

Future<ProviderContainer> _pumpWith(
  WidgetTester t,
  LibraryRig rig,
  SpyGallery spy,
) {
  (rig as _SpyRig).spy = spy;
  return pumpLibrary(t, rig);
}

void main() {
  group('delete safety (AC4)', () {
    testWidgets('deletes exactly the selected ids, only after confirming', (
      t,
    ) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      // Tiles 2 and 5 are content 3 and 6: ids, not positions, must flow.
      await _selectTiles(t, [2, 5]);
      expect(spy.deletes, isEmpty);

      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      expect(find.text('Delete 2 items?'), findsOneWidget);
      // Dialog open: still nothing deleted.
      expect(spy.deletes, isEmpty);

      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(spy.deletes.toSet(), {
        'content://fake/3/0',
        'content://fake/6/0',
      });
      expect(spy.deletes, hasLength(2));
      final remaining = await _remainingIds(rig);
      expect(remaining.contains(3), isFalse);
      expect(remaining.contains(6), isFalse);
      expect(remaining, hasLength(11));
      expect(find.text('2 items deleted'), findsOneWidget);
    });

    testWidgets('cancel, barrier tap and back delete nothing', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0, 1]);

      // Cancel button.
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      // Tap outside the dialog (barrier).
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      // System back while the dialog is open.
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(spy.deletes, isEmpty);
      expect(await _remainingIds(rig), hasLength(13));
      // The selection survives a cancelled delete.
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('one item uses the singular title', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await _selectTiles(t, [0]);
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      expect(find.text('Delete 1 item?'), findsOneWidget);
    });

    testWidgets('partial failure: summary counts the kept items', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SelectiveGallery(rig.gallery, {
        'content://fake/1/0',
        'content://fake/2/0',
      });
      final c = await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0, 1, 2]);
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      // Two failed, one deleted: the failed rows stay.
      expect(find.text("1 deleted, 2 couldn't be deleted"), findsOneWidget);
      final remaining = await _remainingIds(rig);
      expect(remaining.containsAll({1, 2}), isTrue);
      expect(remaining.contains(3), isFalse);
      expect(_tiles(), findsNWidgets(8));
      // F2 fixed: the failed items stay selected, the deleted one is gone.
      expect(find.text('2 selected'), findsOneWidget);
      expect(c.read(librarySelectionProvider), {1, 2});
    });

    testWidgets('every item failing reports all of them', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SelectiveGallery(rig.gallery, {
        'content://fake/1/0',
        'content://fake/2/0',
      });
      await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0, 1]);
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text("2 items couldn't be deleted"), findsOneWidget);
      expect(_tiles(), findsNWidgets(9));
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('slide of a carousel: all gallery files of the post go', (
      t,
    ) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      // The first post tile is the 4-slide carousel (content 10).
      await t.longPress(find.byType(PostThumb).first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();
      expect(spy.deletes, hasLength(4));
      expect(
        spy.deletes.every((u) => u.startsWith('content://fake/10/')),
        true,
      );
    });

    testWidgets('tapping Delete in the dialog twice deletes once', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0]);
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Delete');
      await t.tap(confirm);
      await t.pump(const Duration(milliseconds: 16));
      // A second tap in the exit animation must not reach anything.
      if (confirm.evaluate().isNotEmpty) {
        await t.tap(confirm, warnIfMissed: false);
      }
      await t.pumpAndSettle();
      expect(spy.deletes, hasLength(1));
      expect(t.takeException(), isNull);
      // The page is still there (a double pop would have removed it).
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('F1: Delete and Share are disabled while a delete runs', (
      t,
    ) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery)..gate = Completer<void>();
      await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0]);
      await t.tap(find.byTooltip(_deleteTip));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pump(const Duration(milliseconds: 400));
      // The first delete hangs in the gallery: progress shows and the
      // actions are disabled, so a second confirm is impossible.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      IconButton action(IconData icon) =>
          t.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
      expect(action(Icons.delete_outline_rounded).onPressed, isNull);
      expect(action(Icons.share_outlined).onPressed, isNull);
      await t.tap(find.byTooltip(_deleteTip), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Delete 1 item?'), findsNothing);
      // Tiles ignore taps too.
      await t.tap(_tiles().at(1), warnIfMissed: false);
      await t.pump();
      expect(find.text('1 selected'), findsOneWidget);
      spy.gate!.complete();
      await t.pumpAndSettle();
      expect(spy.deletes, ['content://fake/1/0']);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('F3: a kind switch ends selection mode', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      final c = await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0]);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
      expect(find.textContaining('selected'), findsNothing);
      expect(find.byTooltip(_deleteTip), findsNothing);
      expect(spy.deletes, isEmpty);
    });

    testWidgets('F3: an account chip ends selection mode', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await _selectTiles(t, [0, 1]); // nour_k, ids 1 and 2
      await t.tap(find.textContaining('@brandx').first);
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(3));
      expect(c.read(librarySelectionProvider), isEmpty);
      expect(find.byTooltip(_deleteTip), findsNothing);
    });

    testWidgets('F3: the filter sheet ends selection mode', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await _selectTiles(t, [0]);
      // The Filters action is replaced by the selection actions, so change
      // the filter through the provider, as the sheet's Apply does.
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            c.read(libraryFiltersProvider).copyWith(type: TypeFilter.videos),
          );
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), isEmpty);
    });

    testWidgets('F3: an item that leaves the screen leaves the selection', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      await _selectTiles(t, [0, 1]);
      expect(find.text('2 selected'), findsOneWidget);
      // Another part of the app (retention, a target removal) deletes row 1.
      await rig.content.deleteByIds([1]);
      await t.pumpAndSettle();
      expect(c.read(librarySelectionProvider), {2});
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('Delete and Share act on the same visible set', (t) async {
      final rig = _SpyRig();
      await seedStandard(rig);
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      await _selectTiles(t, [0, 2]);
      await t.tap(find.byTooltip('Share'));
      await t.pumpAndSettle();
      expect(
        rig.share.calls.single.map((f) => f.contentUri).toSet(),
        {'content://fake/1/0', 'content://fake/3/0'},
      );
    });

    testWidgets('broken tile: cancel keeps it, confirm removes only it', (
      t,
    ) async {
      final rig = _SpyRig();
      final nour = await rig.addTarget('nour_k');
      await rig.addContent(
        nour,
        postedAt: DateTime(2026, 11, 20, 10),
        status: MediaFileStatus.failed,
        withUri: false,
      );
      await rig.addContent(nour, postedAt: DateTime(2026, 11, 20, 9));
      final spy = SpyGallery(rig.gallery);
      await _pumpWith(t, rig, spy);
      await t.tap(_tiles().first);
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(2));
      await t.tap(_tiles().first);
      await t.pumpAndSettle();
      await t.tap(find.text('Remove from library'));
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(1));
      // The healthy item's file was not touched.
      expect(spy.deletes, isNot(contains('content://fake/2/0')));
    });
  });

  group('filters (AC3)', () {
    final t1 = Target(
      id: 1,
      platform: PlatformId.instagram,
      remoteUserId: 'u1',
      username: 'a',
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
    );
    final t2 = Target(
      id: 2,
      platform: PlatformId.instagram,
      remoteUserId: 'u2',
      username: 'b',
      category: TargetCategory.ownClient,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
    );
    // Local "now": 2026-11-20 12:00.
    final now = DateTime(2026, 11, 20, 12).toUtc();

    ContentWithMedia item(
      int id,
      int target,
      DateTime local, {
      ContentKind kind = ContentKind.story,
      PostType? postType,
      MediaType media = MediaType.photo,
    }) => ContentWithMedia(
      Content(
        id: id,
        targetId: target,
        kind: kind,
        remoteId: 'r$id',
        postedAt: local.toUtc(),
        slideCount: 1,
        detectedAt: local.toUtc(),
        status: ContentStatus.done,
        postType: kind == ContentKind.post
            ? (postType ?? PostType.photo)
            : null,
        shortcode: kind == ContentKind.post ? 's$id' : null,
      ),
      [
        MediaFile(
          id: id,
          contentId: id,
          slideIndex: 0,
          mediaType: media,
          sourceUrl: 'https://example.invalid/$id',
          status: MediaFileStatus.done,
        ),
      ],
    );

    Set<int> ids(
      List<ContentWithMedia> all,
      LibraryKind kind,
      LibraryFilters f,
    ) => buildLibraryView(
      all: all,
      targets: [t1, t2],
      kind: kind,
      filters: f,
      now: now,
    ).items.map((e) => e.content.id).toSet();

    test('Today: local midnight is in, one millisecond before is out', () {
      final all = [
        item(1, 1, DateTime(2026, 11, 20)),
        item(2, 1, DateTime(2026, 11, 19, 23, 59, 59, 999)),
        item(3, 1, DateTime(2026, 11, 20, 11, 59)),
      ];
      expect(
        ids(all, LibraryKind.stories, LibraryFilters(date: DatePreset.today)),
        {1, 3},
      );
    });

    test('7 and 30 days count local days, today included', () {
      final all = [
        item(1, 1, DateTime(2026, 11, 14)), // 6 days ago, 00:00
        item(2, 1, DateTime(2026, 11, 13, 23, 59)), // 7 days ago, late
        item(3, 1, DateTime(2026, 10, 22)), // 29 days ago
        item(4, 1, DateTime(2026, 10, 21, 23, 59)), // 30 days ago
      ];
      expect(
        ids(all, LibraryKind.stories, LibraryFilters(date: DatePreset.days7)),
        {1},
      );
      expect(
        ids(all, LibraryKind.stories, LibraryFilters(date: DatePreset.days30)),
        {1, 2, 3},
      );
    });

    test('presets stay local across a month, year and DST change', () {
      // "Now" on 1 January: 7 days reaches back into the old year.
      final jan = DateTime(2027, 1, 1, 9).toUtc();
      final all = [
        item(1, 1, DateTime(2026, 12, 26)),
        item(2, 1, DateTime(2026, 12, 25, 23, 59)),
      ];
      final v = buildLibraryView(
        all: all,
        targets: [t1],
        kind: LibraryKind.stories,
        filters: LibraryFilters(date: DatePreset.days7),
        now: jan,
      );
      expect(v.items.map((e) => e.content.id), [1]);
      // 30 days over the first Sunday of November (US DST end).
      final nov = DateTime(2026, 11, 3, 9).toUtc();
      final v30 = buildLibraryView(
        all: [
          item(1, 1, DateTime(2026, 10, 5)), // 29 days before 3 Nov
          item(2, 1, DateTime(2026, 10, 4, 23, 30)),
        ],
        targets: [t1],
        kind: LibraryKind.stories,
        filters: LibraryFilters(date: DatePreset.days30),
        now: nov,
      );
      expect(v30.items.map((e) => e.content.id), [1]);
    });

    test('custom range: inclusive of both days, single day works', () {
      final all = [
        item(1, 1, DateTime(2026, 11, 10)),
        item(2, 1, DateTime(2026, 11, 12, 23, 59, 59)),
        item(3, 1, DateTime(2026, 11, 13)),
        item(4, 1, DateTime(2026, 11, 9, 23, 59)),
      ];
      LibraryFilters range(DateTime a, DateTime b) => LibraryFilters(
        date: DatePreset.custom,
        customFrom: a,
        customTo: b,
      );
      expect(
        ids(
          all,
          LibraryKind.stories,
          range(DateTime(2026, 11, 10), DateTime(2026, 11, 12)),
        ),
        {1, 2},
      );
      expect(
        ids(
          all,
          LibraryKind.stories,
          range(DateTime(2026, 11, 13, 17), DateTime(2026, 11, 13, 3)),
        ),
        {3},
        reason: 'the time of day in the picked dates is ignored',
      );
    });

    test('combinations: account + type + date narrow together', () {
      final all = [
        item(1, 1, DateTime(2026, 11, 20, 9), media: MediaType.video),
        item(2, 1, DateTime(2026, 11, 20, 8)),
        item(3, 2, DateTime(2026, 11, 20, 7), media: MediaType.video),
        item(4, 1, DateTime(2026, 11, 1, 7), media: MediaType.video),
        item(
          5,
          1,
          DateTime(2026, 11, 20, 6),
          kind: ContentKind.post,
          postType: PostType.reel,
          media: MediaType.video,
        ),
      ];
      final f = LibraryFilters(
        targetIds: const {1},
        type: TypeFilter.videos,
        date: DatePreset.days7,
      );
      expect(ids(all, LibraryKind.stories, f), {1});
      // Posts: reels are videos too; the story ids are excluded by the kind.
      expect(ids(all, LibraryKind.posts, f), {5});
      expect(
        ids(
          all,
          LibraryKind.posts,
          LibraryFilters(type: TypeFilter.carousels, targetIds: const {1}),
        ),
        isEmpty,
      );
    });

    test('unviewed counts ignore every filter, per kind', () {
      final all = [
        item(1, 1, DateTime(2026, 11, 20, 9)),
        item(2, 2, DateTime(2026, 11, 1, 9)),
        item(3, 2, DateTime(2026, 11, 20, 9), kind: ContentKind.post),
      ];
      final v = buildLibraryView(
        all: all,
        targets: [t1, t2],
        kind: LibraryKind.stories,
        filters: LibraryFilters(
          targetIds: const {1},
          date: DatePreset.today,
          type: TypeFilter.videos,
        ),
        now: now,
      );
      expect(v.itemCount, 0);
      expect(v.unviewedStories, 2);
      expect(v.unviewedPosts, 1);
    });

    testWidgets('the sheet enforces no future date: last day is today', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-date-custom')));
      await t.pumpAndSettle();
      final picker = t.widget<DateRangePickerDialog>(
        find.byType(DateRangePickerDialog),
      );
      expect(picker.lastDate, DateTime(2026, 11, 20));
    });

    testWidgets('(c) vs (b): filtered-out versus nothing of this kind', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      // An account with no stories and no posts.
      final empty = await rig.addTarget('quiet');
      final c = await pumpLibrary(t, rig);
      c
          .read(libraryFiltersProvider.notifier)
          .replace(LibraryFilters(targetIds: {empty.id}));
      await t.pumpAndSettle();
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Check now'), findsNothing);
      c.read(libraryFiltersProvider.notifier).clear();
      await t.pumpAndSettle();
      expect(_tiles(), findsNWidgets(9));
    });

    testWidgets('filters active but this kind has none: (b), not (c)', (
      t,
    ) async {
      final rig = LibraryRig();
      final nour = await rig.addTarget('nour_k');
      await rig.addContent(nour, postedAt: DateTime(2026, 11, 20, 9));
      final c = await pumpLibrary(t, rig);
      c.read(libraryKindProvider.notifier).select(LibraryKind.posts);
      c
          .read(libraryFiltersProvider.notifier)
          .replace(LibraryFilters(targetIds: {nour.id}));
      await t.pumpAndSettle();
      expect(find.text('Check now'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('unviewed badges do not move when a filter hides items', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final c = await pumpLibrary(t, rig);
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            LibraryFilters(date: DatePreset.today, type: TypeFilter.videos),
          );
      await t.pumpAndSettle();
      final sw = t.widget<KindSwitch>(find.byType(KindSwitch));
      expect(sw.storiesCount, 3);
      expect(sw.postsCount, 2);
    });
  });

  group('states (AC5, AC6)', () {
    testWidgets('a failing check shows the failure, then the next works', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      rig.checkNow.gate = () async => throw StateError('boom');
      await pumpLibrary(t, rig, size: const Size(400, 800));
      await pullToRefresh(t);
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't check right now. Try again later."),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      rig.checkNow.gate = null;
      await t.pump(const Duration(seconds: 5));
      await pullToRefresh(t);
      await t.pumpAndSettle();
      expect(find.textContaining('Check finished'), findsOneWidget);
      expect(rig.checkNow.calls, 2);
    });

    testWidgets('a second pull while checking runs one check', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final gate = Completer<CheckNowResult>();
      rig.checkNow.gate = () => gate.future;
      await pumpLibrary(t, rig, size: const Size(400, 800));
      await pullToRefresh(t);
      await pullToRefresh(t);
      expect(rig.checkNow.calls, 1);
      gate.complete(const CheckNowResult());
      await t.pumpAndSettle();
    });

    testWidgets('unwired target repo also shows the error state', (t) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(
        t,
        rig,
        extra: [
          libraryTargetsProvider.overrideWith(
            (ref) => Stream<List<Target>>.error(StateError('x')),
          ),
        ],
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('accessibility (AC2)', () {
    testWidgets('tiles expose a label, new and selected use the DS strings', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      final handle = t.ensureSemantics();
      await pumpLibrary(t, rig);
      final first = t.getSemantics(_tiles().first);
      expect(first.label, contains('nour_k'));
      expect(first.label, contains('new'));
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      expect(t.getSemantics(_tiles().first).label, contains('selected'));
      handle.dispose();
    });

    testWidgets('tiles are at least 48 dp (smallest is a story tile)', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedStandard(rig);
      await pumpLibrary(t, rig, size: const Size(360, 800));
      for (final e in _tiles().evaluate()) {
        final s = t.getSize(find.byWidget(e.widget));
        expect(s.width, greaterThanOrEqualTo(48));
        expect(s.height, greaterThanOrEqualTo(48));
      }
      for (final tip in ['Filters']) {
        final s = t.getSize(find.byTooltip(tip));
        expect(s.shortestSide, greaterThanOrEqualTo(48));
      }
      await t.longPress(_tiles().first);
      await t.pumpAndSettle();
      for (final tip in ['Cancel selection', _deleteTip, 'Share']) {
        final s = t.getSize(find.byTooltip(tip));
        expect(s.shortestSide, greaterThanOrEqualTo(48), reason: tip);
      }
    });

    for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
      testWidgets('text scale 1.5x and ${dir.name}: no overflow', (t) async {
        final rig = LibraryRig();
        await seedStandard(rig);
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpLibrary(
          t,
          rig,
          direction: dir,
          size: const Size(360, 800),
        );
        expect(t.takeException(), isNull);
        await t.longPress(_tiles().first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.byTooltip(_deleteTip));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Cancel selection'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Filters'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('text scale 1.5x on the empty and error states', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final rig = LibraryRig();
      await pumpLibrary(t, rig, size: const Size(320, 480));
      expect(t.takeException(), isNull);
    });

    testWidgets('text scale 1.5x on the error state', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final rig2 = LibraryRig()..unwiredContent = true;
      await pumpLibrary(t, rig2, size: const Size(320, 480));
      expect(t.takeException(), isNull);
    });
  });

  group('view building', () {
    test('groupLibrary: a day boundary at local midnight splits groups', () {
      final t1 = Target(
        id: 1,
        platform: PlatformId.instagram,
        remoteUserId: 'u1',
        username: 'a',
        category: TargetCategory.ownClient,
        postsWatermarkAt: DateTime.utc(2026),
        addedAt: DateTime.utc(2026),
      );
      ContentWithMedia at(int id, DateTime local) => ContentWithMedia(
        Content(
          id: id,
          targetId: 1,
          kind: ContentKind.story,
          remoteId: 'r$id',
          postedAt: local.toUtc(),
          slideCount: 1,
          detectedAt: local.toUtc(),
          status: ContentStatus.done,
        ),
        const [],
      );
      final groups = groupLibrary(
        [
          at(3, DateTime(2026, 11, 20)),
          at(2, DateTime(2026, 11, 19, 23, 59, 59)),
          at(1, DateTime(2026, 11, 19)),
        ],
        {1: t1},
      );
      expect(groups.map((g) => g.day), [
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 19),
      ]);
    });
  });
}
