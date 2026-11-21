import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/l10n/app_localizations.dart';
import 'package:storize_app/notifications/notification_taps.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_app/ui/ui.dart';

/// Root widget: `ProviderScope` then `MaterialApp.router`.
class StorizeApp extends StatelessWidget {
  /// Creates the app. [overrides] and [textDirection] exist for tests.
  const StorizeApp({
    this.overrides = const [],
    this.textDirection,
    super.key,
  });

  /// Provider overrides (tests, and real wiring from `main`).
  final List<Override> overrides;

  /// Forces a text direction (RTL test hook). Null follows the locale.
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: overrides,
    child: _StorizeAppView(textDirection: textDirection),
  );
}

class _StorizeAppView extends ConsumerWidget {
  const _StorizeAppView({this.textDirection});

  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationTapsProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        ref.read(routerProvider).go(value);
      }
    });
    final forced = textDirection;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: StorizeTheme.light(),
      darkTheme: StorizeTheme.dark(),
      // themeMode stays at its default, ThemeMode.system (UQ-1).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: forced == null
          ? null
          : (context, child) =>
                Directionality(textDirection: forced, child: child!),
    );
  }
}
