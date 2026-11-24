// T-050: the interactive reserve and the dev-only unmetered scope.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_model/storize_model.dart';

import '../governor/fake_time.dart';

const _config = GovernorConfig(
  jitterMin: Duration.zero,
  jitterMax: Duration.zero,
);

({FakeTime time, RequestGovernor governor, List<String> logs}) _rig({
  bool allowUnmetered = false,
}) {
  final time = FakeTime();
  final logs = <String>[];
  final governor = RequestGovernor(
    leases: FakeGovernorLeaseRepo(time.clock),
    clock: time.clock,
    holder: 'test',
    config: _config,
    delay: time.delay,
    log: logs.add,
    allowUnmetered: allowUnmetered,
  );
  return (time: time, governor: governor, logs: logs);
}

Future<int> _call(
  RequestGovernor g, {
  RequestCost cost = RequestCost.api,
  Duration? maxWait,
  RequestPriority? priority,
}) => g.run(
  accountId: 1,
  cost: cost,
  call: () async => 1,
  maxWait: maxWait,
  priority: priority,
);

void main() {
  group('interactive reserve', () {
    test('background calls leave 3 tokens of the burst for the user', () async {
      final r = _rig();
      // Burst 6: three background api calls fit (6 -> 3).
      for (var i = 0; i < 3; i++) {
        await r.time.drive(
          _call(r.governor, priority: RequestPriority.background),
        );
      }
      expect(await r.governor.remainingTokens(1), closeTo(3, 0.01));
      // The fourth would leave 2: it waits (refused with a short maxWait).
      await expectLater(
        r.time.drive(
          _call(
            r.governor,
            priority: RequestPriority.background,
            maxWait: const Duration(seconds: 1),
          ),
        ),
        throwsA(isA<GovernorPaused>()),
      );
      // An interactive call still goes through at once.
      await r.time.drive(
        _call(r.governor, maxWait: const Duration(seconds: 1)),
      );
      expect(await r.governor.remainingTokens(1), closeTo(2, 0.01));
    });

    test('a page load fits into the burst with the reserve', () async {
      final r = _rig();
      await r.time.drive(
        _call(
          r.governor,
          cost: RequestCost.pageLoad,
          priority: RequestPriority.background,
          maxWait: const Duration(seconds: 1),
        ),
      );
      expect(await r.governor.remainingTokens(1), closeTo(3, 0.01));
    });

    test('withPriority sets the default of every run inside it', () async {
      final r = _rig();
      for (var i = 0; i < 3; i++) {
        await r.time.drive(
          RequestGovernor.withPriority(
            RequestPriority.background,
            () => _call(r.governor),
          ),
        );
      }
      await expectLater(
        r.time.drive(
          RequestGovernor.withPriority(
            RequestPriority.background,
            () => _call(r.governor, maxWait: const Duration(seconds: 1)),
          ),
        ),
        throwsA(isA<GovernorPaused>()),
      );
    });
  });

  group('runUnmetered', () {
    Future<void> drain(
      ({FakeTime time, RequestGovernor governor, List<String> logs}) r,
    ) async {
      for (var i = 0; i < 6; i++) {
        await r.time.drive(_call(r.governor));
      }
    }

    test(
      'dev: skips the token budget, keeps a 1 s spacing, logs once',
      () async {
        final r = _rig(allowUnmetered: true);
        await drain(r);
        expect(await r.governor.remainingTokens(1), closeTo(0, 0.01));
        final before = r.time.clock.now();
        await r.time.drive(
          RequestGovernor.runUnmetered(() async {
            for (var i = 0; i < 4; i++) {
              await _call(r.governor, maxWait: const Duration(seconds: 5));
            }
          }),
        );
        final took = r.time.clock.now().difference(before);
        expect(took, greaterThanOrEqualTo(const Duration(seconds: 3)));
        expect(took, lessThan(const Duration(seconds: 30)));
        // No token was taken.
        expect(await r.governor.remainingTokens(1), lessThan(1));
        expect(r.logs.where((l) => l.contains('unmetered=yes')), hasLength(1));
      },
    );

    test(
      'prod: runUnmetered is a normal run (still waits for tokens)',
      () async {
        final r = _rig();
        await drain(r);
        await expectLater(
          r.time.drive(
            RequestGovernor.runUnmetered(
              () => _call(r.governor, maxWait: const Duration(seconds: 5)),
            ),
          ),
          throwsA(isA<GovernorPaused>()),
        );
        expect(r.logs.where((l) => l.contains('unmetered')), isEmpty);
      },
    );

    test('dev: an active Instagram back-off is still respected', () async {
      final r = _rig(allowUnmetered: true);
      await r.time.drive(
        r.governor.reportRateLimited(1, const RateLimited(null)),
      );
      await expectLater(
        r.time.drive(
          RequestGovernor.runUnmetered(() => _call(r.governor)),
        ),
        throwsA(isA<GovernorPaused>()),
      );
    });
  });
}
