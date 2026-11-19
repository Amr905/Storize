import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storize_data/log/crash_hooks.dart';
import 'package:storize_data/log/crash_marker.dart';
import 'package:storize_data/log/file_diagnostic_log.dart';
import 'package:storize_data/log/rotating_log_file.dart';
// TODO(lead): drop once `ports/diagnostic_log.dart` is exported by the barrel.
// ignore: implementation_imports
import 'package:storize_domain/src/ports/diagnostic_log.dart';
import 'package:storize_domain/storize_domain.dart';

/// The diagnostics bundle: the log, the crash marker and the recorder, all
/// rooted in one directory. Both the app `main` and the background dispatcher
/// (T-021) open one.
///
/// Files live under the app support directory: `logs/storize.log` (plus `.1`
/// and `.2`) and `logs/crash_marker.json`. They are private to the app.
final class StorizeDiagnostics {
  StorizeDiagnostics._(this.log, this.marker, this.recorder, this.files);

  /// Builds diagnostics synchronously in [directory].
  factory StorizeDiagnostics.create(
    Directory directory, {
    required Clock clock,
    required bool release,
  }) {
    final files = RotatingLogFile(directory);
    final log = FileDiagnosticLog(
      file: files,
      clock: clock,
      minLevel: release ? LogLevel.info : LogLevel.debug,
      console: !release,
    );
    final marker = CrashMarker(directory);
    final recorder = CrashRecorder(log: log, marker: marker, clock: clock);
    return StorizeDiagnostics._(log, marker, recorder, files);
  }

  /// The diagnostic log (a [DiagnosticLog] port implementation).
  final FileDiagnosticLog log;

  /// The crash marker for the next start.
  final CrashMarker marker;

  /// Records uncaught errors; also offers `runGuarded` for zones.
  final CrashRecorder recorder;

  /// The rotating files, for tests and a future "share diagnostics" feature.
  final RotatingLogFile files;

  /// Opens diagnostics in `<application support>/logs`, or in [directory]
  /// (tests). Release builds log INFO and above to the file only; debug
  /// builds log everything and echo to the console.
  ///
  /// Needs the Flutter binding when [directory] is null (it calls
  /// `path_provider`), so call it after
  /// `WidgetsFlutterBinding.ensureInitialized`.
  static Future<StorizeDiagnostics> open({
    Directory? directory,
    Clock clock = const SystemClock(),
    bool? release,
  }) async {
    final dir =
        directory ??
        Directory('${(await getApplicationSupportDirectory()).path}/logs');
    return StorizeDiagnostics.create(
      dir,
      clock: clock,
      release: release ?? kReleaseMode,
    );
  }

  /// Installs `FlutterError.onError` and `PlatformDispatcher.onError`.
  CrashHooks installCrashHooks() => CrashHooks.install(recorder);
}
