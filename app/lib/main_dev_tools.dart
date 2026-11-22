import 'package:material_ui/material_ui.dart';
import 'package:storize_app/background/background_dispatcher.dart';
import 'package:storize_app/core/composition_production.dart';
import 'package:storize_app/debug/tools/dev_tools_screen.dart';
import 'package:storize_app/debug/tools/dev_tools_wiring.dart';
import 'package:storize_app/main.dart' show installDiagnostics;
import 'package:storize_app/startup_error.dart';
import 'package:workmanager/workmanager.dart';

/// Dev-only entry point for the phone test checklist (T-037a).
///
/// Run: `cd app && flutter run --flavor dev -t lib/main_dev_tools.dart`
///
/// It builds the normal production composition (real database, vault,
/// governor, WorkManager scheduler) and opens [DevToolsScreen] instead of the
/// app. The production `lib/main.dart` never imports anything under
/// `lib/debug/tools/` (a test enforces it), so a release build, which uses
/// `main.dart`, contains none of this code.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final diagnostics = await installDiagnostics();
    if (diagnostics == null) {
      throw StateError('diagnostics_unavailable');
    }
    final composition = await composeProduction(
      background: false,
      diagnostics: diagnostics,
    );
    await Workmanager().initialize(callbackDispatcher);
    runApp(
      MaterialApp(
        title: 'Storize dev tools',
        debugShowCheckedModeBanner: false,
        home: DevToolsScreen(
          actions: buildDevToolsActions(composition, diagnostics.files),
        ),
      ),
    );
  } on Object catch (error, stack) {
    // Before, a start-up failure left a blank screen.
    runApp(StartupErrorApp(error: error, stack: stack, showDetails: true));
  }
}
