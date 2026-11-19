import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';

import 'golden_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  themed(
    Align(alignment: AlignmentDirectional.topStart, child: child),
    brightness: Brightness.light,
    direction: direction,
  ),
);

void main() {
  group('RTL mirroring (AC-3)', () {
    testWidgets('StatusBadge icon sits at the start of the text', (
      tester,
    ) async {
      Future<(double, double)> positions(TextDirection d) async {
        await _pump(
          tester,
          const StatusBadge(status: StorizeStatus.active),
          direction: d,
        );
        return (
          tester.getCenter(find.byIcon(Icons.check_circle_rounded)).dx,
          tester.getCenter(find.text('Active')).dx,
        );
      }

      final (ltrIcon, ltrText) = await positions(TextDirection.ltr);
      expect(ltrIcon, lessThan(ltrText));
      final (rtlIcon, rtlText) = await positions(TextDirection.rtl);
      expect(rtlIcon, greaterThan(rtlText));
    });

    testWidgets('badge hugs the start edge in both directions', (
      tester,
    ) async {
      await _pump(tester, const StatusBadge(status: StorizeStatus.active));
      expect(tester.getTopLeft(find.byType(StatusBadge)).dx, 0);
      await _pump(
        tester,
        const StatusBadge(status: StorizeStatus.active),
        direction: TextDirection.rtl,
      );
      expect(tester.getTopRight(find.byType(StatusBadge)).dx, 800);
    });

    testWidgets('SessionBanner: icon and Fix swap sides', (tester) async {
      Future<(double, double)> xs(TextDirection d) async {
        await _pump(
          tester,
          SizedBox(
            width: 400,
            child: SessionBanner(
              kind: SessionBannerKind.needsRelogin,
              onFix: () {},
            ),
          ),
          direction: d,
        );
        return (
          tester.getCenter(find.byIcon(Icons.warning_amber_rounded)).dx,
          tester.getCenter(find.text('Fix')).dx,
        );
      }

      final (ltrIcon, ltrFix) = await xs(TextDirection.ltr);
      expect(ltrIcon, lessThan(ltrFix));
      final (rtlIcon, rtlFix) = await xs(TextDirection.rtl);
      expect(rtlIcon, greaterThan(rtlFix));
    });

    testWidgets('StoryThumb duration badge moves to the start (right) in RTL', (
      tester,
    ) async {
      Future<double> badgeDx(TextDirection d) async {
        await _pump(
          tester,
          const SizedBox(
            width: 90,
            child: StoryThumb(
              semanticLabel: 'v',
              isVideo: true,
              duration: Duration(seconds: 5),
            ),
          ),
          direction: d,
        );
        final tile = tester.getRect(find.byType(StoryThumb));
        return tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dx -
            tile.center.dx;
      }

      expect(await badgeDx(TextDirection.ltr), lessThan(0));
      expect(await badgeDx(TextDirection.rtl), greaterThan(0));
    });

    testWidgets('SettingRow chevron points to the end side', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 400,
          child: SettingRow.navigation(title: 'Account', onTap: () {}),
        ),
        direction: TextDirection.rtl,
      );
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('Touch targets >= 48 dp (AC-4)', () {
    testWidgets(
      'interactive components meet the Android tap-target guideline',
      (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themed(
            SingleChildScrollView(
              child: Column(
                children: [
                  SessionBanner(
                    kind: SessionBannerKind.needsRelogin,
                    onFix: () {},
                  ),
                  PrimaryButton(label: 'Primary', onPressed: () {}),
                  TonalButton(label: 'Tonal', onPressed: () {}),
                  StorizeTextButton(label: 'Text', onPressed: () {}),
                  TargetRow(
                    username: 'nour_k',
                    category: CategoryKind.ownClient,
                    status: StorizeStatus.active,
                    onTap: () {},
                  ),
                  AccountChipRow(
                    items: const [AccountChipItem(id: 'a', label: '@a')],
                    selectedIds: const {},
                    onChanged: (_) {},
                  ),
                  KindSwitch(
                    selected: LibraryKind.stories,
                    storiesLabel: 'Stories',
                    postsLabel: 'Posts',
                    onChanged: (_) {},
                  ),
                  StepCard(
                    number: 1,
                    title: 'Step',
                    body: 'Body',
                    expandable: true,
                    actionLabel: 'Go',
                    onAction: () {},
                  ),
                  ActivityItem(
                    icon: Icons.sync_rounded,
                    tone: ActivityTone.info,
                    time: '10:00',
                    text: 'Text',
                    actionLabel: 'Fix',
                    onAction: () {},
                  ),
                  SettingRow.toggle(
                    title: 'Switch',
                    switchValue: true,
                    onChanged: (_) {},
                  ),
                  SettingRow.navigation(title: 'Nav', onTap: () {}),
                  SizedBox(
                    width: 100,
                    child: StoryThumb(semanticLabel: 'story', onTap: () {}),
                  ),
                  SizedBox(
                    width: 100,
                    child: PostThumb(semanticLabel: 'post', onTap: () {}),
                  ),
                  PinPad(
                    length: 4,
                    filled: 0,
                    onDigit: (_) {},
                    onBackspace: () {},
                    onBiometric: () {},
                  ),
                ],
              ),
            ),
            brightness: Brightness.light,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      },
    );

    testWidgets('explicit sizes of small-looking controls', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            AccountChipRow(
              items: const [AccountChipItem(id: 'a', label: '@a')],
              selectedIds: const {},
              onChanged: (_) {},
              maxVisible: 0,
            ),
            KindSwitch(
              selected: LibraryKind.stories,
              storiesLabel: 'S',
              postsLabel: 'P',
              onChanged: (_) {},
            ),
            SessionBanner(
              kind: SessionBannerKind.restricted,
              onFix: () {},
            ),
          ],
        ),
      );
      for (final label in ['All', '+1', 'S', 'P', 'Fix']) {
        final size = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (w) => w is ConstrainedBox || w is TextButton,
                ),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });
  });
}
