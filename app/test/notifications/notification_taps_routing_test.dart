import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/notifications/notification_taps.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('a notification tap while running routes to its location', (
    t,
  ) async {
    final taps = StreamController<String>.broadcast();
    addTearDown(taps.close);
    final h = await pumpApp(
      t,
      overrides: [notificationTapsProvider.overrideWith((ref) => taps.stream)],
    );
    expect(h.location, '/library');
    taps.add('/account');
    await t.pumpAndSettle();
    expect(h.location, '/account');
    taps.add('/settings?section=storage');
    await t.pumpAndSettle();
    expect(h.location, '/settings?section=storage');
  });
}
