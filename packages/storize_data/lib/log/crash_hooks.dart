import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:storize_data/log/crash_marker.dart';
import 'package:storize_domain/storize_domain.dart';

/// Writes uncaught errors to the [DiagnosticLog] and the [CrashMarker].
///
/// One recorder serves the three entry points: the Flutter framework
/// ([CrashHooks.install]), the platform dispatcher (same call) and zones
/// ([runGuarded], for the background dispatcher of T-021).
final class CrashRecorder {
  /// Creates a recorder.
  CrashRecorder({required this.log, required this.marker, required this.clock});

  /// Where errors are logged (redacted by the implementation).
  final DiagnosticLog log;

  /// Where the next-start marker is written.
  final CrashMarker marker;

  /// The time source for the marker.
  final Clock clock;

  /// Logs [error] at ERROR level under tag `crash`, with [source] naming the
  /// hook. With [fatal] true (the default) it also writes the crash marker;
  /// non-fatal errors (such as `FlutterError.onError`, where the app keeps
  /// running) are only logged. Never throws, and the marker is written even
  /// if logging throws.
  void record(
    Object error,
    StackTrace? stack, {
    required String source,
    bool fatal = true,
  }) {
    try {
      log.log(
        LogLevel.error,
        'crash',
        'uncaught error ($source)',
        error: error,
        stack: stack,
      );
    } on Object {
      // A crash handler must not crash.
    }
    if (!fatal) return;
    try {
      marker.write(error, clock.now());
    } on Object {
      // A crash handler must not crash.
    }
  }

  /// Runs [body] in a guarded zone: errors that nothing else catches are
  /// recorded with source `zone` instead of killing the isolate silently.
  ///
  /// Use it as the root of the background dispatcher (T-021). Returns what
  /// [body] returns, or null if it threw synchronously. For async work pass an
  /// async [body]; its unhandled errors reach the zone handler.
  ///
  /// The foreground app does not wrap `runApp` in this (that causes a zone
  /// mismatch with `WidgetsFlutterBinding`); it relies on [CrashHooks.install].
  R? runGuarded<R>(R Function() body) => runZonedGuarded<R>(
    body,
    (error, stack) => record(error, stack, source: 'zone'),
  );
}

/// Installed crash hooks. Call [uninstall] to restore the previous handlers
/// (tests do this; the app never does).
final class CrashHooks {
  CrashHooks._(
    this._recorder,
    this._dispatcher,
    this._previousFlutter,
    this._previousDispatcher,
    this._flutterHandler,
    this._dispatcherHandler,
  );

  final CrashRecorder _recorder;
  final PlatformDispatcher _dispatcher;
  final FlutterExceptionHandler? _previousFlutter;
  final ErrorCallback? _previousDispatcher;
  final FlutterExceptionHandler _flutterHandler;
  final ErrorCallback _dispatcherHandler;

  /// The recorder the hooks write to.
  CrashRecorder get recorder => _recorder;

  /// Sets `FlutterError.onError` and `PlatformDispatcher.onError` to record
  /// through [recorder]. Only `PlatformDispatcher.onError` (and `runGuarded`)
  /// write the APP_CRASH marker; `FlutterError.onError` errors (a layout
  /// overflow, a failed image decode) are logged at ERROR but the app keeps
  /// running, so they leave no marker.
  ///
  /// Framework errors are also shown on the console in debug builds only
  /// (the console copy is not redacted, so release builds never print it).
  /// Uncaught async errors are reported as handled (`true`) so the app keeps
  /// running; there is no remote crash reporting (NFR-6).
  ///
  /// Pass [dispatcher] only in tests.
  // ignore: prefer_constructors_over_static_methods, installs global handlers.
  static CrashHooks install(
    CrashRecorder recorder, {
    PlatformDispatcher? dispatcher,
  }) {
    final platform = dispatcher ?? PlatformDispatcher.instance;
    final previousFlutter = FlutterError.onError;
    final previousDispatcher = platform.onError;

    void onFlutterError(FlutterErrorDetails details) {
      recorder.record(
        details.exception,
        details.stack,
        source: 'FlutterError.onError',
        fatal: false,
      );
      if (kDebugMode) FlutterError.presentError(details);
    }

    bool onPlatformError(Object error, StackTrace stack) {
      recorder.record(error, stack, source: 'PlatformDispatcher.onError');
      return true;
    }

    FlutterError.onError = onFlutterError;
    platform.onError = onPlatformError;
    return CrashHooks._(
      recorder,
      platform,
      previousFlutter,
      previousDispatcher,
      onFlutterError,
      onPlatformError,
    );
  }

  /// Restores the handlers that were set before [install], if the current
  /// ones are still ours.
  void uninstall() {
    if (FlutterError.onError == _flutterHandler) {
      FlutterError.onError = _previousFlutter;
    }
    if (_dispatcher.onError == _dispatcherHandler) {
      _dispatcher.onError = _previousDispatcher;
    }
  }
}
