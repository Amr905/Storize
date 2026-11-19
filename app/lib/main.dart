import 'package:material_ui/material_ui.dart';

void main() => runApp(const StorizeApp());

/// Root widget (placeholder; real UI arrives in T-024/T-025).
class StorizeApp extends StatelessWidget {
  /// Creates the root widget.
  const StorizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Storize',
      home: Scaffold(body: Center(child: Text('Storize'))),
    );
  }
}
