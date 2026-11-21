// QA (T-026): login host allowlist bypasses, staging session on every path,
// lease handling, secrets in output, and the loading gate.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/features/onboarding/login_controller.dart';
import 'package:storize_app/features/onboarding/login_host_policy.dart';
import 'package:storize_app/router/routes.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import '../features/onboarding/onboarding_rig.dart';

final Uri _ig = Uri.parse('https://www.instagram.com/');
const int _staging = LoginAccount.unsavedId;

class _Sessions implements SessionStore {
  _Sessions(this.inner, {this.failSaveFor, this.failClear = false});
  final FakeSessionStore inner;
  final int? failSaveFor;
  final bool failClear;
  @override
  Future<void> save(int id, SessionBlob s) {
    if (id == failSaveFor) throw StateError('vault down');
    return inner.save(id, s);
  }

  @override
  Future<SessionBlob?> load(int id) => inner.load(id);
  @override
  Future<void> clear(int id) {
    if (failClear && id == _staging) throw StateError('clear failed');
    return inner.clear(id);
  }
}

class _GatedPlatform implements ContentPlatform {
  _GatedPlatform(this.inner, this.gate);
  final FakeContentPlatform inner;
  final Completer<void> gate;
  @override
  Future<Result<RemoteUser>> verifySession() async {
    await gate.future;
    return inner.verifySession();
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<void> _login(WidgetTester t, OnbRig rig) async {
  rig.web.cookies = Map.of(OnbRig.goodCookies);
  rig.events!.onLoadStop(_ig);
  await t.pump();
  await t.pump();
}

void main() {
  group('host allowlist', () {
    const blocked = [
      'http://www.instagram.com/',
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'data:text/html,<script>1</script>',
      'file:///etc/passwd',
      'https://instagram.com.evil.com/',
      'https://evilinstagram.com/',
      'https://instagram.com@evil.com/',
      'https://www.instagram.com@evil.com/login',
      'https://evil.com/?u=https://www.instagram.com/',
      'https://evil.com/instagram.com',
      'https://www.instagram.com./',
      'https://l.instagram.com/?u=https%3A%2F%2Fevil.com',
      'https://L.INSTAGRAM.COM/',
      'https://notfacebook.com/',
      'https://facebook.com.evil.io/',
      'https://xn--instgram-5ya.com/',
      'ftp://www.instagram.com/',
      'about:blank',
      'https:///path',
    ];
    for (final u in blocked) {
      test('blocks $u', () {
        expect(LoginHostPolicy.allows(Uri.parse(u)), isFalse);
      });
    }
    test('allows the real login hosts only over https', () {
      for (final u in [
        'https://www.instagram.com/accounts/login/',
        'https://instagram.com/',
        'https://m.facebook.com/login',
        'https://WWW.Instagram.COM/x',
        'https://www.instagram.com:443/',
      ]) {
        expect(LoginHostPolicy.allows(Uri.parse(u)), isTrue, reason: u);
      }
    });
    test('isInstagram is false for facebook, so no cookie read there', () {
      expect(
        LoginHostPolicy.isInstagram(Uri.parse('https://m.facebook.com/')),
        isFalse,
      );
    });
  });

  group('staging session (id 0)', () {
    testWidgets(
      'vault save of the real id fails: staging cleared, flag unset',
      (t) async {
        final rig = OnbRig();
        rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
        await rig.pump(
          t,
          initial: Routes.loginPath,
          sessionsOverride: _Sessions(rig.sessions, failSaveFor: 1),
        );
        await _login(t, rig);
        await t.pumpAndSettle();
        expect(rig.sessions.accountIds.contains(_staging), isFalse);
        expect((await rig.settings.get()).onboardingDone, isFalse);
        expect(rig.web.clears, greaterThan(0));
      },
    );

    testWidgets('clear(0) itself throwing does not break the flow', (t) async {
      final rig = OnbRig();
      rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
      await rig.pump(
        t,
        initial: Routes.loginPath,
        sessionsOverride: _Sessions(rig.sessions, failClear: true),
      );
      await _login(t, rig);
      await t.pumpAndSettle();
      final active = await rig.accounts.getActive();
      expect(active, isNotNull);
      expect(active!.id, isNot(_staging));
    });

    testWidgets('decline keeps the previous account and its session', (
      t,
    ) async {
      final rig = OnbRig();
      final old = await rig.accounts.upsert(
        LoginAccount(
          id: _staging,
          platform: PlatformId.instagram,
          remoteUserId: '7',
          username: 'old_user',
          status: AccountStatus.active,
          connectedAt: DateTime.utc(2026, 11),
        ),
      );
      await rig.sessions.save(
        old.id,
        SessionBlob(
          cookies: const {
            'sessionid': 'OLD',
            'ds_user_id': '7',
            'csrftoken': 'c',
          },
          userAgent: 'UA',
          capturedAt: DateTime.utc(2026, 11),
        ),
      );
      rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
      await rig.pump(t, initial: Routes.loginPath);
      await _login(t, rig);
      await t.pump();
      final c = rig.container.read(loginControllerProvider.notifier);
      expect(
        rig.container.read(loginControllerProvider).phase,
        LoginPhase.confirmSwitch,
      );
      c.answerSwitch(confirm: false);
      await t.pump();
      await t.pump();
      expect((await rig.accounts.getActive())!.remoteUserId, '7');
      expect(rig.sessions.accountIds, {old.id});
      expect((await rig.sessions.load(old.id))!.cookies['sessionid'], 'OLD');
    });

    testWidgets('lease lost during verify: nothing stored, staging cleared', (
      t,
    ) async {
      final rig = OnbRig();
      final gate = Completer<void>();
      rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
      await rig.pump(
        t,
        initial: Routes.loginPath,
        platformOverride: _GatedPlatform(rig.platform, gate),
      );
      await _login(t, rig);
      expect(rig.sessions.accountIds, {_staging});
      rig.lease.lost.add(null);
      await t.pump();
      expect(rig.sessions.accountIds, isEmpty);
      gate.complete();
      await t.pumpAndSettle();
      expect(rig.sessions.accountIds, isEmpty);
      expect(await rig.accounts.getActive(), isNull);
      expect((await rig.settings.get()).onboardingDone, isFalse);
      expect(
        rig.container.read(loginControllerProvider).error,
        LoginError.busy,
      );
    });

    testWidgets('page disposed during verify: nothing stored', (t) async {
      final rig = OnbRig();
      final gate = Completer<void>();
      rig.platform.verifySessionResults.addOk(OnbRig.user('nour', '42'));
      await rig.pump(
        t,
        initial: Routes.loginPath,
        platformOverride: _GatedPlatform(rig.platform, gate),
      );
      await _login(t, rig);
      rig.router.go(Routes.welcomePath);
      await t.pumpAndSettle();
      gate.complete();
      await t.pumpAndSettle();
      expect(rig.sessions.accountIds, isEmpty);
      expect(await rig.accounts.getActive(), isNull);
      expect(rig.lease.calls.where((c) => c == 'release:login'), isNotEmpty);
    });
  });

  group('lease', () {
    testWidgets('acquired once with owner login, released on leaving', (
      t,
    ) async {
      final rig = OnbRig();
      await rig.pump(t, initial: Routes.loginPath);
      expect(rig.lease.calls, ['acquire:login']);
      rig.router.go(Routes.welcomePath);
      await t.pumpAndSettle();
      expect(rig.lease.calls, ['acquire:login', 'release:login']);
    });

    testWidgets('busy lease: no WebView cookie read, no release of a lease '
        'that was never taken', (t) async {
      final rig = OnbRig()..lease.available = false;
      await rig.pump(t, initial: Routes.loginPath);
      expect(
        rig.container.read(loginControllerProvider).error,
        LoginError.busy,
      );
      expect(rig.events, isNull, reason: 'no WebView while busy');
      expect(rig.sessions.accountIds, isEmpty);
      rig.router.go(Routes.welcomePath);
      await t.pumpAndSettle();
      expect(rig.lease.calls.contains('release:login'), isFalse);
    });
  });

  group('secrets', () {
    testWidgets('no cookie value in logs, state or rendered text', (t) async {
      final printed = <String>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => printed.add(m ?? '');
      addTearDown(() => debugPrint = old);
      final rig = OnbRig();
      rig.platform.verifySessionResults.addFailure(const NetworkFailure());
      await rig.pump(t, initial: Routes.loginPath);
      await _login(t, rig);
      await t.pumpAndSettle();
      final texts = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .join(' ');
      final state = rig.container.read(loginControllerProvider).toString();
      for (final s in ['SECRET-SESSION', 'SECRET-CSRF']) {
        expect(texts.contains(s), isFalse);
        expect(state.contains(s), isFalse);
        expect(printed.join().contains(s), isFalse);
      }
    });

    testWidgets(
      'platform throwing with a cookie in the message shows no text',
      (t) async {
        final rig = OnbRig();
        await rig.pump(
          t,
          initial: Routes.loginPath,
          platformOverride: _Throwing(),
        );
        await _login(t, rig);
        await t.pumpAndSettle();
        expect(find.textContaining('SECRET'), findsNothing);
        expect(
          rig.container.read(loginControllerProvider).error,
          LoginError.unusable,
        );
        expect(rig.sessions.accountIds, isEmpty);
      },
    );
  });
}

class _Throwing implements ContentPlatform {
  @override
  Future<Result<RemoteUser>> verifySession() async =>
      throw StateError('sessionid=SECRET-SESSION');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
