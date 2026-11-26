// T-053: the Library's Highlights segment (S-04).
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import 'library_rig.dart';

void main() {
  testWidgets('Highlights segment shows highlights only; Stories clears it', (
    t,
  ) async {
    final rig = LibraryRig();
    final nour = await rig.addTarget('nour_k');
    await rig.addContent(nour, postedAt: DateTime(2026, 11, 20, 10));
    await rig.addContent(
      nour,
      postedAt: DateTime(2026, 11, 20, 9),
      kind: ContentKind.highlight,
    );
    final c = await pumpLibrary(t, rig);

    expect(find.text('Highlights'), findsOneWidget);
    expect(c.read(libraryFiltersProvider).highlightsOnly, isFalse);
    expect(find.byType(StoryThumb), findsNWidgets(1));

    await t.tap(find.text('Highlights'));
    await t.pumpAndSettle();
    expect(c.read(libraryFiltersProvider).highlightsOnly, isTrue);
    expect(c.read(libraryKindProvider), LibraryKind.stories);
    expect(find.byType(StoryThumb), findsNWidgets(1));
    expect(find.text('Highlight'), findsOneWidget); // saffron badge on the tile
    final sw = t.widget<KindSwitch>(find.byType(KindSwitch));
    expect(sw.highlightsSelected, isTrue);

    await t.tap(find.text('Posts').first);
    await t.pumpAndSettle();
    expect(c.read(libraryFiltersProvider).highlightsOnly, isFalse);
    expect(c.read(libraryKindProvider), LibraryKind.posts);

    await t.tap(find.text('Stories').first);
    await t.pumpAndSettle();
    expect(c.read(libraryFiltersProvider).highlightsOnly, isFalse);
    expect(c.read(libraryKindProvider), LibraryKind.stories);
    expect(find.byType(StoryThumb), findsNWidgets(1));
  });
}
