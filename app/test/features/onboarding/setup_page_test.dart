import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/onboarding/setup_ops.dart';
import 'package:storize_app/router/routes.dart';

import 'onboarding_rig.dart';

void main() {
  testWidgets('shows pending notification and battery steps', (t) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Battery optimization'), findsOneWidget);
    expect(find.byKey(const ValueKey('onb-battery-warning')), findsOneWidget);
    expect(find.text('Storage'), findsNothing);
  });

  testWidgets('re-checks every step when the app resumes', (t) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.byKey(const ValueKey('onb-battery-warning')), findsOneWidget);
    rig.ops
      ..notif = true
      ..battery = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('onb-battery-warning')), findsNothing);
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('shows the manufacturer steps and opens battery settings', (
    t,
  ) async {
    final rig = OnbRig();
    rig.ops.oem = 'xiaomi';
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.text('Extra step for Xiaomi'), findsOneWidget);
    await t.tap(find.text('Open battery settings'));
    await t.pump();
    expect(rig.ops.batteryOpens, 1);
  });

  testWidgets('storage card appears on Android 8-9 only', (t) async {
    var rig = OnbRig();
    rig.ops.sdk = 27;
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Needed to save into your gallery.'), findsOneWidget);

    rig = OnbRig();
    rig.ops.sdk = 29;
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.text('Storage'), findsNothing);
  });

  testWidgets('denied twice offers Open app settings', (t) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.setupPath);
    expect(find.text('Open app settings'), findsNothing);
    await t.tap(find.text('Allow'));
    await t.pump();
    await t.pump();
    expect(find.text('Open app settings'), findsNothing);
    await t.tap(find.text('Allow'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Open app settings'));
    await t.pump();
    expect(rig.ops.settingsOpens, 1);
  });

  testWidgets('a granted prompt marks the step done', (t) async {
    final rig = OnbRig();
    rig.ops.notifOutcome = PermissionOutcome.granted;
    await rig.pump(t, initial: Routes.setupPath);
    await t.tap(find.text('Allow'));
    await t.pump();
    await t.pump();
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('Done and Skip are always enabled and leave S-03', (t) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.setupPath);
    await t.tap(find.byKey(const ValueKey('onb-skip')));
    await t.pumpAndSettle();
    expect(rig.router.state.uri.path, '/library');
  });
}
