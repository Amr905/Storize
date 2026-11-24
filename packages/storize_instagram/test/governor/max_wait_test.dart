import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import 'fake_time.dart';

const _noJitter = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

void main() {
  late FakeTime time;
  late RequestGovernor g;

  setUp(() {
    time = FakeTime();
    g = RequestGovernor(
      leases: FakeGovernorLeaseRepo(time.clock),
      clock: time.clock,
      holder: 'ui',
      config: _noJitter,
      delay: time.delay,
    );
  });

  Future<void> drain() async {
    for (var i = 0; i < 6; i++) {
      await time.drive(
        g.run(accountId: 1, cost: RequestCost.api, call: () async => i),
      );
    }
  }

  test('over maxWait: refused, no token spent, call not made', () async {
    await drain();
    var made = false;
    Object? error;
    try {
      await time.drive(
        g.run(
          accountId: 1,
          cost: RequestCost.pageLoad,
          maxWait: const Duration(seconds: 8),
          call: () async => made = true,
        ),
      );
    } on GovernorPaused catch (e) {
      error = e;
    }
    expect(error, isA<GovernorPaused>());
    final paused = error! as GovernorPaused;
    expect(paused.toFailure(), isA<RateLimited>());
    expect(paused.retryAfter, const Duration(minutes: 3));
    expect(made, isFalse);
    expect(await g.remainingTokens(1), 0);
    expect(await g.isPaused(1), isFalse, reason: 'no back-off is recorded');
  });

  test('under maxWait: waits and then runs', () async {
    await drain();
    var done = false;
    final f = g
        .run(
          accountId: 1,
          cost: RequestCost.api,
          maxWait: const Duration(seconds: 90),
          call: () async => 1,
        )
        .then((_) => done = true);
    await time.elapse(const Duration(seconds: 59));
    expect(done, isFalse);
    await time.elapse(const Duration(seconds: 1));
    expect(done, isTrue);
    await f;
  });

  test('withMaxWait sets the zone default for runs inside it', () async {
    await drain();
    final future = RequestGovernor.withMaxWait(
      const Duration(seconds: 8),
      () => g.run(accountId: 1, cost: RequestCost.api, call: () async => 1),
    );
    await expectLater(time.drive(future), throwsA(isA<GovernorPaused>()));
  });

  test('without maxWait the call still waits as today', () async {
    await drain();
    var done = false;
    final f = g
        .run(accountId: 1, cost: RequestCost.api, call: () async => 1)
        .then((_) => done = true);
    await time.elapse(const Duration(minutes: 1));
    expect(done, isTrue);
    await f;
  });
}
