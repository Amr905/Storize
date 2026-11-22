import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/startup_error.dart';

void main() {
  testWidgets('dev details show the error type and message', (t) async {
    await t.pumpWidget(
      StartupErrorApp(
        error: StateError('database_open_failed'),
        stack: StackTrace.current,
        showDetails: true,
      ),
    );
    expect(find.text("Storize couldn't start"), findsOneWidget);
    final text = t.widget<SelectableText>(
      find.byKey(const ValueKey('startup-error-details')),
    );
    expect(text.data, contains('type=StateError'));
    expect(text.data, contains('database_open_failed'));
  });

  testWidgets('release shows only the type', (t) async {
    await t.pumpWidget(
      StartupErrorApp(error: StateError('secret_path'), showDetails: false),
    );
    final text = t.widget<SelectableText>(
      find.byKey(const ValueKey('startup-error-details')),
    );
    expect(text.data, 'type=StateError');
  });
}
