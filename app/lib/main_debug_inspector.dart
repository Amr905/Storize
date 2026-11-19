import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/inspector_screen.dart';

/// Debug-only entry point for the T-002 spike.
///
/// Run: `flutter run --flavor dev -t lib/main_debug_inspector.dart`
/// Then open `chrome://inspect` on the PC to see the WebView.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }
  runApp(const InspectorApp());
}

/// Root of the inspector app.
class InspectorApp extends StatelessWidget {
  /// Creates the app.
  const InspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Storize inspector',
      debugShowCheckedModeBanner: false,
      home: DebugInspectorScreen(),
    );
  }
}
