import 'package:storize_domain/src/usecases/verify_session.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

const RemoteUser me = RemoteUser(
  remoteUserId: '1',
  username: 'me',
  followedByViewer: false,
  blockedByViewer: false,
);

void main() {
  late FakeClock clock;
  late FakeAccountRepo accounts;
  late FakeContentPlatform platform;
  late VerifySession verify;

  Future<LoginAccount> seed({
    AccountStatus status = AccountStatus.active,
    String? reason,
  }) => accounts.upsert(
    LoginAccount(
      id: LoginAccount.unsavedId,
      platform: PlatformId.instagram,
      remoteUserId: '1',
      username: 'me',
      status: status,
      statusReason: reason,
      connectedAt: s.t0,
    ),
  );

  setUp(() async {
    clock = FakeClock(s.t0);
    accounts = FakeAccountRepo();
    platform = FakeContentPlatform();
    verify = VerifySession(
      accounts: accounts,
      platform: platform,
      clock: clock,
    );
    await seed(status: AccountStatus.needsRelogin, reason: 'OLD');
  });

  Future<LoginAccount> current() async => (await accounts.getActive())!;

  test(
    'a working session sets ACTIVE, clears the reason, stamps success',
    () async {
      platform.verifySessionResults.addOk(me);
      clock.set(s.t0.add(const Duration(hours: 2)));

      final outcome = await verify();

      expect(outcome, isA<AccountUpdated>());
      expect((outcome as AccountUpdated).status, AccountStatus.active);
      final account = await current();
      expect(account.status, AccountStatus.active);
      expect(account.statusReason, isNull);
      expect(account.lastSuccessAt, clock.now());
    },
  );

  test('verifySession is called exactly once per run', () async {
    platform.verifySessionResults.addOk(me);
    await verify();
    expect(platform.callsTo('verifySession'), hasLength(1));
  });

  test('login required maps to NEEDS_RELOGIN with SESSION_EXPIRED', () async {
    platform.verifySessionResults.addFailure(
      const SessionInvalid(SessionReason.loginRequired),
    );
    final outcome = await verify();

    expect(outcome, isA<AccountUpdated>());
    final account = await current();
    expect(account.status, AccountStatus.needsRelogin);
    expect(account.statusReason, 'SESSION_EXPIRED');
  });

  test(
    'checkpoint or challenge maps to NEEDS_RELOGIN with CHECKPOINT',
    () async {
      platform.verifySessionResults.addFailure(
        const SessionInvalid(SessionReason.challenge),
      );
      await verify();

      final account = await current();
      expect(account.status, AccountStatus.needsRelogin);
      expect(account.statusReason, 'CHECKPOINT');
    },
  );

  test('restricted maps to RESTRICTED', () async {
    platform.verifySessionResults.addFailure(const AccountRestricted());
    await verify();

    final account = await current();
    expect(account.status, AccountStatus.restricted);
  });

  test(
    'a network failure leaves the status and last success unchanged',
    () async {
      await accounts.setStatus(
        (await current()).id,
        AccountStatus.active,
        lastSuccessAt: s.t0,
      );
      platform.verifySessionResults.addFailure(const NetworkFailure());

      final outcome = await verify();

      expect(outcome, isA<AccountUnchanged>());
      expect((outcome as AccountUnchanged).failure, const NetworkFailure());
      final account = await current();
      expect(account.status, AccountStatus.active);
      expect(account.lastSuccessAt, s.t0);
    },
  );

  test(
    'governor_busy and webview_busy (NetworkFailure) change nothing',
    () async {
      // Both surface as NetworkFailure at the port; they must not be treated
      // as a session problem.
      for (var i = 0; i < 2; i++) {
        platform.verifySessionResults.addFailure(const NetworkFailure());
        expect(await verify(), isA<AccountUnchanged>());
      }
      expect((await current()).status, AccountStatus.needsRelogin);
      expect((await current()).statusReason, 'OLD');
    },
  );

  test('other failures (rate limit) leave the account unchanged', () async {
    platform.verifySessionResults.addFailure(const RateLimited(null));
    final outcome = await verify();

    expect(outcome, isA<AccountUnchanged>());
    expect((await current()).statusReason, 'OLD');
  });

  test(
    'no login account returns NoLoginAccount and makes no request',
    () async {
      final empty = FakeAccountRepo();
      final noAccount = VerifySession(
        accounts: empty,
        platform: platform,
        clock: clock,
      );

      expect(await noAccount(), isA<NoLoginAccount>());
      expect(platform.callsTo('verifySession'), isEmpty);
    },
  );
}
