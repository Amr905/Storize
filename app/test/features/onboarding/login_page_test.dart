import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/features/onboarding/login_web_view.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'onboarding_rig.dart';

Future<OnbRig> _open(WidgetTester t) async {
  final rig = OnbRig();
  await rig.pump(t, initial: Routes.loginPath);
  return rig;
}

Uri _ig = Uri.parse('https://www.instagram.com/');

Future<void> _loggedIn(WidgetTester t, OnbRig rig) async {
  rig.web.cookies = Map.of(OnbRig.goodCookies);
  rig.events!.onLoadStop(_ig);
  await t.pump();
  await t.pump();
}

LoginAccount _stored(String name, String id) => LoginAccount(
  id: LoginAccount.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: id,
  username: name,
  status: AccountStatus.active,
  connectedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('holds the lease while open and releases it on dispose', (
    t,
  ) async {
    final rig = await _open(t);
    expect(rig.lease.calls, ['acquire:login']);
    expect(find.byKey(const ValueKey('fake-web')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await t.pumpAndSettle();
    expect(rig.lease.calls, ['acquire:login', 'release:login']);
  });

  testWidgets('shows the busy error when page mode holds the lease', (
    t,
  ) async {
    final rig = OnbRig()..lease.available = false;
    await rig.pump(t, initial: Routes.loginPath);
    expect(find.text("Login isn't available right now"), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-web')), findsNothing);
    expect(rig.lease.calls, ['acquire:login']);
  });

  testWidgets('losing the lease stops the login and wipes the WebView', (
    t,
  ) async {
    final rig = await _open(t);
    rig.lease.lost.add(null);
    await t.pump();
    await t.pump();
    expect(find.text("Login isn't available right now"), findsOneWidget);
    expect(rig.web.clears, 1);
  });

  testWidgets('navigation is limited to the allowlist', (t) async {
    final rig = await _open(t);
    expect(
      rig.events!.allowNavigation(Uri.parse('https://evil.com/')),
      isFalse,
    );
    expect(
      rig.events!.allowNavigation(Uri.parse('https://www.facebook.com/login')),
      isTrue,
    );
  });

  testWidgets('no cookies yet: stays on the login page, no IG-4 call', (
    t,
  ) async {
    final rig = await _open(t);
    rig.web.cookies = {'csrftoken': 'x'};
    rig.events!.onLoadStop(_ig);
    await t.pump();
    await t.pump();
    expect(rig.platform.calls, isEmpty);
    expect(rig.sessions.accountIds, isEmpty);
  });

  testWidgets('success: IG-4, vault write, cookies wiped, then S-03', (
    t,
  ) async {
    final rig = await _open(t);
    rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
    await _loggedIn(t, rig);
    expect(find.text('Connected as @nour'), findsOneWidget);
    expect(rig.platform.calls.map((c) => c.method), ['verifySession']);
    final active = (await rig.accounts.getActive())!;
    expect(active.username, 'nour');
    expect(active.status, AccountStatus.active);
    expect(rig.sessions.accountIds, {active.id});
    final blob = (await rig.sessions.load(active.id))!;
    expect(blob.cookies['sessionid'], 'SECRET-SESSION');
    expect(rig.web.clears, greaterThanOrEqualTo(1));
    expect(rig.web.cookies, isEmpty);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(rig.router.state.uri.path, '/setup');
  });

  testWidgets('cookie values never appear on screen', (t) async {
    final rig = await _open(t);
    rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
    await _loggedIn(t, rig);
    expect(find.textContaining('SECRET'), findsNothing);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
  });

  testWidgets('failed IG-4 leaves nothing in the vault and wipes the WebView', (
    t,
  ) async {
    final rig = await _open(t);
    rig.platform.verifySessionResults.addFailure(
      const SessionInvalid(SessionReason.loginRequired),
    );
    await _loggedIn(t, rig);
    expect(find.text("Couldn't connect this account"), findsOneWidget);
    expect(rig.sessions.accountIds, isEmpty);
    expect(await rig.accounts.getActive(), isNull);
    expect(rig.web.clears, 1);
  });

  testWidgets('network failure and checkpoint show their own errors', (
    t,
  ) async {
    var rig = await _open(t);
    rig.platform.verifySessionResults.addFailure(const NetworkFailure());
    await _loggedIn(t, rig);
    expect(find.text('No internet'), findsOneWidget);

    rig = await _open(t);
    rig.platform.verifySessionResults.addFailure(const AccountRestricted());
    await _loggedIn(t, rig);
    expect(find.text('Instagram needs to verify this account'), findsOneWidget);

    rig = await _open(t);
    rig.platform.verifySessionResults.addFailure(
      const SessionInvalid(SessionReason.challenge),
    );
    await _loggedIn(t, rig);
    expect(find.text('Instagram needs to verify this account'), findsOneWidget);
  });

  testWidgets('page load failure shows Retry, which reloads', (t) async {
    final rig = await _open(t);
    rig.events!.onLoadError(LoginLoadError.page);
    await t.pump();
    expect(find.text("The page didn't load"), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump();
    expect(rig.web.reloads, 1);
    expect(find.byKey(const ValueKey('fake-web')), findsOneWidget);
  });

  testWidgets('re-login as another account asks first; Switch replaces', (
    t,
  ) async {
    final rig = OnbRig();
    final old = await rig.accounts.upsert(_stored('old_acc', '1'));
    await rig.sessions.save(
      old.id,
      SessionBlob(
        cookies: const {'sessionid': 'OLD', 'ds_user_id': '1'},
        userAgent: 'UA',
        capturedAt: DateTime.utc(2026),
      ),
    );
    await rig.pump(t, initial: Routes.setupPath);
    // Open S-02 as a pushed page (re-login).
    unawaited(rig.router.push(Routes.loginPath));
    await t.pumpAndSettle();
    rig.platform.verifySessionResults.addOk(OnbRig.user('new_acc', '2'));
    await _loggedIn(t, rig);
    expect(find.text('Switch to @new_acc?'), findsOneWidget);
    expect((await rig.accounts.getActive())!.username, 'old_acc');
    await t.tap(find.text('Switch'));
    await t.pump();
    await t.pump();
    final active = (await rig.accounts.getActive())!;
    expect(active.username, 'new_acc');
    expect(rig.sessions.accountIds, containsAll({old.id, active.id}));
    expect(
      (await rig.sessions.load(active.id))!.cookies['sessionid'],
      'SECRET-SESSION',
    );
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(rig.router.state.uri.path, '/setup');
  });

  testWidgets('declining the switch keeps the old account (wrong account)', (
    t,
  ) async {
    final rig = OnbRig();
    final old = await rig.accounts.upsert(_stored('old_acc', '1'));
    await rig.pump(t, initial: Routes.loginPath);
    rig.platform.verifySessionResults.addOk(OnbRig.user('new_acc', '2'));
    await _loggedIn(t, rig);
    await t.tap(find.text('Keep current'));
    await t.pump();
    await t.pump();
    expect(find.text('Account not switched'), findsOneWidget);
    expect(find.text('Checks keep using @old_acc.'), findsOneWidget);
    expect((await rig.accounts.getActive())!.id, old.id);
    expect(rig.sessions.accountIds, isEmpty);
    expect(rig.web.clears, greaterThanOrEqualTo(1));
  });

  testWidgets('back during login cancels, wipes and releases the lease', (
    t,
  ) async {
    final rig = await _open(t);
    rig.web.cookies = {'x': 'y'};
    await t.tap(find.byTooltip('Cancel login'));
    await t.pumpAndSettle();
    expect(rig.web.clears, 1);
    expect(rig.lease.calls.last, 'release:login');
    expect(rig.router.state.uri.path, '/welcome');
  });
}
