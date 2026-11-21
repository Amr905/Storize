import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/library/library_services.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/features/targets/targets_page.dart';
import 'package:storize_app/features/targets/targets_providers.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// "Now" in every targets test: 2026-11-21 12:00 local time.
final DateTime targetsNow = DateTime(2026, 11, 21, 12);

/// A [CheckNowAction] that counts calls and can hold a run open.
class FakeCheckNow implements CheckNowAction {
  /// Result returned by the run.
  CheckNowResult result = const CheckNowResult(newItems: 2);

  /// When set, the run waits for this before completing.
  Completer<void>? gate;

  /// Number of runs started.
  int calls = 0;

  /// The `targetId` of each run (null = all).
  final List<int?> targetIds = [];

  @override
  Future<CheckNowResult> call({int? targetId}) async {
    calls++;
    targetIds.add(targetId);
    final g = gate;
    if (g != null) await g.future;
    return result;
  }
}

/// Fakes and seed helpers for S-07 and S-08 tests.
class TargetsRig {
  TargetsRig() : clock = FakeClock(targetsNow.toUtc()) {
    activity = FakeActivityRepo(clock);
  }

  final FakeClock clock;
  final FakeTargetRepo targets = FakeTargetRepo();
  final FakeAccountRepo accounts = FakeAccountRepo();
  late final FakeActivityRepo activity;
  final FakeContentPlatform platform = FakeContentPlatform();
  final FakeScheduler scheduler = FakeScheduler();
  final FakeCheckNow checkNow = FakeCheckNow();

  /// Adds a target with a remote user ID derived from [username].
  Future<Target> addTarget(
    String username, {
    TargetStatus status = TargetStatus.active,
    TargetCategory category = TargetCategory.ownClient,
    DateTime? lastStoriesCheckAt,
    DateTime? lastNewStoryAt,
    String? remoteUserId,
  }) => targets.insert(
    Target(
      id: Target.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: remoteUserId ?? 'uid-$username',
      username: username,
      category: category,
      status: status,
      postsWatermarkAt: DateTime.utc(2026),
      addedAt: DateTime.utc(2026),
      lastStoriesCheckAt: lastStoriesCheckAt?.toUtc(),
      lastNewStoryAt: lastNewStoryAt?.toUtc(),
    ),
  );

  /// Stores the logged-in account with [status].
  Future<void> addAccount({
    AccountStatus status = AccountStatus.active,
    String username = 'loginacc',
  }) async {
    await accounts.upsert(
      LoginAccount(
        id: LoginAccount.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: 'login-uid',
        username: username,
        status: status,
        connectedAt: DateTime.utc(2026),
      ),
    );
  }

  List<Override> get overrides => [
    targetRepoProvider.overrideWithValue(targets),
    accountRepoProvider.overrideWithValue(accounts),
    activityRepoProvider.overrideWithValue(activity),
    clockProvider.overrideWithValue(clock),
    contentPlatformProvider.overrideWithValue(platform),
    schedulerProvider.overrideWithValue(scheduler),
    checkNowActionProvider.overrideWithValue(checkNow),
  ];
}

/// An S-08 form fixed to [value], for golden states.
class FixedAddForm extends AddTargetFormController {
  /// Creates the fixed notifier.
  FixedAddForm(this.value);

  /// The state to show.
  final AddTargetForm value;

  @override
  AddTargetForm build() => value;
}

/// Pumps the targets pages in a router so pushes and pops work. `initial` is
/// the location; `/targets` shows S-07, `/targets/add` shows S-08.
Future<GoRouter> pumpTargets(
  WidgetTester tester, {
  required TargetsRig rig,
  String initial = Routes.targetsPath,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
  List<Override> extra = const [],
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: Routes.targetsPath,
        builder: (_, _) => const TargetsPage(),
      ),
      GoRoute(
        path: Routes.addTargetPath,
        builder: (_, _) => const AddTargetPage(),
      ),
      GoRoute(
        path: '/targets/:targetId',
        builder: (_, state) =>
            Scaffold(body: Text('S-09 ${state.pathParameters['targetId']}')),
      ),
    ],
  );
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
