// T-055 (FR-76): the S-04 search field, the active filter chips, the result
// count and the empty state with "Clear filters".
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/ui/ui.dart' show LibraryKind;

import 'library_rig.dart';
import 'library_search_rig.dart';

Finder _chip(String key) => find.byKey(ValueKey(key));

String _count(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('library-result-count'))).data!;

/// Opens search, types [text] and waits out the 300 ms debounce.
Future<void> _search(WidgetTester t, String text) async {
  if (find.byKey(const ValueKey('library-search-field')).evaluate().isEmpty) {
    await t.tap(find.byTooltip('Search'));
    await t.pump();
  }
  await t.enterText(find.byKey(const ValueKey('library-search-field')), text);
  await t.pump(librarySearchDebounce);
  await t.pumpAndSettle();
}

void main() {
  group('search field (AC: search, debounce)', () {
    testWidgets('the search icon opens the field in the app bar', (t) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await pumpLibrary(t, rig);
      expect(find.byKey(const ValueKey('library-search-field')), findsNothing);
      await t.tap(find.byTooltip('Search'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library-search-field')),
        findsOneWidget,
      );
    });

    testWidgets('typing waits 300 ms before the query is committed', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      await t.pumpAndSettle();
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Search'));
      await t.pump();

      await t.enterText(
        find.byKey(const ValueKey('library-search-field')),
        'sunset',
      );
      await t.pump(const Duration(milliseconds: 150));
      await t.enterText(
        find.byKey(const ValueKey('library-search-field')),
        'sunset ',
      );
      await t.pump(const Duration(milliseconds: 299));
      expect(c.read(librarySearchQueryProvider), '');
      expect(_chip('active-filter-search'), findsNothing);

      await t.pump(const Duration(milliseconds: 1));
      await t.pumpAndSettle();
      // Trimmed, committed once, after the last keystroke.
      expect(c.read(librarySearchQueryProvider), 'sunset');
      expect(_chip('active-filter-search'), findsOneWidget);
    });

    testWidgets('the query matches caption and location, case-insensitively', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'SUNSET');
      expect(_count(t), '2 results');
      await _search(t, 'alexandria');
      expect(_count(t), '1 result');
    });

    testWidgets('closing the field ends the search', (t) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'coffee');
      expect(c.read(librarySearchQueryProvider), 'coffee');
      await t.tap(find.byTooltip('Close search'));
      await t.pumpAndSettle();
      expect(c.read(librarySearchQueryProvider), '');
      expect(find.byKey(const ValueKey('library-search-field')), findsNothing);
    });
  });

  group('result count', () {
    testWidgets('shows the count of shown items, singular and plural', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      // No filter or search: no count line.
      expect(_chip('library-result-count'), findsNothing);
      await _search(t, 'sunset');
      expect(_count(t), '2 results');
      await _search(t, 'reel');
      expect(_count(t), '1 result');
    });
  });

  group('chips', () {
    testWidgets('removing the search chip restores the list', (t) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'coffee');
      expect(_count(t), '1 result');
      await t.tap(
        find.descendant(
          of: _chip('active-filter-search'),
          matching: find.byTooltip('Remove filter'),
        ),
      );
      await t.pumpAndSettle();
      expect(c.read(librarySearchQueryProvider), '');
      expect(_chip('active-filter-search'), findsNothing);
      expect(_chip('library-result-count'), findsNothing);
    });

    testWidgets('account, reel and media chips remove one at a time', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      final nour = rig.byName['nour_k']!;
      c.read(libraryKindProvider.notifier).select(LibraryKind.posts);
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            LibraryFilters(
              targetIds: {nour.id},
              reelsOnly: true,
              type: TypeFilter.videos,
            ),
          );
      await t.pumpAndSettle();
      expect(_chip('active-filter-account-${nour.id}'), findsOneWidget);
      expect(_chip('active-filter-reels'), findsOneWidget);
      expect(_chip('active-filter-type'), findsOneWidget);
      expect(_count(t), '1 result');

      await t.tap(
        find.descendant(
          of: _chip('active-filter-reels'),
          matching: find.byTooltip('Remove filter'),
        ),
      );
      await t.pumpAndSettle();
      expect(_chip('active-filter-reels'), findsNothing);
      expect(c.read(libraryFiltersProvider).reelsOnly, isFalse);
      expect(c.read(libraryFiltersProvider).targetIds, {nour.id});
      expect(_chip('active-filter-type'), findsOneWidget);

      await t.tap(
        find.descendant(
          of: _chip('active-filter-account-${nour.id}'),
          matching: find.byTooltip('Remove filter'),
        ),
      );
      await t.pumpAndSettle();
      expect(_chip('active-filter-account-${nour.id}'), findsNothing);
      expect(c.read(libraryFiltersProvider).targetIds, isEmpty);
    });

    testWidgets('Clear all removes every chip and ends the search', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      final nour = rig.byName['nour_k']!;
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'beach');
      c
          .read(libraryFiltersProvider.notifier)
          .replace(
            LibraryFilters(
              targetIds: {nour.id},
              date: DatePreset.days30,
            ),
          );
      await t.pumpAndSettle();
      expect(_chip('active-filter-search'), findsOneWidget);
      expect(_chip('active-filter-date'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('active-filter-clear-all')));
      await t.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(c.read(librarySearchQueryProvider), '');
      expect(c.read(libraryFiltersProvider).isActive, isFalse);
      expect(find.byKey(const ValueKey('library-search-field')), findsNothing);
      expect(_chip('library-result-count'), findsNothing);
    });
  });

  group('empty result', () {
    testWidgets('shows No matches, and Clear filters restores the list', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'zzz-nothing');
      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Try fewer filters.'), findsOneWidget);
      expect(_count(t), '0 results');

      await t.tap(find.text('Clear filters'));
      await t.pumpAndSettle();
      expect(find.text('No matches'), findsNothing);
      expect(_chip('active-filter-search'), findsNothing);
      expect(find.byType(InputChip), findsNothing);
    });
  });

  group('carousels with search', () {
    testWidgets('the carousel type combines with the search and removes', (
      t,
    ) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      final c = await pumpLibrary(t, rig);
      await t.tap(find.text('Posts').first);
      await t.pumpAndSettle();
      await _search(t, 'sunset');
      expect(_count(t), '2 results');
      c
          .read(libraryFiltersProvider.notifier)
          .replace(LibraryFilters(type: TypeFilter.carousels));
      await t.pumpAndSettle();
      expect(_chip('active-filter-type'), findsOneWidget);
      expect(find.text('Carousels'), findsOneWidget);
      expect(_count(t), '1 result');
      await t.tap(
        find.descendant(
          of: _chip('active-filter-type'),
          matching: find.byTooltip('Remove filter'),
        ),
      );
      await t.pumpAndSettle();
      expect(_count(t), '2 results');
    });
  });

  group('reels in the kind sheet', () {
    testWidgets('choosing Reels applies a reel chip and the count', (t) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await pumpLibrary(t, rig);
      await t.tap(find.byTooltip('Filters'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-kind-reels')));
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect(_chip('active-filter-reels'), findsOneWidget);
      expect(_count(t), '1 result');
    });
  });
}
