import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_model/storize_model.dart';

import '../../ui/golden_helpers.dart';
import 'onboarding_rig.dart';

Future<void> _shot(WidgetTester t, String name, Brightness b) => expectLater(
  find.byKey(const ValueKey('shot')),
  matchesGoldenFile('goldens/${name}_${b.name}.png'),
);

void _both(
  String name,
  Future<void> Function(WidgetTester t, Brightness b) body,
) {
  for (final b in Brightness.values) {
    testWidgets('$name golden (${b.name})', (t) async {
      await body(t, b);
      await _shot(t, name, b);
    });
  }
}

void main() {
  setUpAll(loadTestFonts);

  _both('s01_welcome_unticked', (t, b) => OnbRig().pump(t, brightness: b));

  _both('s01_welcome_ticked', (t, b) async {
    await OnbRig().pump(t, brightness: b);
    await t.tap(find.byKey(const ValueKey('onb-risk-checkbox')));
    await t.pumpAndSettle();
  });

  _both('s02_login_loading', (t, b) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.loginPath, brightness: b);
    rig.events!.onProgress(45);
    await t.pump();
  });

  _both('s02_login_connecting', (t, b) async {
    final rig = OnbRig();
    rig.platform.verifySessionResults.add(
      // Never completes while the golden is taken.
      const Ok<RemoteUser>(
        RemoteUser(
          remoteUserId: '42',
          username: 'nour',
          followedByViewer: false,
          blockedByViewer: false,
        ),
      ),
    );
    await rig.pump(t, initial: Routes.loginPath, brightness: b);
    rig.web.cookies = Map.of(OnbRig.goodCookies);
    rig.events!.onLoadStop(Uri.parse('https://www.instagram.com/'));
    await t.pump();
  });

  _both('s02_login_network_error', (t, b) async {
    final rig = OnbRig();
    await rig.pump(t, initial: Routes.loginPath, brightness: b);
    rig.events!.onLoadError(LoginLoadError.network);
    await t.pump();
  });

  _both('s02_login_checkpoint_error', (t, b) async {
    final rig = OnbRig();
    rig.platform.verifySessionResults.addFailure(const AccountRestricted());
    await rig.pump(t, initial: Routes.loginPath, brightness: b);
    rig.web.cookies = Map.of(OnbRig.goodCookies);
    rig.events!.onLoadStop(Uri.parse('https://www.instagram.com/'));
    await t.pump();
    await t.pump();
  });

  _both('s03_setup_samsung', (t, b) async {
    final rig = OnbRig()..ops.notif = true;
    await rig.pump(t, initial: Routes.setupPath, brightness: b);
  });

  _both('s03_setup_android9_storage', (t, b) async {
    final rig = OnbRig()
      ..ops.sdk = 28
      ..ops.oem = 'other';
    await rig.pump(
      t,
      initial: Routes.setupPath,
      brightness: b,
      size: const Size(400, 950),
    );
  });
}
