import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/library/library_filters.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_domain/storize_domain.dart';

import '../../ui/golden_helpers.dart';
import 'library_rig.dart';

const _phone = Size(400, 800);

Future<void> _golden(WidgetTester t, String name, Brightness b) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void _both(
  String name,
  Future<void> Function(WidgetTester t, LibraryRig rig, Brightness b) body, {
  Future<void> Function(LibraryRig rig)? seed,
}) {
  for (final b in Brightness.values) {
    testWidgets('$name golden (${b.name})', (t) async {
      final rig = LibraryRig();
      await (seed ?? seedStandard)(rig);
      await body(t, rig, b);
      await _golden(t, name, b);
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('library_stories', (t, rig, b) async {
    await pumpLibrary(t, rig, brightness: b, size: _phone);
  });

  _both('library_posts', (t, rig, b) async {
    await pumpLibrary(
      t,
      rig,
      brightness: b,
      size: _phone,
    );
    await t.tap(find.text('Posts').first);
    await t.pumpAndSettle();
  });

  _both('library_selection', (t, rig, b) async {
    await pumpLibrary(t, rig, brightness: b, size: _phone);
    await t.longPress(find.byKey(const ValueKey(1)));
    await t.tap(find.byKey(const ValueKey(2)));
    await t.pumpAndSettle();
  });

  _both('library_filters', (t, rig, b) async {
    await pumpLibrary(t, rig, brightness: b, size: const Size(400, 900));
    await t.tap(find.byTooltip('Filters'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('filter-account-1')));
    await t.tap(find.byKey(const ValueKey('filter-date-days7')));
    await t.pumpAndSettle();
  });

  _both(
    'library_empty_no_targets',
    (t, rig, b) => pumpLibrary(t, rig, brightness: b, size: _phone),
    seed: (_) async {},
  );

  _both(
    'library_empty_waiting',
    (t, rig, b) => pumpLibrary(t, rig, brightness: b, size: _phone),
    seed: (rig) async {
      await rig.addTarget(
        'nour_k',
        lastStoriesCheckAt: DateTime(2026, 11, 20, 10, 42).toUtc(),
      );
    },
  );

  _both('library_empty_filtered', (t, rig, b) async {
    final c = await pumpLibrary(t, rig, brightness: b, size: _phone);
    final client = rig.byName['client_co']!;
    c
        .read(libraryFiltersProvider.notifier)
        .replace(
          c
              .read(libraryFiltersProvider)
              .copyWith(targetIds: {client.id}, date: DatePreset.today),
        );
    await t.pumpAndSettle();
  });

  _both('library_loading', (t, rig, b) async {
    await pumpLibrary(
      t,
      rig,
      brightness: b,
      size: _phone,
      settle: false,
      extra: [
        allContentProvider.overrideWith(
          (ref) => const Stream<List<ContentWithMedia>>.empty(),
        ),
      ],
    );
    await t.pump();
  });

  _both('library_error', (t, rig, b) async {
    await pumpLibrary(
      t,
      rig,
      brightness: b,
      size: _phone,
      extra: [
        allContentProvider.overrideWith(
          (ref) => Stream<List<ContentWithMedia>>.error(StateError('db')),
        ),
      ],
    );
  });

  testWidgets('library_stories_rtl golden (light)', (t) async {
    final rig = LibraryRig();
    await seedStandard(rig);
    await pumpLibrary(t, rig, size: _phone, direction: TextDirection.rtl);
    await _golden(t, 'library_stories_rtl', Brightness.light);
  });
}
