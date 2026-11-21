import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/account/account_page.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_app/ui/ui.dart';

import '../settings/settings_rig.dart';

/// Pumps [AccountPage] in a router. Destinations are stand-ins.
Future<void> pumpAccount(
  WidgetTester tester,
  SettingsRig rig, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.accountPath,
    routes: [
      GoRoute(
        path: Routes.accountPath,
        builder: (_, _) => const AccountPage(),
      ),
      GoRoute(
        path: Routes.loginPath,
        builder: (_, _) => const Scaffold(body: Text('S-02 login')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
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
  await tester.pumpAndSettle();
}
