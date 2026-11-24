import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/targets/target_list_row.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'targets_rig.dart';

void main() {
  late AppLocalizations l10n;

  Future<AppLocalizations> loc(WidgetTester t) async =>
      AppLocalizations.of(t.element(find.byType(Scaffold).first));

  testWidgets('AC1: rows show username, status, category and meta line', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget(
      'nour_k',
      category: TargetCategory.consented,
      lastStoriesCheckAt: DateTime(2026, 11, 21, 10, 42),
      lastNewStoryAt: DateTime(2026, 11, 21, 10, 15),
    );
    await rig.addTarget('client_co', status: TargetStatus.paused);
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    expect(find.text(l10n.tgtCountLimit(2, 50)), findsOneWidget);
    expect(find.textContaining('nour_k'), findsOneWidget);
    expect(find.text(l10n.tgtCatConsented), findsOneWidget);
    expect(find.text(l10n.statusActive), findsOneWidget);
    expect(find.text(l10n.statusPaused), findsOneWidget);
    expect(find.text(l10n.tgtMetaLastNew('10:15 AM')), findsOneWidget);
    expect(find.text(l10n.tgtMetaChecked('10:42 AM')), findsOneWidget);
    expect(find.text(l10n.tgtMetaPausedByYou), findsOneWidget);
  });

  testWidgets('FR-73: a pending target shows the waiting chip, no swipe', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget('later_k', status: TargetStatus.pendingLookup);
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    expect(find.text(l10n.tgtStatusPending), findsOneWidget);
    expect(find.text(l10n.statusActive), findsNothing);
    expect(
      t.widget<TargetListRow>(find.byType(TargetListRow)).swipeAction,
      isNull,
    );
  });

  testWidgets('AC1: Check now is disabled with a tooltip without a session', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount(status: AccountStatus.needsRelogin);
    await rig.addTarget('nour_k');
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    final button = t.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.tgtCheckNow),
    );
    expect(button.onPressed, isNull);
    expect(find.byTooltip(l10n.tgtCheckNowDisabled), findsOneWidget);

    await t.tap(find.widgetWithText(TextButton, l10n.tgtCheckNow));
    await t.pump();
    expect(rig.checkNow.calls, 0);
  });

  for (final status in [null, AccountStatus.loggedOut]) {
    testWidgets('Check now is disabled with account status $status (Lead)', (
      t,
    ) async {
      final rig = TargetsRig();
      if (status != null) await rig.addAccount(status: status);
      await rig.addTarget('nour_k');
      await pumpTargets(t, rig: rig);
      l10n = await loc(t);
      final button = t.widget<TextButton>(
        find.widgetWithText(TextButton, l10n.tgtCheckNow),
      );
      expect(button.onPressed, isNull);
    });
  }

  testWidgets('AC1: Check now with an active session marks rows Checking', (
    t,
  ) async {
    final rig = TargetsRig()..checkNow.gate = Completer<void>();
    await rig.addAccount();
    await rig.addTarget('nour_k');
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    await t.tap(find.widgetWithText(TextButton, l10n.tgtCheckNow));
    await t.pump();
    expect(rig.checkNow.calls, 1);
    expect(find.text(l10n.statusChecking), findsOneWidget);

    rig.checkNow.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text(l10n.statusChecking), findsNothing);
    expect(find.text(l10n.tgtCheckDone(2)), findsOneWidget);
  });

  testWidgets('AC2: swipe pauses, then resumes, the target', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    final nour = await rig.addTarget('nour_k');
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    await t.drag(find.textContaining('nour_k'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect((await rig.targets.getById(nour.id))!.status, TargetStatus.paused);
    expect(find.text(l10n.statusPaused), findsOneWidget);

    await t.drag(find.textContaining('nour_k'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect((await rig.targets.getById(nour.id))!.status, TargetStatus.active);
    expect(find.text(l10n.statusActive), findsOneWidget);
  });

  testWidgets('AC2: rate-limit bar shows only for a recent rate limit', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget('nour_k');
    await rig.activity.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: targetsNow.subtract(const Duration(minutes: 10)).toUtc(),
        type: ActivityType.rateLimited,
        severity: Severity.warn,
      ),
    );
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);
    expect(find.text(l10n.tgtRateLimitBar), findsOneWidget);
  });

  testWidgets('AC2: no rate-limit bar for an old rate limit', (t) async {
    final rig = TargetsRig();
    await rig.addAccount();
    await rig.addTarget('nour_k');
    await rig.activity.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: targetsNow.subtract(const Duration(hours: 3)).toUtc(),
        type: ActivityType.rateLimited,
        severity: Severity.warn,
      ),
    );
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);
    expect(find.text(l10n.tgtRateLimitBar), findsNothing);
  });

  testWidgets('AC4: loading shows skeleton rows', (t) async {
    final rig = TargetsRig();
    await pumpTargets(
      t,
      rig: rig,
      settle: false,
      extra: [
        targetsProvider.overrideWith(
          (ref) => StreamController<List<Target>>().stream,
        ),
      ],
    );
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('AC4: error shows the error state with Retry', (t) async {
    final rig = TargetsRig();
    await pumpTargets(
      t,
      rig: rig,
      extra: [
        targetsProvider.overrideWith(
          (ref) => Stream<List<Target>>.error(StateError('boom')),
        ),
      ],
    );
    l10n = await loc(t);
    expect(find.text(l10n.errorUnknownTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, l10n.retry), findsOneWidget);
  });

  testWidgets('empty state offers Add account and opens S-08', (t) async {
    final rig = TargetsRig();
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);
    expect(find.text(l10n.tgtEmptyTitle), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, l10n.tgtAddAccount));
    await t.pumpAndSettle();
    expect(find.text(l10n.tgtAddAndVerify), findsOneWidget);
  });

  testWidgets('FAB opens S-08', (t) async {
    final rig = TargetsRig();
    await rig.addTarget('nour_k');
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);

    await t.tap(find.byTooltip(l10n.tgtAddAccount));
    await t.pumpAndSettle();
    expect(find.text(l10n.tgtFormTitle), findsWidgets);
  });

  testWidgets('a session problem shows the banner and disables Check now', (
    t,
  ) async {
    final rig = TargetsRig();
    await rig.addAccount(status: AccountStatus.needsRelogin);
    await rig.addTarget('nour_k');
    await pumpTargets(t, rig: rig);
    l10n = await loc(t);
    expect(find.text(l10n.bannerReloginTitle), findsOneWidget);
    final button = t.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.tgtCheckNow),
    );
    expect(button.onPressed, isNull);
  });
}
