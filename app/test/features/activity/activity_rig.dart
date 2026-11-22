import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/activity/activity_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// "Now" in every activity test: 2026-11-20 12:00 local time.
final DateTime activityNow = DateTime(2026, 11, 20, 12).toUtc();

/// Fakes and seed helpers for the S-11 tests.
class ActivityRig {
  ActivityRig() : clock = FakeClock(activityNow) {
    events = FakeActivityRepo(clock);
  }

  final FakeClock clock;
  late final FakeActivityRepo events;
  final FakeTargetRepo targets = FakeTargetRepo();
  final FakeAccountRepo accounts = FakeAccountRepo();
  final Map<String, Target> byName = {};

  Future<Target> addTarget(String username) async =>
      byName[username] = await targets.insert(
        Target(
          id: Target.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'uid-$username',
          username: username,
          category: TargetCategory.ownClient,
          postsWatermarkAt: DateTime.utc(2026),
          addedAt: DateTime.utc(2026),
        ),
      );

  Future<void> add(
    ActivityType type,
    DateTime at, {
    Severity severity = Severity.info,
    Target? target,
    int count = 1,
    Map<String, Object?> payload = const {},
  }) async {
    await events.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: at.toUtc(),
        type: type,
        severity: severity,
        targetId: target?.id,
        count: count,
        payload: payload,
      ),
    );
  }

  List<Override> get overrides => [
    activityRepoProvider.overrideWithValue(events),
    targetRepoProvider.overrideWithValue(targets),
    accountRepoProvider.overrideWithValue(accounts),
    clockProvider.overrideWithValue(clock),
  ];
}

DateTime _at(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);

/// The standard data set: a check, downloads, a gap, a removal, a rate limit,
/// a session problem, a platform change, one download two days old and one
/// entry older than the 7-day window (must never show).
Future<void> seedActivity(ActivityRig rig) async {
  final nour = await rig.addTarget('nour_k');
  final brandx = await rig.addTarget('brandx');
  final client = await rig.addTarget('client_co');
  await rig.add(
    ActivityType.downloadedStories,
    _at(20, 10, 42),
    target: nour,
    count: 3,
  );
  await rig.add(
    ActivityType.checkDone,
    _at(20, 10, 42),
    count: 12,
    payload: {'targets': 12, 'failed': 0},
  );
  await rig.add(
    ActivityType.gap,
    _at(20, 9, 40),
    severity: Severity.warn,
    payload: {
      'fromMs': _at(20, 2, 10).millisecondsSinceEpoch,
      'toMs': _at(20, 9, 40).millisecondsSinceEpoch,
    },
  );
  await rig.add(ActivityType.removedBeforeDownload, _at(20, 8), target: brandx);
  await rig.add(
    ActivityType.rateLimited,
    _at(20, 7, 30),
    severity: Severity.warn,
  );
  await rig.add(
    ActivityType.sessionProblem,
    _at(20, 6),
    severity: Severity.error,
  );
  await rig.add(
    ActivityType.platformChanged,
    _at(19, 22, 10),
    severity: Severity.error,
  );
  await rig.add(
    ActivityType.downloadedPosts,
    _at(18, 15),
    target: client,
    count: 2,
  );
  await rig.add(
    ActivityType.downloadedPosts,
    _at(12, 15),
    target: client,
    count: 9,
  );
}

/// Pumps [ActivityPage] in a router so taps can navigate. Destinations are
/// plain stand-ins that show their route in text.
Future<GoRouter> pumpActivity(
  WidgetTester tester,
  ActivityRig rig, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 1200),
  List<Override> extra = const [],
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = buildActivityRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...rig.overrides, ...extra],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.light
            ? StorizeTheme.light()
            : StorizeTheme.dark(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}

/// The router used by [pumpActivity].
GoRouter buildActivityRouter() => GoRouter(
  initialLocation: Routes.activityPath,
  routes: [
    GoRoute(path: Routes.activityPath, builder: (_, _) => const ActivityPage()),
    GoRoute(
      path: Routes.setupPath,
      builder: (_, _) => const Scaffold(body: Text('S-03 setup')),
    ),
    GoRoute(
      path: Routes.accountPath,
      builder: (_, _) => const Scaffold(body: Text('S-13 account')),
    ),
    GoRoute(
      path: '/story/:contentId',
      builder: (_, s) =>
          Scaffold(body: Text('S-06 story ${s.pathParameters['contentId']}')),
    ),
    GoRoute(
      path: '/post/:contentId',
      builder: (_, s) =>
          Scaffold(body: Text('S-15 post ${s.pathParameters['contentId']}')),
    ),
    GoRoute(
      path: Routes.libraryPath,
      builder: (_, _) => const Scaffold(body: Text('S-04 library')),
    ),
  ],
);
