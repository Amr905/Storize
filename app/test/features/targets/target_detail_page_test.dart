import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import 'target_detail_rig.dart';

Future<AppLocalizations> _l10n(WidgetTester tester) async =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

void main() {
  group('S-09 header and editable fields (AC1)', () {
    testWidgets('shows name, status, category and note', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'nour_k',
        displayName: 'Nour K.',
        note: 'consent by email 3/11',
        category: TargetCategory.consented,
      );
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      expect(find.text('Nour K.'), findsOneWidget);
      // The username is in the app bar and under the display name.
      expect(find.text('@nour_k'), findsNWidgets(2));
      expect(find.text(l10n.statusActive), findsOneWidget);
      expect(find.text(l10n.tgtCatConsented), findsOneWidget);
      expect(find.text('consent by email 3/11'), findsOneWidget);
      expect(find.byTooltip(l10n.tdtEditCategory), findsOneWidget);
      expect(find.byTooltip(l10n.tdtEditNote), findsOneWidget);
    });

    testWidgets('status card explains a not-visible account', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'old_acct',
        status: TargetStatus.notVisible,
      );
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      expect(find.text(l10n.tdtStatusNotVisible('@loginacc')), findsOneWidget);
    });

    testWidgets('FR-73: a pending target shows the waiting chip and card', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'later_k',
        status: TargetStatus.pendingLookup,
      );
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      // The chip in the header and the status card.
      expect(find.text(l10n.tdtStatusPending), findsNWidgets(2));
      expect(find.text(l10n.statusActive), findsNothing);
    });

    testWidgets('no status card for an active account', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      expect(find.textContaining("doesn't follow"), findsNothing);
      expect(find.text(l10n.tdtStatusUnavailable), findsNothing);
    });

    testWidgets('edits the note through the sheet and saves it', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.byTooltip(l10n.tdtEditNote));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  new note  ');
      await tester.tap(find.widgetWithText(PrimaryButton, l10n.setSave));
      await tester.pumpAndSettle();

      final saved = await rig.targets.getById(target.id);
      expect(saved!.note, 'new note');
      expect(find.text('new note'), findsOneWidget);
    });

    testWidgets('changes the category through the sheet', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.byTooltip(l10n.tdtEditCategory));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.tgtCatPublicShort));
      await tester.pumpAndSettle();

      final saved = await rig.targets.getById(target.id);
      expect(saved!.category, TargetCategory.public);
    });

    testWidgets('unknown target shows the not-found message', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      await pumpDetail(tester, rig: rig, targetId: 999);
      final l10n = await _l10n(tester);

      expect(find.text(l10n.tdtNotFound), findsOneWidget);
    });
  });

  group('S-09 track toggles (AC2, F-1)', () {
    testWidgets('turning off the last track is refused', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget(
        'nour_k',
        trackPosts: false,
        trackReels: false,
      );
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.widgetWithText(FilterChip, l10n.tgtTrackStories));
      await tester.pumpAndSettle();

      expect(find.text(l10n.tgtTrackRequired), findsOneWidget);
      final saved = await rig.targets.getById(target.id);
      expect(saved!.trackStories, isTrue);
    });

    testWidgets('a track can be turned on and another off', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k', trackReels: false);
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.widgetWithText(FilterChip, l10n.tgtTrackReels));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, l10n.tgtTrackPosts));
      await tester.pumpAndSettle();

      final saved = await rig.targets.getById(target.id);
      expect(saved!.trackReels, isTrue);
      expect(saved.trackPosts, isFalse);
      expect(saved.trackStories, isTrue);
    });
  });

  group('S-09 stats (AC3)', () {
    testWidgets('shows stories, posts and space separately', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await rig.addContent(target);
      await rig.addContent(target);
      await rig.addContent(target, kind: ContentKind.post);
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final tiles = find.byType(StatTile);
      expect(tiles, findsNWidgets(3));
      expect(
        find.descendant(of: tiles.at(0), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tiles.at(1), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tiles.at(2), matching: find.text('3.0 MB')),
        findsOneWidget,
      );
    });
  });

  group('S-09 actions and Recent (AC4)', () {
    testWidgets('Check now runs a check when the session is usable', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, l10n.tgtCheckNow));
      await tester.pumpAndSettle();

      expect(rig.checkNow.calls, 1);
      expect(rig.checkNow.targetIds, [target.id]);
      expect(find.text(l10n.tgtCheckDone(2)), findsOneWidget);
    });

    testWidgets('Check now is disabled without a usable session', (
      tester,
    ) async {
      final rig = DetailRig();
      await rig.addAccount(status: AccountStatus.needsRelogin);
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, l10n.tgtCheckNow),
      );
      expect(button.onPressed, isNull);
      expect(find.byTooltip(l10n.tgtCheckNowDisabled), findsOneWidget);
    });

    testWidgets('Pause and Resume change the status', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.tgtActionPause),
      );
      await tester.pumpAndSettle();
      expect(
        (await rig.targets.getById(target.id))!.status,
        TargetStatus.paused,
      );
      expect(find.text(l10n.tgtActionResume), findsOneWidget);

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.tgtActionResume),
      );
      await tester.pumpAndSettle();
      expect(
        (await rig.targets.getById(target.id))!.status,
        TargetStatus.active,
      );
    });

    testWidgets('Recent switches between stories and posts', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await rig.addContent(target);
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      expect(find.text(l10n.tdtEmptyPosts), findsNothing);
      expect(find.text(l10n.tdtEmptyStories), findsNothing);

      // The history section pushes Recent down: scroll it into view.
      final postsChip = find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text(l10n.libPostsTab),
      );
      await tester.ensureVisible(postsChip);
      await tester.pumpAndSettle();
      await tester.tap(postsChip);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.tdtEmptyPosts),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.tdtEmptyPosts), findsOneWidget);
    });

    testWidgets('Recent shows an empty state with no stories', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.scrollUntilVisible(
        find.text(l10n.tdtEmptyStories),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.tdtEmptyStories), findsOneWidget);
    });
  });

  group('S-09 overflow menu (AC5)', () {
    testWidgets('offers Remove and no Export', (tester) async {
      final rig = DetailRig();
      await rig.addAccount();
      final target = await rig.addTarget('nour_k');
      await pumpDetail(tester, rig: rig, targetId: target.id);
      final l10n = await _l10n(tester);

      await tester.tap(find.byTooltip(l10n.tdtMenuTooltip));
      await tester.pumpAndSettle();

      expect(find.text(l10n.tdtRemove), findsOneWidget);
      expect(find.textContaining('Export'), findsNothing);
    });
  });
}
