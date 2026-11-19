import 'package:material_ui/material_ui.dart';
import 'package:storize_app/app.dart';
import 'package:storize_data/log/log.dart';

/// App entry point.
///
/// Diagnostics are opened here, before `runApp`, because the crash hooks need
/// the log instance (TECH_SPEC §8). This is deliberately not a composition
/// root: nothing else is wired here, the instance is not shared, and the
/// pending-crash report (`reportPendingCrash`) is run by the later composition
/// root once the database is open.
///
/// Opening diagnostics must never stop the app, so a failure here is ignored
/// and the app starts without crash logging.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await installDiagnostics();
  runApp(const StorizeApp());
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
