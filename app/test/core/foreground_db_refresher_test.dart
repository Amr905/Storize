import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/foreground_db_refresher.dart';

void main() {
  testWidgets('refreshes on resume and periodically while resumed', (t) async {
    var calls = 0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [dbRefreshProvider.overrideWithValue(() => calls++)],
        child: const ForegroundDbRefresher(
          interval: Duration(seconds: 10),
          child: SizedBox(),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 25));
    expect(calls, 2);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 30));
    expect(calls, 2, reason: 'no refresh while in the background');

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(calls, 3, reason: 'refresh at once on resume');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('does nothing when not wired', (t) async {
    await t.pumpWidget(
      const ProviderScope(child: ForegroundDbRefresher(child: SizedBox())),
    );
    await t.pump(const Duration(minutes: 1));
  });
}
