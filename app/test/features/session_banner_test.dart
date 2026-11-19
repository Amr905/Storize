import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/ui/ui.dart';
import 'package:storize_model/storize_model.dart';

import '../helpers/app_harness.dart';

void main() {
  for (final tab in ['/library', '/targets', '/activity']) {
    testWidgets('banner on $tab for NEEDS_RELOGIN', (t) async {
      final h = await pumpApp(t, initialLocation: tab);
      await h.accounts.upsert(account(AccountStatus.needsRelogin));
      await t.pumpAndSettle();
      expect(find.byType(SessionBanner), findsOneWidget);
      expect(find.text('Instagram login needs attention'), findsOneWidget);
      expect(find.text('Fix'), findsOneWidget);
    });
  }

  testWidgets('banner for RESTRICTED', (t) async {
    final h = await pumpApp(t);
    await h.accounts.upsert(account(AccountStatus.restricted));
    await t.pumpAndSettle();
    expect(find.text('Instagram account restricted'), findsOneWidget);
    expect(
      t.widget<SessionBanner>(find.byType(SessionBanner)).kind,
      SessionBannerKind.restricted,
    );
  });

  testWidgets('hidden for ACTIVE, no account, and the settings tab', (t) async {
    final h = await pumpApp(t);
    expect(find.byType(SessionBanner), findsNothing);
    await h.accounts.upsert(account(AccountStatus.active));
    await t.pumpAndSettle();
    expect(find.byType(SessionBanner), findsNothing);
    await h.accounts.setStatus(1, AccountStatus.needsRelogin);
    await t.pumpAndSettle();
    expect(find.byType(SessionBanner), findsOneWidget);
    await h.go('/settings');
    expect(find.byType(SessionBanner), findsNothing);
  });

  testWidgets('banner appears and disappears as the status changes', (t) async {
    final h = await pumpApp(t);
    final a = await h.accounts.upsert(account(AccountStatus.needsRelogin));
    await t.pumpAndSettle();
    expect(find.byType(SessionBanner), findsOneWidget);
    await h.accounts.setStatus(a.id, AccountStatus.active);
    await t.pumpAndSettle();
    expect(find.byType(SessionBanner), findsNothing);
  });

  testWidgets('Fix opens S-13 and back returns', (t) async {
    final h = await pumpApp(t);
    await h.accounts.upsert(account(AccountStatus.needsRelogin));
    await t.pumpAndSettle();
    await t.tap(find.text('Fix'));
    await t.pumpAndSettle();
    expect(h.location, '/account');
    expect(find.text('Instagram account'), findsOneWidget);
    h.router.pop();
    await t.pumpAndSettle();
    expect(h.location, '/library');
    expect(find.byType(SessionBanner), findsOneWidget);
  });
}
