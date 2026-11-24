import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/target_history_section.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'target_detail_rig.dart';

/// T-042 AC2 (S-09): history progress, Pause/Resume/Cancel, range editor and
/// the Highlights switch.
void main() {
  late AppLocalizations l10n;

  Future<Target> seed(
    DetailRig rig, {
    HistoryRange range = HistoryRange.days30,
    HistoryState? state = HistoryState.running,
    int fetched = 312,
    DateTime? oldest,
    bool highlights = false,
  }) async {
    await rig.addAccount();
    final target = await rig.addTarget('nour_k');
    await rig.targets.update(
      target.copyWith(
        historyRange: range,
        highlightsEnabled: highlights,
        historyProgress: state == null
            ? null
            : HistoryProgress(
                state: state,
                fetched: fetched,
                oldestSeenAt: oldest,
                updatedAt: detailNow,
              ),
      ),
    );
    return target;
  }

  Future<Target> stored(WidgetTester t, DetailRig rig, int id) async =>
      (await t.runAsync(() => rig.targets.getById(id)))!;

  /// A finder limited to the S-09 history section (the target's own Pause
  /// button shares the label).
  Finder inSection(Finder f) => find.descendant(
    of: find.byType(TargetHistorySection),
    matching: f,
  );

  Future<void> tapFinder(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('AC2: progress shows the count and the date reached', (t) async {
    final rig = DetailRig();
    final target = await seed(
      rig,
      oldest: DateTime.utc(2026, 11, 1, 9),
    );
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(
      find.text(l10n.tdtHistoryRunning(312, 'Nov 1, 2026')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.tdtHistoryRange(l10n.tgtHistory30Days)),
      findsOneWidget,
    );
    expect(
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryPause)),
      findsOneWidget,
    );
    expect(
      inSection(find.widgetWithText(TextButton, l10n.tdtHistoryCancel)),
      findsOneWidget,
    );
  });

  testWidgets('AC2: progress without a date uses the count only', (t) async {
    final rig = DetailRig();
    final target = await seed(rig, fetched: 1);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(find.text(l10n.tdtHistoryRunningNoDate(1)), findsOneWidget);
  });

  testWidgets('AC2: Pause pauses a running history and shows Paused', (
    t,
  ) async {
    final rig = DetailRig();
    final target = await seed(rig);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    await tapFinder(
      t,
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryPause)),
    );
    expect(
      (await stored(t, rig, target.id)).historyProgress?.state,
      HistoryState.paused,
    );
    expect(find.text(l10n.tdtHistoryPaused), findsOneWidget);
    expect(
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryResume)),
      findsOneWidget,
    );
  });

  testWidgets('AC2: Resume resumes a paused history and kicks the task', (
    t,
  ) async {
    final rig = DetailRig();
    final target = await seed(rig, state: HistoryState.paused);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    await tapFinder(
      t,
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryResume)),
    );
    expect(
      (await stored(t, rig, target.id)).historyProgress?.state,
      HistoryState.running,
    );
    expect(rig.scheduler.kickHistoryCalls, 1);
  });

  testWidgets('AC2: a failed history shows Failed and Resume', (t) async {
    final rig = DetailRig();
    final target = await seed(rig, state: HistoryState.failed);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(find.text(l10n.tdtHistoryFailed), findsOneWidget);
    expect(
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryResume)),
      findsOneWidget,
    );
  });

  testWidgets('AC2: Done shows no pause or resume button', (t) async {
    final rig = DetailRig();
    final target = await seed(rig, state: HistoryState.done);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    expect(find.text(l10n.tdtHistoryDone), findsOneWidget);
    expect(
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryPause)),
      findsNothing,
    );
    expect(
      inSection(find.widgetWithText(OutlinedButton, l10n.tdtHistoryResume)),
      findsNothing,
    );
  });

  testWidgets('AC2: Cancel stops the history and sets the range to None', (
    t,
  ) async {
    final rig = DetailRig();
    final target = await seed(rig);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    await tapFinder(
      t,
      inSection(find.widgetWithText(TextButton, l10n.tdtHistoryCancel)),
    );
    final after = await stored(t, rig, target.id);
    expect(after.historyRange, HistoryRange.none);
    expect(after.historyProgress?.state, HistoryState.idle);
  });

  testWidgets('AC2: Change opens the range picker; a choice updates the range '
      'and kicks the task', (t) async {
    final rig = DetailRig();
    final target = await seed(rig);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    await tapFinder(t, find.text(l10n.tdtHistoryChange));
    await tapFinder(t, find.text(l10n.tgtHistory7Days));

    expect((await stored(t, rig, target.id)).historyRange, HistoryRange.days7);
    expect(rig.scheduler.kickHistoryCalls, 1);
  });

  testWidgets('AC2: turning Highlights on saves the flag and runs a sync', (
    t,
  ) async {
    final rig = DetailRig();
    rig.platform.fetchHighlightsResults.fallback =
        const Ok<List<RemoteHighlight>>(
          [],
        );
    final target = await seed(rig, range: HistoryRange.none, state: null);
    await pumpDetail(t, rig: rig, targetId: target.id);
    l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));

    await tapFinder(t, find.byType(SwitchListTile));
    expect((await stored(t, rig, target.id)).highlightsEnabled, isTrue);
    await t.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(rig.platform.callsTo('fetchHighlights'), hasLength(1));
  });

  testWidgets('AC2: turning Highlights off saves the flag and does not sync', (
    t,
  ) async {
    final rig = DetailRig();
    final target = await seed(
      rig,
      range: HistoryRange.none,
      state: null,
      highlights: true,
    );
    await pumpDetail(t, rig: rig, targetId: target.id);

    await tapFinder(t, find.byType(SwitchListTile));
    expect((await stored(t, rig, target.id)).highlightsEnabled, isFalse);
    expect(rig.platform.callsTo('fetchHighlights'), isEmpty);
  });
}
