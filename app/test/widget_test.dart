import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/main.dart';

void main() {
  testWidgets('root widget pumps and shows the app name', (tester) async {
    await tester.pumpWidget(const StorizeApp());
    expect(find.text('Storize'), findsOneWidget);
  });
}
