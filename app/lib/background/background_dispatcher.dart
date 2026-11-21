import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:storize_app/background/background_router.dart';
import 'package:storize_app/core/composition.dart';
import 'package:storize_app/core/composition_production.dart';
import 'package:storize_data/log/log.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:workmanager/workmanager.dart';

/// The WorkManager entry point (TECH_SPEC section 2, `callbackDispatcher`).
///
/// Pass it to `Workmanager().initialize` in `main`. `vm:entry-point` keeps it
/// from being tree-shaken in release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask(
    runBackgroundTask,
    onTaskStopped: (task, reason) async {
      // WorkManager stopped the task (constraints lost, quota, timeout). Log
      // it; per-worker stop reasons are not available natively (TASKS T-005).
      try {
        final diagnostics = await StorizeDiagnostics.open();
        diagnostics.log.log(
          LogLevel.warn,
          'background',
          'task_stopped task=$task reason=${reason.name}',
        );
      } on Object {
        // Nothing to do: logging must never break the stop.
      }
    },
  );
}

/// Builds a composition for a background task.
typedef BackgroundCompose = Future<AppComposition> Function(
  StorizeDiagnostics diagnostics,
);

/// Opens diagnostics in a background isolate.
typedef OpenDiagnostics = Future<StorizeDiagnostics> Function();

/// The longest a task may take before it reports "retry" (WorkManager stops
/// a worker at 10 minutes; the use cases stop at about 8).
const Duration backgroundHardLimit = Duration(minutes: 9, seconds: 30);

/// Runs one background task in this isolate and returns the WorkManager
/// result: `true` done, `false` retry with back-off.
///
/// Order: plugins registered, diagnostics opened, the body runs inside
/// `CrashRecorder.runGuarded` (an uncaught error is recorded as a crash), the
/// composition is built (this opens the database), start-up work runs (crash
/// report, sweeps, gap detection), the task is routed, and the composition is
/// closed at the end, on every path.
///
/// [compose], [openDiagnostics] and [prepareIsolate] are injected by tests.
Future<bool> runBackgroundTask(
  String task,
  Map<String, dynamic>? input, {
  BackgroundCompose? compose,
  OpenDiagnostics? openDiagnostics,
  void Function()? prepareIsolate,
  Duration hardLimit = backgroundHardLimit,
}) async {
  (prepareIsolate ?? _prepareIsolate)();
  StorizeDiagnostics diagnostics;
  try {
    diagnostics = await (openDiagnostics ?? StorizeDiagnostics.open)();
  } on Object {
    // Run the task rather than skip it: log into a throwaway directory.
    diagnostics = StorizeDiagnostics.create(
      Directory.systemTemp.createTempSync('storize_bg'),
      clock: const SystemClock(),
      release: true,
    );
  }

  Future<bool> body() async {
    final build =
        compose ?? (d) => composeProduction(background: true, diagnostics: d);
    final c = await build(diagnostics);
    try {
      await c.start();
      return await routerFor(c).route(task, input);
    } finally {
      await c.dispose();
    }
  }

  final done = Completer<bool>();
  void run() => body().then(
    done.complete,
    onError: (Object error) {
      if (!done.isCompleted) done.complete(false);
    },
  );
  diagnostics.recorder.runGuarded(run);
  return done.future.timeout(hardLimit, onTimeout: () => false);
}

void _prepareIsolate() {
  WidgetsFlutterBinding.ensureInitialized();
  // Register plugins in this isolate before the database, the secure storage
  // and the WebView are touched (status file, T-021 carry-forward).
  DartPluginRegistrant.ensureInitialized();
}
