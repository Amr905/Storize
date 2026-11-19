import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';

/// Scaffold with the 4-tab bottom navigation. Each tab is a branch of the
/// [StatefulNavigationShell] and keeps its own back stack.
class AppShell extends StatelessWidget {
  /// Creates the shell around [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// The branch container.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Standard Android bottom-nav back: from the root of any other tab go to
    // Library first; from the Library root the app exits. Pages pushed inside
    // a tab are popped by the nested navigator before this is consulted.
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            // Tapping the active tab returns to its root.
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.photo_library_outlined),
              selectedIcon: const Icon(Icons.photo_library),
              label: l10n.navLibrary,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: l10n.navTargets,
            ),
            NavigationDestination(
              icon: const Icon(Icons.notifications_none),
              selectedIcon: const Icon(Icons.notifications),
              label: l10n.navActivity,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
