import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/debug/address.dart';
import 'package:storize_app/debug/address_bar.dart';

void main() {
  test('normalizes instagram.com addresses', () {
    expect(
      normalizeInspectorAddress('/stories/someone/').toString(),
      'https://www.instagram.com/stories/someone/',
    );
    expect(
      normalizeInspectorAddress('instagram.com/someone/').toString(),
      'https://instagram.com/someone/',
    );
    expect(
      normalizeInspectorAddress(' https://www.instagram.com/p/abc/ ')
          .toString(),
      'https://www.instagram.com/p/abc/',
    );
  });

  test('rejects other hosts, schemes, ports, userinfo and junk', () {
    for (final bad in [
      '',
      'example.com/x',
      'http://www.instagram.com/',
      'https://instagram.com.evil.com/',
      'https://evil.com/?u=www.instagram.com',
      'https://user@www.instagram.com@evil.com/',
      'https://www.instagram.com:8443/',
      'javascript:alert(1)',
      'ftp://www.instagram.com/',
      'two words',
    ]) {
      expect(normalizeInspectorAddress(bad), isNull, reason: bad);
    }
  });

  testWidgets('address bar calls onGo only for valid addresses', (
    tester,
  ) async {
    final seen = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InspectorAddressBar(onGo: seen.add)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'evil.com');
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(seen, isEmpty);
    expect(find.text('Only instagram.com addresses'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '/stories/x/');
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(seen.single.toString(), 'https://www.instagram.com/stories/x/');
    expect(find.text('Only instagram.com addresses'), findsNothing);
  });
}
