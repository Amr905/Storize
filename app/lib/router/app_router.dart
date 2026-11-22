import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/account/account_page.dart';
import 'package:storize_app/features/activity/activity_page.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/lock/lock_page.dart';
import 'package:storize_app/features/onboarding/login_page.dart';
import 'package:storize_app/features/onboarding/setup_page.dart';
import 'package:storize_app/features/onboarding/welcome_page.dart';
import 'package:storize_app/features/settings/settings_page.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/features/targets/target_detail_page.dart';
import 'package:storize_app/features/targets/targets_page.dart';
import 'package:storize_app/features/viewer/post_viewer_page.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_app/router/app_shell.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_app/router/routes.dart';

/// The location to open at launch. Null means the Library. Tests override it.
final Provider<String?> initialLocationProvider = Provider<String?>(
  (ref) => null,
);

/// The app's [GoRouter]. Re-evaluates the gates whenever
/// [onboardingCompleteProvider] or [appLockedProvider] change.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(onboardingCompleteProvider, (_, _) => refresh.value++)
    ..listen(appLockedProvider, (_, _) => refresh.value++);
  final router = createRouter(
    isOnboardingComplete: () => ref.read(onboardingCompleteProvider),
    isLocked: () => ref.read(appLockedProvider),
    refreshListenable: refresh,
    initialLocation: ref.read(initialLocationProvider),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Paths that stay reachable while onboarding is incomplete.
const Set<String> _onboardingPaths = {
  Routes.welcomePath,
  Routes.loginPath,
  Routes.setupPath,
};

/// Builds the router. Separate from [routerProvider] so it can be tested
/// without Riverpod.
GoRouter createRouter({
  required bool Function() isOnboardingComplete,
  required bool Function() isLocked,
  Listenable? refreshListenable,
  String? initialLocation,
}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation ?? Routes.libraryPath,
    refreshListenable: refreshListenable,
    // Any location that matches no route (`/unknown`, `/library//`, `http://`
    // links, an unsafe `from`) lands on the Library, and the URL becomes
    // `/library`.
    onException: (_, _, router) => router.go(Routes.libraryPath),
    redirect: (context, state) => _redirect(
      state.uri,
      isOnboardingComplete: isOnboardingComplete(),
      isLocked: isLocked(),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.libraryPath),
      // Onboarding (S-01, S-02, S-03) and lock (S-14).
      GoRoute(
        path: Routes.welcomePath,
        name: Routes.welcome,
        builder: (_, _) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.loginPath,
        name: Routes.login,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.setupPath,
        name: Routes.setup,
        builder: (_, _) => const SetupPage(),
      ),
      GoRoute(
        path: Routes.lockPath,
        name: Routes.lock,
        builder: (_, _) => const LockPage(),
      ),
      // Full-screen pages above the tab shell.
      GoRoute(
        path: '/story/:contentId',
        name: Routes.storyViewer,
        redirect: _invalidIdToLibrary('contentId'),
        builder: (_, state) => StoryViewerPage(
          contentId: parseId(state.pathParameters['contentId'])!,
        ),
      ),
      GoRoute(
        path: '/post/:contentId',
        name: Routes.postViewer,
        redirect: _invalidIdToLibrary('contentId'),
        builder: (_, state) => PostViewerPage(
          contentId: parseId(state.pathParameters['contentId'])!,
        ),
      ),
      GoRoute(
        path: Routes.addTargetPath,
        name: Routes.addTarget,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const AddTargetPage(),
      ),
      GoRoute(
        path: Routes.accountPath,
        name: Routes.account,
        builder: (_, _) => const AccountPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.libraryPath,
                name: Routes.library,
                builder: (_, state) => LibraryPage(
                  kind: parseKind(state.uri.queryParameters['kind']),
                  targetId: parseId(state.uri.queryParameters['target']),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.targetsPath,
                name: Routes.targets,
                builder: (_, _) => const TargetsPage(),
                routes: [
                  // Declared after the 'add' route at the root, but its path
                  // is `/targets/:targetId`, so 'add' must not match it:
                  // the top-level '/targets/add' route is listed first.
                  GoRoute(
                    path: ':targetId',
                    name: Routes.targetDetail,
                    redirect: _invalidIdToTargets,
                    builder: (_, state) => TargetDetailPage(
                      targetId: parseId(state.pathParameters['targetId'])!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.activityPath,
                name: Routes.activity,
                builder: (_, _) => const ActivityPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settingsPath,
                name: Routes.settings,
                builder: (_, state) => SettingsPage(
                  section: SettingsSection.values
                      .where(
                        (s) => s.name == state.uri.queryParameters['section'],
                      )
                      .firstOrNull,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

GoRouterRedirect _invalidIdToLibrary(String param) =>
    (_, state) => parseId(state.pathParameters[param]) == null
    ? Routes.libraryPath
    : null;

String? _invalidIdToTargets(BuildContext _, GoRouterState state) =>
    parseId(state.pathParameters['targetId']) == null
    ? Routes.targetsPath
    : null;

/// Maps `storize://` links, then applies the lock and onboarding gates.
///
/// A gated destination is kept in `?from=` and restored once the gate opens,
/// so a deep link survives the gate.
String? _redirect(
  Uri uri, {
  required bool isOnboardingComplete,
  required bool isLocked,
}) {
  var target = uri;
  final link = DeepLink.parse(uri);
  if (link != null) target = Uri.parse(link.location);

  String? result;
  if (isLocked) {
    if (target.path != Routes.lockPath) {
      result = _withFrom(Routes.lockPath, target);
    }
  } else if (target.path == Routes.lockPath) {
    result = _fromOrLibrary(target);
  } else if (!isOnboardingComplete) {
    if (!_onboardingPaths.contains(target.path)) {
      result = _withFrom(Routes.welcomePath, target);
    }
  } else if (target.path == Routes.welcomePath) {
    result = _fromOrLibrary(target);
  }
  if (result != null) return result;
  return link == null ? null : target.toString();
}

String _withFrom(String path, Uri destination) => Uri(
  path: path,
  queryParameters: {'from': destination.toString()},
).toString();

/// The `from` location if it is a safe in-app path, else the Library.
String _fromOrLibrary(Uri gate) {
  final from = gate.queryParameters['from'];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return Routes.libraryPath;
  }
  final parsed = Uri.tryParse(from);
  if (parsed == null ||
      parsed.hasScheme ||
      parsed.path == Routes.lockPath ||
      parsed.path == Routes.welcomePath) {
    return Routes.libraryPath;
  }
  return from;
}
