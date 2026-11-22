import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_app/background/background_dispatcher.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_app/core/composition_production.dart';
import 'package:storize_app/notifications/notification_taps.dart';
import 'package:storize_app/router/app_router.dart';
import 'package:storize_app/startup_error.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:workmanager/workmanager.dart';

/// App entry point.
///
/// Diagnostics are opened first, because the crash hooks need the log
/// instance (TECH_SPEC section 8). Then the composition root is built
/// ([buildApp]) and the app runs with its providers wired.
///
/// Opening diagnostics must never stop the app, so a failure there is ignored
/// and the app starts without crash logging.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = await installDiagnostics();
  runApp(await buildApp(diagnostics: diagnostics));
}

/// Builds the foreground composition and the app widget.
///
/// Order: the composition opens the database; WorkManager gets the background
/// entry point; the app widget is returned with every provider overridden;
/// then, without holding up the first frame, [AppComposition.start] runs (crash
/// report, sweeps, gap detection) and the periodic tasks are registered from
/// the settings and kept in step with them. Registering at each start is what
/// brings the tasks back after a force-stop.
///
/// If the composition cannot be built the error is logged and the app starts
/// unwired (its screens show the framework error widget), instead of a blank
/// screen.
Future<Widget> buildApp({
  StorizeDiagnostics? diagnostics,
  Future<AppComposition> Function(StorizeDiagnostics)? compose,
  Future<void> Function()? initializeWorkmanager,
}) async {
  final d =
      diagnostics ??
      StorizeDiagnostics.create(
        Directory.systemTemp.createTempSync('storize_fg'),
        clock: const SystemClock(),
        release: true,
      );
  try {
    final composition =
        await (compose ??
            (log) => composeProduction(background: false, diagnostics: log))(d);
    await (initializeWorkmanager ??
        () => Workmanager().initialize(callbackDispatcher))();
    unawaited(_startUp(composition));
    // A notification that launched the app opens its screen at start-up.
    final launch = await composition.parts.notifications?.launchLocation();
    return StorizeApp(
      overrides: [
        ...appOverrides(composition),
        if (launch != null) initialLocationProvider.overrideWithValue(launch),
        if (composition.parts.notifications case final n?)
          notificationTapsProvider.overrideWith((ref) => n.taps),
      ],
    );
  } on Object catch (error, stack) {
    d.log.log(
      LogLevel.error,
      'start',
      'composition_failed type=${error.runtimeType}',
      stack: stack,
    );
    return StartupErrorApp(error: error, stack: stack);
  }
}

Future<void> _startUp(AppComposition composition) async {
  // Subscribe first: the first emission registers the tasks even if the
  // start-up work below is slow.
  composition.keepScheduleApplied();
  // Foreground only: a background task must not wipe a running login.
  await composition.clearStagingSession();
  await composition.start();
}

/// Opens [StorizeDiagnostics] and installs the crash hooks. Returns null if
/// that failed.
///
/// `runApp` is not wrapped in a zone (that would mismatch the binding's zone);
/// `PlatformDispatcher.onError` covers uncaught async errors instead. The
/// background dispatcher (T-021) uses `CrashRecorder.runGuarded`.
Future<StorizeDiagnostics?> installDiagnostics({
  Future<StorizeDiagnostics> Function() open = StorizeDiagnostics.open,
}) async {
  try {
    final diagnostics = await open();
    diagnostics.installCrashHooks();
    return diagnostics;
  } on Object {
    return null;
  }
}
