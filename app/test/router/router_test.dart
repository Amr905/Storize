import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/gates.dart';
import 'package:storize_app/features/account/account_page.dart';
import 'package:storize_app/features/activity/activity_page.dart';
import 'package:storize_app/features/library/library_page.dart';
import 'package:storize_app/features/library/library_providers.dart';
import 'package:storize_app/features/lock/lock_page.dart';
import 'package:storize_app/features/onboarding/login_page.dart';
import 'package:storize_app/features/onboarding/setup_page.dart';
import 'package:storize_app/features/onboarding/welcome_page.dart';
import 'package:storize_app/features/settings/settings_page.dart';
import 'package:storize_app/features/targets/add_target_page.dart';
import 'package:storize_app/features/targets/targets_page.dart';
import 'package:storize_app/features/viewer/story_viewer_page.dart';
import 'package:storize_app/router/deep_link.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import '../helpers/app_harness.dart';

void main() {
  group('routes', () {
    testWidgets('launches on the Library tab with 4 tabs', (t) async {
      final h = await pumpApp(t);
      expect(h.location, '/library');
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      for (final label in ['Library', 'Targets', 'Activity', 'Settings']) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byType(LibraryPage), findsOneWidget);
    });

    testWidgets('every screen resolves to its placeholder', (t) async {
      final h = await pumpApp(t);
      const cases = {
        '/post/3': 'TODO(T-029)',
        '/targets/9': 'TODO(T-031)',
      };
      for (final e in cases.entries) {
        await h.go(e.key);
        expect(find.text(e.value), findsOneWidget, reason: e.key);
      }
      await h.go('/story/3');
      expect(_story(3), findsOneWidget, reason: '/story/3');
      // Onboarding pages are real. S-01 redirects to the Library once
      // onboarding is complete, so it is covered by the gates group.
      await h.go('/targets');
      expect(find.byType(TargetsPage), findsOneWidget, reason: '/targets');
      await h.go('/targets/add');
      expect(
        find.byType(AddTargetPage),
        findsOneWidget,
        reason: '/targets/add',
      );
      await h.go('/settings');
      expect(find.byType(SettingsPage), findsOneWidget, reason: '/settings');
      await h.go('/account');
      expect(find.byType(AccountPage), findsOneWidget, reason: '/account');
      await h.go('/login');
      expect(find.byType(LoginPage), findsOneWidget, reason: '/login');
      await h.go('/setup');
      expect(find.byType(SetupPage), findsOneWidget, reason: '/setup');
      await h.go('/library');
      expect(find.byType(LibraryPage), findsOneWidget, reason: '/library');
      await h.go('/activity');
      expect(find.byType(ActivityPage), findsOneWidget, reason: '/activity');
      // The lock page is only reachable while locked.
      expect(Routes.lockPath, '/lock');
    });

    testWidgets('invalid ids in app routes go to a safe screen', (t) async {
      final h = await pumpApp(t);
      await h.go('/story/abc');
      expect(h.location, '/library');
      await h.go('/post/0');
      expect(h.location, '/library');
      await h.go('/targets/abc');
      expect(h.location, '/targets');
    });

    testWidgets('typed location helpers', (t) async {
      final h = await pumpApp(t);
      await h.go(Routes.storyLocation(5));
      expect(_story(5), findsOneWidget);
      await h.go(Routes.targetDetailLocation(8));
      expect(find.text('targetId=8'), findsOneWidget);
      await h.go(Routes.settingsLocation());
      expect(h.location, '/settings');
    });
  });

  group('deep links', () {
    testWidgets('storize://story/{id} opens S-06', (t) async {
      final h = await pumpApp(t);
      await h.go('storize://story/12');
      expect(h.location, '/story/12');
      expect(_story(12), findsOneWidget);
    });

    testWidgets('storize://post/{id} opens S-15', (t) async {
      final h = await pumpApp(t);
      await h.go('storize://post/13');
      expect(h.location, '/post/13');
      expect(find.text('contentId=13'), findsOneWidget);
    });

    testWidgets('storize://account opens S-13', (t) async {
      final h = await pumpApp(t);
      await h.go('storize://account');
      expect(h.location, '/account');
      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('storize://library keeps its filters', (t) async {
      final h = await pumpApp(t);
      await h.go('storize://library?kind=posts&target=5');
      expect(h.location, '/library?kind=posts&target=5');
      final page = t.widget<LibraryPage>(find.byType(LibraryPage));
      expect(page.kind, ContentKind.post);
      expect(page.targetId, 5);
      // The page applied the parameters to its state.
      expect(h.container.read(libraryKindProvider), LibraryKind.posts);
      expect(h.container.read(libraryFiltersProvider).targetIds, {5});
    });

    testWidgets('storize://settings/storage opens S-12 at storage', (t) async {
      final h = await pumpApp(t);
      await h.go('storize://settings/storage');
      expect(h.location, '/settings?section=storage');
      expect(
        find.byWidgetPredicate(
          (w) => w is SettingsPage && w.section == SettingsSection.storage,
        ),
        findsOneWidget,
      );
    });

    for (final bad in [
      'storize://story/abc',
      'storize://post/-1',
      'storize://library?kind=x&target=y',
      'storize://unknown/thing',
    ]) {
      testWidgets('invalid "$bad" goes to the Library without crashing', (
        t,
      ) async {
        final h = await pumpApp(t, initialLocation: '/targets');
        await h.go(bad);
        expect(h.location, '/library');
        expect(find.byType(LibraryPage), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('a link used as the launch location works', (t) async {
      final h = await pumpApp(t, initialLocation: 'storize://story/21');
      expect(h.location, '/story/21');
      expect(_story(21), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('each tab keeps its own back stack', (t) async {
      final h = await pumpApp(t);
      Future<void> tapTab(String label) async {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await t.pumpAndSettle();
      }

      await tapTab('Targets');
      await h.push('/targets/9');
      expect(find.text('targetId=9'), findsOneWidget);

      await tapTab('Library');
      expect(find.byType(LibraryPage), findsOneWidget);
      expect(find.text('targetId=9'), findsNothing);

      await tapTab('Targets');
      expect(find.text('targetId=9'), findsOneWidget);
      expect(h.location, '/targets/9');

      // Tapping the active tab pops back to its root.
      await tapTab('Targets');
      expect(find.byType(TargetsPage), findsOneWidget);
      expect(find.text('targetId=9'), findsNothing);
    });

    testWidgets('back from a tab detail returns to the tab root', (t) async {
      final h = await pumpApp(t);
      await h.go('/targets');
      await h.push('/targets/4');
      h.router.pop();
      await t.pumpAndSettle();
      expect(h.location, '/targets');
    });

    testWidgets('nav items are at least 48dp and RTL works', (t) async {
      await pumpApp(t, textDirection: TextDirection.rtl);
      for (final d in t.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      )) {
        final box = t.getSize(find.byWidget(d));
        expect(box.height, greaterThanOrEqualTo(48));
      }
      // First tab (Library) is on the right in RTL.
      final library = t.getCenter(find.text('Library').last);
      final settings = t.getCenter(find.text('Settings').last);
      expect(library.dx, greaterThan(settings.dx));
    });
  });

  group('gates', () {
    testWidgets('open gates leave navigation alone', (t) async {
      final h = await pumpApp(t, overrides: defaultGateOverrides);
      await h.go('/targets');
      expect(h.location, '/targets');
    });

    testWidgets('incomplete onboarding redirects to S-01', (t) async {
      final h = await pumpApp(
        t,
        overrides: [onboardingCompleteProvider.overrideWithValue(false)],
      );
      expect(h.location.startsWith('/welcome'), isTrue);
      expect(find.byType(WelcomePage), findsOneWidget);
      // The onboarding pages stay reachable.
      await h.go('/login');
      expect(h.location, '/login');
      await h.go('/setup');
      expect(h.location, '/setup');
      // Everything else is gated.
      await h.go('/targets');
      expect(h.location.startsWith('/welcome'), isTrue);
    });

    testWidgets('locked app redirects to S-14', (t) async {
      final h = await pumpApp(
        t,
        overrides: [appLockedProvider.overrideWithValue(true)],
      );
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.byType(LockPage), findsOneWidget);
      await h.go('/settings');
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('lock wins over onboarding', (t) async {
      final h = await pumpApp(
        t,
        overrides: [
          appLockedProvider.overrideWithValue(true),
          onboardingCompleteProvider.overrideWithValue(false),
        ],
      );
      expect(h.location.startsWith('/lock'), isTrue);
    });

    testWidgets('unlocking continues to the original location', (t) async {
      final g = gate(appLockedProvider, initial: true);
      final h = await pumpApp(
        t,
        initialLocation: '/targets/3',
        overrides: g.overrides,
      );
      expect(h.location.startsWith('/lock'), isTrue);
      h.container.read(g.flag.notifier).set(value: false);
      await t.pumpAndSettle();
      expect(h.location, '/targets/3');
      expect(find.text('targetId=3'), findsOneWidget);
    });

    testWidgets('a deep link survives the lock gate', (t) async {
      final g = gate(appLockedProvider, initial: true);
      final h = await pumpApp(
        t,
        initialLocation: 'storize://story/77',
        overrides: g.overrides,
      );
      expect(h.location.startsWith('/lock'), isTrue);
      expect(find.byType(LockPage), findsOneWidget);
      h.container.read(g.flag.notifier).set(value: false);
      await t.pumpAndSettle();
      expect(h.location, '/story/77');
      expect(_story(77), findsOneWidget);
    });

    testWidgets('a deep link opened while locked survives too', (t) async {
      final g = gate(appLockedProvider, initial: false);
      final h = await pumpApp(t, overrides: g.overrides);
      h.container.read(g.flag.notifier).set(value: true);
      await t.pumpAndSettle();
      expect(h.location.startsWith('/lock'), isTrue);
      await h.go('storize://post/5');
      expect(h.location.startsWith('/lock'), isTrue);
      h.container.read(g.flag.notifier).set(value: false);
      await t.pumpAndSettle();
      expect(h.location, '/post/5');
    });

    testWidgets('a deep link survives the onboarding gate', (t) async {
      final g = gate(onboardingCompleteProvider, initial: false);
      final h = await pumpApp(
        t,
        initialLocation: 'storize://post/8',
        overrides: g.overrides,
      );
      expect(h.location.startsWith('/welcome'), isTrue);
      h.container.read(g.flag.notifier).set(value: true);
      await t.pumpAndSettle();
      expect(h.location, '/post/8');
      expect(find.text('contentId=8'), findsOneWidget);
    });

    testWidgets('an unsafe from= is ignored', (t) async {
      final h = await pumpApp(
        t,
        overrides: [appLockedProvider.overrideWithValue(false)],
      );
      for (final from in ['https://evil.example', '//evil.example/x']) {
        await h.go(
          Uri(path: '/lock', queryParameters: {'from': from}).toString(),
        );
        expect(h.location, '/library', reason: from);
      }
    });

    testWidgets('gate pages redirect away when the gate is open', (t) async {
      final h = await pumpApp(t);
      await h.go('/lock');
      expect(h.location, '/library');
      await h.go('/welcome');
      expect(h.location, '/library');
    });
  });

  testWidgets('router is a GoRouter', (t) async {
    final h = await pumpApp(t);
    expect(h.router, isA<GoRouter>());
  });
}

Finder _story(int id) => find.byWidgetPredicate(
  (w) => w is StoryViewerPage && w.contentId == id,
  description: 'StoryViewerPage(contentId: $id)',
);
