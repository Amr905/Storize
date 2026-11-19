import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/lock/lock_controller.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// A login account with the given [status].
LoginAccount account(AccountStatus status) => LoginAccount(
  id: LoginAccount.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: '1',
  username: 'tester',
  status: status,
  connectedAt: DateTime.utc(2026),
);

/// Gate state that tests can flip at runtime.
class GateFlag extends Notifier<bool> {
  GateFlag(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  // A named-parameter setter reads better at call sites than a setter.
  // ignore: use_setters_to_change_properties
  void set({required bool value}) => state = value;
}

/// Everything a test needs after [pumpApp].
class AppHarness {
  AppHarness(this.tester, this.container, this.accounts);

  final WidgetTester tester;
  final ProviderContainer container;
  final FakeAccountRepo accounts;

  GoRouter get router => container.read(routerProvider);

  /// The visible location, including pages added with `push`.
  String get location {
    final config = router.routerDelegate.currentConfiguration;
    final top = config.last;
    return (top is ImperativeRouteMatch ? top.matches.uri : config.uri)
        .toString();
  }

  /// Navigates and settles.
  Future<void> go(String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  /// Pushes and settles.
  Future<void> push(String location) async {
    unawaited(router.push<void>(location));
    await tester.pumpAndSettle();
  }
}

void unawaited(Future<void> f) {}

/// Pumps [StorizeApp] with fakes. Pass [overrides] to replace any provider.
Future<AppHarness> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  String? initialLocation,
  TextDirection? textDirection,
  FakeAccountRepo? accounts,
  bool bypassLock = true,
}) async {
  final repo = accounts ?? FakeAccountRepo();
  await tester.pumpWidget(
    StorizeApp(
      textDirection: textDirection,
      overrides: [
        accountRepoProvider.overrideWithValue(repo),
        initialLocationProvider.overrideWithValue(initialLocation),
        // The lock is fail-closed; other screens' tests opt out here. Lock
        // tests pass bypassLock: false.
        if (bypassLock) appLockTestBypassProvider.overrideWithValue(true),
        ...overrides,
      ],
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return AppHarness(tester, container, repo);
}

/// Overrides a gate provider with a flag that [GateFlag.set] can flip.
({List<Override> overrides, NotifierProvider<GateFlag, bool> flag}) gate(
  Provider<bool> target, {
  required bool initial,
}) {
  final flag = NotifierProvider<GateFlag, bool>(() => GateFlag(initial));
  return (
    overrides: [target.overrideWith((ref) => ref.watch(flag))],
    flag: flag,
  );
}

/// Convenience for the default (no gates) provider values.
final defaultGateOverrides = <Override>[
  onboardingCompleteProvider.overrideWithValue(true),
  appLockedProvider.overrideWithValue(false),
];
