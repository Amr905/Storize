import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'onboarding_rig.dart';

/// Forwards to [inner]; `verifySession` runs [onVerify] first.
class _Platform implements ContentPlatform {
  _Platform(this.inner, this.onVerify);

  final FakeContentPlatform inner;
  final Future<void> Function() onVerify;

  @override
  Future<Result<RemoteUser>> verifySession() async {
    await onVerify();
    return inner.verifySession();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FailingAccounts implements AccountRepo {
  _FailingAccounts(this.inner);

  final AccountRepo inner;

  @override
  Stream<LoginAccount?> watchActive() => inner.watchActive();

  @override
  Future<LoginAccount?> getActive() => inner.getActive();

  @override
  Future<LoginAccount> upsert(LoginAccount account) =>
      throw StateError('db down');

  @override
  Future<void> setStatus(
    int id,
    AccountStatus status, {
    String? reason,
    DateTime? lastSuccessAt,
  }) => inner.setStatus(
    id,
    status,
    reason: reason,
    lastSuccessAt: lastSuccessAt,
  );
}

/// A store whose `save` fails for [failingId] (never prints the blob).
class _FailingSessions implements SessionStore {
  _FailingSessions(this.inner, this.failingId);

  final FakeSessionStore inner;
  final int failingId;

  @override
  Future<void> save(int accountId, SessionBlob session) {
    if (accountId == failingId) throw StateError('vault down');
    return inner.save(accountId, session);
  }

  @override
  Future<SessionBlob?> load(int accountId) => inner.load(accountId);

  @override
  Future<void> clear(int accountId) => inner.clear(accountId);
}

final Uri _ig = Uri.parse('https://www.instagram.com/');

Future<void> _loggedIn(WidgetTester t, OnbRig rig) async {
  rig.web.cookies = Map.of(OnbRig.goodCookies);
  rig.events!.onLoadStop(_ig);
  await t.pump();
  await t.pump();
}

void main() {
  const staging = LoginAccount.unsavedId;

  testWidgets('verify reads the staging id; success moves it to the account', (
    t,
  ) async {
    final rig = OnbRig();
    var seenDuringVerify = false;
    rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
    await rig.pump(
      t,
      initial: Routes.loginPath,
      platformOverride: _Platform(rig.platform, () async {
        seenDuringVerify = rig.sessions.accountIds.contains(staging);
      }),
    );
    await _loggedIn(t, rig);
    expect(seenDuringVerify, isTrue);
    final active = (await rig.accounts.getActive())!;
    expect(active.id, isNot(staging));
    expect(rig.sessions.accountIds, {active.id});
    expect((await rig.settings.get()).onboardingDone, isFalse);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
  });

  testWidgets('failure clears the staging id', (t) async {
    final rig = OnbRig();
    rig.platform.verifySessionResults.addFailure(const NetworkFailure());
    await rig.pump(t, initial: Routes.loginPath);
    await _loggedIn(t, rig);
    expect(rig.sessions.accountIds, isEmpty);
    expect((await rig.settings.get()).onboardingDone, isFalse);
  });

  testWidgets('cancel during verify clears the staging id and stores nothing', (
    t,
  ) async {
    final rig = OnbRig();
    final gate = Completer<void>();
    rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
    await rig.pump(
      t,
      initial: Routes.loginPath,
      platformOverride: _Platform(rig.platform, () => gate.future),
    );
    await _loggedIn(t, rig);
    expect(rig.sessions.accountIds, {staging});
    await t.tap(find.byTooltip('Cancel login'));
    await t.pump();
    expect(rig.sessions.accountIds, isEmpty);
    gate.complete();
    await t.pumpAndSettle();
    expect(rig.sessions.accountIds, isEmpty);
    expect(await rig.accounts.getActive(), isNull);
  });

  testWidgets('verify throwing clears the staging id', (t) async {
    final rig = OnbRig();
    await rig.pump(
      t,
      initial: Routes.loginPath,
      platformOverride: _Platform(
        rig.platform,
        () async => throw StateError('boom'),
      ),
    );
    await _loggedIn(t, rig);
    expect(rig.sessions.accountIds, isEmpty);
    expect(find.text("Couldn't connect this account"), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
  });

  testWidgets('a failing account write clears the staging id', (t) async {
    final rig = OnbRig();
    rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
    await rig.pump(
      t,
      initial: Routes.loginPath,
      accountsOverride: _FailingAccounts(rig.accounts),
    );
    await _loggedIn(t, rig);
    expect(rig.sessions.accountIds, isEmpty);
    expect(find.textContaining('SECRET'), findsNothing);
  });

  testWidgets('a failing vault write for the staging id leaves nothing', (
    t,
  ) async {
    final rig = OnbRig();
    final sessions = _FailingSessions(rig.sessions, staging);
    await rig.pump(
      t,
      initial: Routes.loginPath,
      sessionsOverride: sessions,
    );
    await _loggedIn(t, rig);
    expect(rig.sessions.accountIds, isEmpty);
    expect(rig.platform.calls, isEmpty);
    expect(find.text("Couldn't connect this account"), findsOneWidget);
  });
}
