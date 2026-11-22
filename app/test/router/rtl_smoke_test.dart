// QA: RTL render smoke of the shell with the banner on every tab, at a large
// text scale. Fails on any layout overflow or framework exception. Covers
// S-04 (/library), S-07 (/targets), S-09 (/targets/:id), S-11 (/activity),
// S-12 (/settings) and S-13 (/account), T-038 AC3.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('RTL shell, banner, every tab: no overflow', (t) async {
    t.view.physicalSize = const Size(360 * 2, 640 * 2);
    t.view.devicePixelRatio = 2;
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final h = await pumpApp(t, textDirection: TextDirection.rtl);
    await h.accounts.upsert(account(AccountStatus.restricted));
    await t.pumpAndSettle();
    final d = Directionality.of(t.element(find.byType(NavigationBar)));
    expect(d, TextDirection.rtl);
    for (final path in [
      '/library',
      '/targets',
      '/activity',
      '/settings',
      '/targets/3',
      '/account',
    ]) {
      await h.go(path);
      expect(t.takeException(), isNull, reason: path);
      // Every routed page inherits the RTL direction (T-038 AC3).
      expect(
        Directionality.of(t.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
        reason: path,
      );
      expect(
        find.byType(SessionBanner).evaluate().length,
        ['/library', '/targets', '/activity'].contains(path) ? 1 : 0,
        reason: path,
      );
    }
  });
}
