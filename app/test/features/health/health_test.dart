// T-056 (FR-75): the Health screen, its cards, the countdown and the entry
// points.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/activity/activity_page.dart';
import 'package:storize_app/features/health/health_page.dart';
import 'package:storize_app/features/health/health_providers.dart';
import 'package:storize_app/features/health/health_view.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/ui/components/status_badge.dart';
import 'package:storize_app/ui/theme/theme.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'health_rig.dart';

void main() {
  Future<AppLocalizations> l10nOf(WidgetTester t) async =>
      AppLocalizations.of(t.element(find.byType(HealthPage)));

  group('view mapping', () {
    HealthTarget row({
      TargetStatus status = TargetStatus.active,
      TargetCheckOutcome? outcome,
      String? code,
    }) => HealthTarget(
      id: 1,
      username: 'a',
      status: status,
      lastOutcome: outcome,
      lastCode: code,
      savedToday: 0,
    );

    test('a user pause and a pending lookup win over the last outcome', () {
      expect(
        healthResultOf(
          row(status: TargetStatus.paused, outcome: TargetCheckOutcome.ok),
        ).kind,
        HealthResultKind.paused,
      );
      expect(
        healthResultOf(
          row(
            status: TargetStatus.pendingLookup,
            outcome: TargetCheckOutcome.failed,
          ),
        ).kind,
        HealthResultKind.waiting,
      );
    });

    test('each outcome maps to its pill, failures keep the code', () {
      expect(
        healthResultOf(row(outcome: TargetCheckOutcome.ok)).kind,
        HealthResultKind.ok,
      );
      expect(
        healthResultOf(row(outcome: TargetCheckOutcome.nothingNew)).kind,
        HealthResultKind.nothingNew,
      );
      final failed = healthResultOf(
        row(outcome: TargetCheckOutcome.failed, code: 'network'),
      );
      expect(failed.kind, HealthResultKind.failed);
      expect(failed.code, 'network');
      expect(healthResultOf(row()).kind, HealthResultKind.none);
    });

    test('relative times and the countdown round as expected', () {
      final now = healthNow;
      expect(healthMinutesLeft(now.add(const Duration(seconds: 1)), now), 1);
      expect(healthMinutesLeft(now.add(const Duration(minutes: 42)), now), 42);
      expect(
        healthMinutesLeft(now.add(const Duration(seconds: 61)), now),
        2,
      );
    });
  });

  testWidgets('shows the session, budget, pause, schedule and accounts', (
    t,
  ) async {
    final model = FakeHealthReadModel(healthSnapshot());
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final l10n = await l10nOf(t);

    expect(find.text('@storize_archive'), findsOneWidget);
    expect(find.byType(StatusBadge), findsWidgets);
    expect(find.text(l10n.hltBudgetLeft(2, 6)), findsOneWidget);
    expect(find.text(l10n.hltBudgetRefill(60)), findsOneWidget);
    expect(find.text(l10n.hltPausedTitle), findsOneWidget);
    expect(find.textContaining('42 min left'), findsOneWidget);
    expect(find.textContaining('Every 30 min for stories'), findsOneWidget);
    expect(find.textContaining('Last run 9 min ago'), findsOneWidget);

    expect(find.text('@nour_k'), findsOneWidget);
    expect(find.text(l10n.hltResultOk), findsOneWidget);
    expect(find.text(l10n.hltSavedToday(3)), findsOneWidget);
    expect(find.text(l10n.hltResultNothingNew), findsOneWidget);
    expect(find.text(l10n.hltResultWaiting), findsOneWidget);
    expect(find.text(l10n.hltResultPaused), findsOneWidget);
    expect(
      find.text(l10n.hltResultFailed(l10n.errorNetworkTitle)),
      findsOneWidget,
    );
    expect(
      find.text(l10n.hltResultFailed(l10n.hltReasonNotVisible)),
      findsOneWidget,
    );
    expect(find.text(l10n.hltNoSuccess), findsNWidgets(3));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('no pause row when the budget is free', (t) async {
    final model = FakeHealthReadModel(healthSnapshot(paused: false));
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final l10n = await l10nOf(t);
    expect(find.text(l10n.hltPausedTitle), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('no connected account and no targets say so', (t) async {
    final model = FakeHealthReadModel(
      healthSnapshot(
        paused: false,
        withSession: false,
        targets: const [],
      ),
    );
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final l10n = await l10nOf(t);
    expect(find.text(l10n.hltSessionNone), findsOneWidget);
    expect(find.text(l10n.hltNoAccounts), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a failed read shows the error state and Retry reads again', (
    t,
  ) async {
    final model = FakeHealthReadModel(healthSnapshot())
      ..error = StateError('boom');
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final l10n = await l10nOf(t);
    expect(find.text(l10n.errorUnknownTitle), findsOneWidget);

    model.error = null;
    final before = model.reads;
    await t.tap(find.text(l10n.retry));
    await t.pumpAndSettle();
    expect(model.reads, greaterThan(before));
    expect(find.text('@nour_k'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('pull to refresh reads the snapshot again', (t) async {
    final model = FakeHealthReadModel(healthSnapshot());
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final before = model.reads;
    await t.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      800,
    );
    await t.pumpAndSettle();
    expect(model.reads, greaterThan(before));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('refreshes every 15 s while open', (t) async {
    final model = FakeHealthReadModel(healthSnapshot());
    await t.pumpWidget(
      healthApp(home: const HealthPage(), overrides: healthOverrides(model)),
    );
    await t.pumpAndSettle();
    final before = model.reads;
    await t.pump(healthRefreshInterval);
    await t.pumpAndSettle();
    expect(model.reads, before + 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the Activity app-bar icon opens Health', (t) async {
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(t.view.reset);
    final model = FakeHealthReadModel(healthSnapshot());
    final router = healthRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [...healthOverrides(model), ...activityQuietOverrides()],
        child: MaterialApp.router(
          theme: StorizeTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
    final l10n = AppLocalizations.of(t.element(find.byType(ActivityPage)));
    await t.tap(find.byTooltip(l10n.hltTitle));
    await t.pumpAndSettle();
    expect(find.byType(HealthPage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('See details on the session banner opens Health', (t) async {
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 900);
    addTearDown(t.view.reset);
    final model = FakeHealthReadModel(healthSnapshot());
    final router = healthRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...healthOverrides(model),
          ...activityQuietOverrides(
            account: LoginAccount(
              id: 1,
              platform: PlatformId.instagram,
              remoteUserId: 'me',
              username: 'storize_archive',
              status: AccountStatus.needsRelogin,
              connectedAt: DateTime.utc(2026),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: StorizeTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
    final l10n = AppLocalizations.of(t.element(find.byType(ActivityPage)));
    await t.tap(find.text(l10n.hltSeeDetails));
    await t.pumpAndSettle();
    expect(find.byType(HealthPage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
