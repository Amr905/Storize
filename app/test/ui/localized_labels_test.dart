import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

import 'golden_helpers.dart';

/// Labels that used to come from `StorizeStrings` (T-024b) and the
/// parameterised semantics labels. The English wording must not change.
void main() {
  testWidgets('StepCard semantics read number, title and status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            StepCard(number: 2, title: 'Connect', body: 'Body'),
            StepCard(
              number: 3,
              title: 'Finish',
              body: 'Body',
              status: StepStatus.done,
            ),
          ],
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.bySemanticsLabel('Step 2, Connect, To do'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3, Finish, Done'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('StatTile and KindSwitch semantics include the values', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            const StatTile(value: '128', label: 'Saved'),
            KindSwitch(
              selected: LibraryKind.stories,
              storiesLabel: 'Stories',
              postsLabel: 'Posts',
              storiesCount: 12,
              onChanged: (_) {},
            ),
          ],
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.bySemanticsLabel('Saved: 128'), findsOneWidget);
    expect(find.bySemanticsLabel('Stories, 12'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('default badge and tag text comes from the localisations', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            StatusBadge(status: StorizeStatus.needsRelogin),
            CategoryTag(kind: CategoryKind.ownClient),
          ],
        ),
        brightness: Brightness.light,
      ),
    );
    expect(find.text('Needs re-login'), findsOneWidget);
    expect(find.text('Own / client'), findsOneWidget);
  });

  testWidgets('skeleton exposes the Loading label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        const SkeletonList(itemCount: 1, animate: false),
        brightness: Brightness.light,
      ),
    );
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    handle.dispose();
  });
}
