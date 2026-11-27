import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/core/session_banner_provider.dart';
import 'package:storize_app/features/activity/activity_page.dart';
import 'package:storize_app/features/activity/activity_providers.dart';
import 'package:storize_app/features/health/health_page.dart';
import 'package:storize_app/features/health/health_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/theme/theme.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// "Now" of every Health test: 2026-11-27 10:42 UTC.
final DateTime healthNow = DateTime.utc(2026, 11, 27, 10, 42);

HealthTarget _t(
  int id,
  String name, {
  DateTime? lastSuccessAt,
  TargetCheckOutcome? outcome,
  String? code,
  int saved = 0,
  TargetStatus status = TargetStatus.active,
}) => HealthTarget(
  id: id,
  username: name,
  status: status,
  lastSuccessAt: lastSuccessAt,
  lastOutcome: outcome,
  lastCode: code,
  savedToday: saved,
);

/// The standard snapshot: a healthy session, part of the budget used, a
/// pause, and one account in each result state.
HealthSnapshot healthSnapshot({
  bool paused = true,
  bool withSession = true,
  List<HealthTarget>? targets,
  AccountStatus status = AccountStatus.active,
}) => HealthSnapshot(
  at: healthNow,
  session: withSession
      ? HealthSession(username: 'storize_archive', status: status)
      : null,
  budget: HealthBudget(
    burst: 6,
    callsPerHour: 60,
    availableNow: 2,
    pausedUntil: paused ? healthNow.add(const Duration(minutes: 42)) : null,
  ),
  schedule: HealthSchedule(
    storyIntervalMin: 30,
    postIntervalMin: 180,
    lastRunAt: healthNow.subtract(const Duration(minutes: 9)),
  ),
  targets:
      targets ??
      [
        _t(
          1,
          'nour_k',
          lastSuccessAt: healthNow.subtract(const Duration(minutes: 8)),
          outcome: TargetCheckOutcome.ok,
          saved: 3,
        ),
        _t(
          2,
          'brandx',
          lastSuccessAt: healthNow.subtract(const Duration(hours: 2)),
          outcome: TargetCheckOutcome.nothingNew,
        ),
        _t(
          3,
          'client_co',
          lastSuccessAt: healthNow.subtract(const Duration(days: 1)),
          outcome: TargetCheckOutcome.failed,
          code: 'network',
        ),
        _t(
          4,
          'private_one',
          outcome: TargetCheckOutcome.failed,
          code: 'not_visible',
        ),
        _t(5, 'quiet_one', status: TargetStatus.paused),
        _t(6, 'new_one', status: TargetStatus.pendingLookup),
      ],
);

/// Overrides that feed the Health screen from a fake read model.
List<Override> healthOverrides(FakeHealthReadModel model) => [
  healthReadModelProvider.overrideWithValue(model),
];

/// The app shell for Health tests: localisations and the Storize theme, with
/// [home] as the route.
Widget healthApp({
  required Widget home,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.light
        ? StorizeTheme.light()
        : StorizeTheme.dark(),
    home: home,
  ),
);

/// Overrides that keep the Activity page quiet (no events, no banner unless
/// [account] is set).
List<Override> activityQuietOverrides({LoginAccount? account}) => [
  activityEventsProvider.overrideWith((ref) => Stream.value(const [])),
  activityTargetsProvider.overrideWith((ref) => Stream.value(const [])),
  activeAccountProvider.overrideWith((ref) => Stream.value(account)),
  clockProvider.overrideWithValue(FakeClock(healthNow)),
];

/// A router with Activity at `/activity` and Health at `/activity/health`,
/// as in the app.
GoRouter healthRouter() => GoRouter(
  initialLocation: Routes.activityPath,
  routes: [
    GoRoute(
      path: Routes.activityPath,
      builder: (_, _) => const ActivityPage(),
      routes: [
        GoRoute(path: 'health', builder: (_, _) => const HealthPage()),
      ],
    ),
  ],
);
