// T-055 goldens: search active and filters applied, light and dark (FR-76).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/ui/ui.dart' show LibraryKind;

import '../../ui/golden_helpers.dart';
import 'library_rig.dart';
import 'library_search_rig.dart';

const _phone = Size(400, 800);

void _both(
  String name,
  Future<void> Function(WidgetTester t, LibraryRig rig, Brightness b) body,
) {
  for (final b in Brightness.values) {
    testWidgets('$name golden (${b.name})', (t) async {
      final rig = LibraryRig();
      await seedSearch(rig);
      await body(t, rig, b);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_${b.name}.png'),
      );
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('library_search_active', (t, rig, b) async {
    final c = await pumpLibrary(t, rig, brightness: b, size: _phone);
    await t.tap(find.text('Posts').first);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Search'));
    await t.pump();
    await t.enterText(
      find.byKey(const ValueKey('library-search-field')),
      'sunset',
    );
    await t.pump(librarySearchDebounce);
    await t.pumpAndSettle();
    expect(c.read(librarySearchQueryProvider), 'sunset');
  });

  _both('library_filters_applied', (t, rig, b) async {
    final c = await pumpLibrary(t, rig, brightness: b, size: _phone);
    final nour = rig.byName['nour_k']!;
    c.read(libraryKindProvider.notifier).select(LibraryKind.posts);
    c
        .read(libraryFiltersProvider.notifier)
        .replace(
          LibraryFilters(
            targetIds: {nour.id},
            date: DatePreset.days30,
            type: TypeFilter.videos,
          ),
        );
    await t.pumpAndSettle();
  });
}
