import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_model/storize_model.dart';

import 'targets_rig.dart';

/// T-042 AC1 (S-08): the post-history picker and the Highlights switch.
void main() {
  late AppLocalizations l10n;

  Future<void> openForm(WidgetTester t, TargetsRig rig) async {
    await pumpTargets(t, rig: rig, initial: '/targets/add');
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
  }

  AddTargetForm formOf(WidgetTester t) => ProviderScope.containerOf(
    t.element(find.byType(AddTargetPage)),
  ).read(addTargetFormProvider);

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  Future<void> addOkUser(TargetsRig rig) async {
    rig.platform.resolveUserResults.addOk(
      const RemoteUser(
        remoteUserId: 'uid-1',
        username: 'nour_k',
        followedByViewer: false,
        blockedByViewer: false,
      ),
    );
    rig.platform.latestPostTimeResults.fallback = const Ok<DateTime?>(null);
  }

  testWidgets(
    'AC1: the history picker defaults to None and Highlights is off',
    (
      t,
    ) async {
      final rig = TargetsRig();
      await openForm(t, rig);

      expect(formOf(t).historyRange, HistoryRange.none);
      expect(formOf(t).highlights, isFalse);
      expect(find.byKey(const ValueKey('history-none')), findsOneWidget);
      expect(find.text(l10n.tgtHistoryAllHint), findsNothing);
    },
  );

  testWidgets('AC1: choosing Last 7 days sets the range', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await tapText(t, l10n.tgtHistory7Days);
    expect(formOf(t).historyRange, HistoryRange.days7);
  });

  testWidgets('AC1: All shows the slow-download hint', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await tapText(t, l10n.tgtHistoryAll);
    expect(formOf(t).historyRange, HistoryRange.all);
    expect(find.text(l10n.tgtHistoryAllHint), findsOneWidget);
  });

  testWidgets('AC1: Since a date opens the date picker and keeps the date', (
    t,
  ) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await tapText(t, l10n.tgtHistorySince);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tapText(
      t,
      MaterialLocalizations.of(
        t.element(find.byType(Scaffold).first),
      ).okButtonLabel,
    );

    final form = formOf(t);
    expect(form.historyRange, HistoryRange.since);
    expect(form.historySince, DateTime(2026, 11, 21));
    expect(find.text(l10n.tgtHistorySinceDate('Nov 21, 2026')), findsOneWidget);
  });

  testWidgets('AC1: cancelling the date picker keeps the old range', (t) async {
    final rig = TargetsRig();
    await openForm(t, rig);

    await tapText(t, l10n.tgtHistorySince);
    await tapText(
      t,
      MaterialLocalizations.of(
        t.element(find.byType(Scaffold).first),
      ).cancelButtonLabel,
    );

    expect(formOf(t).historyRange, HistoryRange.none);
  });

  testWidgets('AC1: a valid add with a range and highlights starts the history '
      'and saves the flag', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await addOkUser(rig);
    await openForm(t, rig);

    await t.enterText(find.byType(TextField).at(0), 'nour_k');
    await tapText(t, l10n.tgtCatOwnTitle);
    await tapText(t, l10n.tgtHistoryToday);
    await tapText(t, l10n.tgtHighlightsLabel);
    expect(formOf(t).highlights, isTrue);

    await t.ensureVisible(
      find.widgetWithText(FilledButton, l10n.tgtAddAndVerify),
    );
    await t.runAsync(() async {
      await t.tap(find.widgetWithText(FilledButton, l10n.tgtAddAndVerify));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await t.pumpAndSettle();

    final stored = (await t.runAsync(() => rig.targets.watchAll().first))!
        .single;
    expect(stored.highlightsEnabled, isTrue);
    expect(stored.historyRange, HistoryRange.today);
    expect(stored.historyProgress?.state, HistoryState.running);
    expect(rig.scheduler.kickHistoryCalls, 1);
  });

  testWidgets(
    'AC1: a valid add with None starts no history and kicks nothing',
    (
      t,
    ) async {
      final rig = TargetsRig();
      await rig.addAccount();
      await addOkUser(rig);
      await openForm(t, rig);

      await t.enterText(find.byType(TextField).at(0), 'nour_k');
      await tapText(t, l10n.tgtCatOwnTitle);
      await t.ensureVisible(
        find.widgetWithText(FilledButton, l10n.tgtAddAndVerify),
      );
      await t.runAsync(() async {
        await t.tap(find.widgetWithText(FilledButton, l10n.tgtAddAndVerify));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await t.pumpAndSettle();

      final stored = (await t.runAsync(() => rig.targets.watchAll().first))!
          .single;
      expect(stored.highlightsEnabled, isFalse);
      expect(stored.historyProgress, isNull);
      expect(rig.scheduler.kickHistoryCalls, 0);
    },
  );
}
