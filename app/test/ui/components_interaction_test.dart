import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

import 'golden_helpers.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  themed(SingleChildScrollView(child: child), brightness: Brightness.light),
);

void main() {
  testWidgets('SessionBanner.onFix fires when "Fix" is tapped', (tester) async {
    var fixed = 0;
    await _pump(
      tester,
      SessionBanner(
        kind: SessionBannerKind.needsRelogin,
        onFix: () => fixed++,
      ),
    );
    expect(find.text('Instagram login needs attention'), findsOneWidget);
    await tester.tap(find.text('Fix'));
    expect(fixed, 1);
  });

  testWidgets('SessionBanner restricted shows the restricted copy', (
    tester,
  ) async {
    await _pump(
      tester,
      SessionBanner(kind: SessionBannerKind.restricted, onFix: () {}),
    );
    expect(find.text('Instagram account restricted'), findsOneWidget);
  });

  group('PinPad', () {
    testWidgets('digit and backspace callbacks', (tester) async {
      final digits = <int>[];
      var backspaces = 0;
      await _pump(
        tester,
        PinPad(
          length: 4,
          filled: 1,
          onDigit: digits.add,
          onBackspace: () => backspaces++,
        ),
      );
      await tester.tap(find.text('7'));
      await tester.tap(find.text('0'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(digits, [7, 0]);
      expect(backspaces, 1);
    });

    testWidgets('cooldown disables the keys and shows the time', (
      tester,
    ) async {
      final digits = <int>[];
      await _pump(
        tester,
        PinPad(
          length: 4,
          filled: 0,
          cooldown: const Duration(seconds: 45),
          onDigit: digits.add,
          onBackspace: () {},
        ),
      );
      expect(find.text('Try again in 0:45'), findsOneWidget);
      await tester.tap(find.text('5'));
      expect(digits, isEmpty);
    });

    testWidgets('shakeTrigger change plays the shake and settles', (
      tester,
    ) async {
      Widget pad(int trigger) => PinPad(
        length: 4,
        filled: 4,
        errorText: 'Wrong PIN',
        shakeTrigger: trigger,
        onDigit: (_) {},
        onBackspace: () {},
      );
      await _pump(tester, pad(0));
      await _pump(tester, pad(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Transform), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Wrong PIN'), findsOneWidget);
    });

    test('rejects lengths outside 4-6', () {
      expect(
        () => PinPad(
          length: 3,
          filled: 0,
          onDigit: (_) {},
          onBackspace: () {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('ConfirmDialog', () {
    Future<bool?> open(WidgetTester tester, {required String tap}) async {
      bool? result;
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  context,
                  title: 'Delete?',
                  body: 'Cannot be undone.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                  destructive: true,
                );
              },
              child: const Text('open'),
            ),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm resolves true', (tester) async {
      expect(await open(tester, tap: 'Delete'), isTrue);
    });

    testWidgets('cancel resolves false', (tester) async {
      expect(await open(tester, tap: 'Cancel'), isFalse);
    });
  });

  group('AccountChipRow', () {
    const items = [
      AccountChipItem(id: 'a', label: '@nour_k'),
      AccountChipItem(id: 'b', label: '@brandx'),
      AccountChipItem(id: 'c', label: '@client_co'),
    ];

    testWidgets('single select replaces the selection; All clears it', (
      tester,
    ) async {
      final calls = <Set<String>>[];
      await _pump(
        tester,
        AccountChipRow(
          items: items,
          selectedIds: const {'a'},
          onChanged: calls.add,
        ),
      );
      await tester.tap(find.bySemanticsLabel('@brandx'));
      await tester.tap(find.text('All'));
      expect(calls, [
        {'b'},
        <String>{},
      ]);
    });

    testWidgets('multi select toggles', (tester) async {
      final calls = <Set<String>>[];
      await _pump(
        tester,
        AccountChipRow(
          items: items,
          selectedIds: const {'a'},
          multiSelect: true,
          onChanged: calls.add,
        ),
      );
      await tester.tap(find.bySemanticsLabel('@brandx'));
      await tester.tap(find.bySemanticsLabel('@nour_k'));
      expect(calls, [
        {'a', 'b'},
        <String>{},
      ]);
    });

    testWidgets('overflow shows +N and fires onOverflowTap', (tester) async {
      var overflow = 0;
      await _pump(
        tester,
        AccountChipRow(
          items: items,
          selectedIds: const {},
          maxVisible: 1,
          onChanged: (_) {},
          onOverflowTap: () => overflow++,
        ),
      );
      expect(find.text('+2'), findsOneWidget);
      expect(find.bySemanticsLabel('@brandx'), findsNothing);
      await tester.tap(find.text('+2'));
      expect(overflow, 1);
    });
  });

  testWidgets('KindSwitch reports the tapped kind', (tester) async {
    final kinds = <LibraryKind>[];
    await _pump(
      tester,
      KindSwitch(
        selected: LibraryKind.stories,
        storiesLabel: 'Stories',
        postsLabel: 'Posts',
        storiesCount: 12,
        postsCount: 3,
        onChanged: kinds.add,
      ),
    );
    await tester.tap(find.text('Posts'));
    expect(kinds, [LibraryKind.posts]);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Buttons ignore taps while loading and show a spinner', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        children: [
          PrimaryButton(label: 'Go', loading: true, onPressed: () => taps++),
          TonalButton(label: 'Tonal', loading: true, onPressed: () => taps++),
          StorizeTextButton(
            label: 'Text',
            loading: true,
            onPressed: () => taps++,
          ),
        ],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
    await tester.tap(find.text('Go'), warnIfMissed: false);
    await tester.tap(find.text('Tonal'), warnIfMissed: false);
    await tester.tap(find.text('Text'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('StepCard expands and collapses', (tester) async {
    final changes = <bool>[];
    await _pump(
      tester,
      StepCard(
        number: 2,
        title: 'Notifications',
        body: 'Body text',
        expandable: true,
        initiallyExpanded: false,
        onExpansionChanged: changes.add,
      ),
    );
    expect(find.text('Body text'), findsNothing);
    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(find.text('Body text'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(find.text('Body text'), findsNothing);
    expect(changes, [true, false]);
  });

  testWidgets('SettingRow switch and navigation callbacks', (tester) async {
    final values = <bool>[];
    var navigated = 0;
    await _pump(
      tester,
      Column(
        children: [
          SettingRow.toggle(
            title: 'Notifications',
            switchValue: false,
            onChanged: values.add,
          ),
          SettingRow.navigation(title: 'Account', onTap: () => navigated++),
        ],
      ),
    );
    await tester.tap(find.text('Notifications'));
    await tester.tap(find.text('Account'));
    expect(values, [true]);
    expect(navigated, 1);
  });

  testWidgets('EmptyState action, TargetRow tap and thumb taps', (
    tester,
  ) async {
    final log = <String>[];
    await _pump(
      tester,
      Column(
        children: [
          SizedBox(
            height: 300,
            child: EmptyState(
              icon: Icons.photo_outlined,
              title: 'Empty',
              body: 'Nothing here',
              actionLabel: 'Add',
              onAction: () => log.add('empty'),
            ),
          ),
          TargetRow(
            username: 'nour_k',
            category: CategoryKind.ownClient,
            status: StorizeStatus.active,
            onTap: () => log.add('row'),
          ),
          SizedBox(
            width: 100,
            child: StoryThumb(
              semanticLabel: 'story',
              onTap: () => log.add('story'),
              onLongPress: () => log.add('long'),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Add'));
    await tester.tap(find.byType(TargetRow));
    await tester.tap(find.bySemanticsLabel('story'));
    await tester.longPress(find.bySemanticsLabel('story'));
    expect(log, ['empty', 'row', 'story', 'long']);
  });

  testWidgets('TargetRow swipe towards the end triggers the action', (
    tester,
  ) async {
    var swiped = 0;
    await _pump(
      tester,
      TargetRow(
        username: 'nour_k',
        category: CategoryKind.ownClient,
        status: StorizeStatus.active,
        swipeAction: TargetRowSwipeAction(
          label: 'Pause',
          icon: Icons.pause_rounded,
          onTriggered: () => swiped++,
        ),
      ),
    );
    await tester.fling(find.byType(TargetRow), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(swiped, 1);
    // The row snaps back instead of being dismissed.
    expect(find.byType(TargetRow), findsOneWidget);
  });
}
