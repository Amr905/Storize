import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/providers.dart';
import 'package:storize_app/features/onboarding/login_lease.dart';
import 'package:storize_app/features/onboarding/login_page.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/features/onboarding/onboarding_providers.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_app/features/onboarding/setup_page.dart';
import 'package:storize_app/features/onboarding/welcome_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

/// A fake login WebView. Tests drive it through [events].
class FakeWeb implements LoginWebViewController {
  Map<String, String> cookies = {};
  int clears = 0;
  int reloads = 0;
  LoginWebViewEvents? events;

  @override
  Future<Map<String, String>> readCookies() async => cookies;

  @override
  Future<String?> userAgent() async => 'UA';

  @override
  Future<void> clearData() async {
    clears++;
    cookies = {};
  }

  @override
  Future<void> reload() async => reloads++;
}

/// Lease double that records calls.
class FakeLease implements LoginLease {
  bool available = true;

  /// Refusals before [available] applies (a slow first database open).
  int refuseFirst = 0;
  final List<String> calls = [];
  final StreamController<void> lost = StreamController<void>.broadcast();

  @override
  Future<bool> tryAcquire(String owner) async {
    calls.add('acquire:$owner');
    if (refuseFirst > 0) {
      refuseFirst--;
      return false;
    }
    return available;
  }

  @override
  Future<void> release(String owner) async => calls.add('release:$owner');

  @override
  Stream<void> get onLost => lost.stream;
}

/// Device double for S-03.
class FakeSetupOps implements SetupOps {
  bool notif = false;
  bool battery = false;
  bool storage = false;
  String oem = 'samsung';
  int sdk = 34;
  PermissionOutcome notifOutcome = PermissionOutcome.denied;
  int batteryOpens = 0;
  int settingsOpens = 0;

  @override
  Future<bool> notificationsAllowed() async => notif;

  @override
  Future<PermissionOutcome> requestNotifications() async => notifOutcome;

  @override
  Future<bool> batteryUnrestricted() async => battery;

  @override
  Future<void> openBatterySettings() async => batteryOpens++;

  @override
  Future<String> manufacturer() async => oem;

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<bool> storageGranted() async => storage;

  @override
  Future<PermissionOutcome> requestStorage() async => PermissionOutcome.denied;

  @override
  Future<void> openAppSettings() async => settingsOpens++;
}

/// Everything a test needs.
class OnbRig {
  final web = FakeWeb();
  final lease = FakeLease();
  final ops = FakeSetupOps();
  final sessions = FakeSessionStore();
  final platform = FakeContentPlatform();
  final accounts = FakeAccountRepo();
  final settings = FakeSettingsRepo();
  final clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
  LoginWebViewEvents? events;
  late ProviderContainer container;
  late GoRouter router;

  static const goodCookies = {
    'sessionid': 'SECRET-SESSION',
    'ds_user_id': '42',
    'csrftoken': 'SECRET-CSRF',
  };

  static RemoteUser user(String name, String id) => RemoteUser(
    remoteUserId: id,
    username: name,
    followedByViewer: false,
    blockedByViewer: false,
  );

  Widget fakeWebView(BuildContext context, LoginWebViewEvents e) {
    events = e;
    web.events = e;
    e.onReady(web);
    return const SizedBox.expand(key: ValueKey('fake-web'));
  }

  /// Pumps [initial] inside a router so `context.go` works.
  Future<void> pump(
    WidgetTester t, {
    String initial = Routes.welcomePath,
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 800),
    bool pushLogin = false,
    ContentPlatform? platformOverride,
    List<Duration> acquireBackoff = const [],
    AccountRepo? accountsOverride,
    SessionStore? sessionsOverride,
  }) async {
    t.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(t.view.reset);
    Widget stub(String name) => Scaffold(body: Text(name));
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: Routes.welcomePath,
          builder: (_, _) => const WelcomePage(),
        ),
        GoRoute(path: Routes.loginPath, builder: (_, _) => const LoginPage()),
        GoRoute(path: Routes.setupPath, builder: (_, _) => const SetupPage()),
        GoRoute(
          path: Routes.libraryPath,
          builder: (_, _) => stub('LIBRARY-STUB'),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        loginLeaseProvider.overrideWithValue(lease),
        loginAcquireBackoffProvider.overrideWithValue(acquireBackoff),
        loginWebViewBuilderProvider.overrideWithValue(fakeWebView),
        setupOpsProvider.overrideWithValue(ops),
        sessionStoreProvider.overrideWithValue(sessionsOverride ?? sessions),
        loginPlatformProvider.overrideWithValue(platformOverride ?? platform),
        accountRepoProvider.overrideWithValue(accountsOverride ?? accounts),
        settingsRepoProvider.overrideWithValue(settings),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('shot'),
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
      ),
    );
    await t.pump();
    await t.pump();
    if (pushLogin) {
      unawaited(router.push(Routes.loginPath));
      await t.pump();
      await t.pump();
    }
  }
}
