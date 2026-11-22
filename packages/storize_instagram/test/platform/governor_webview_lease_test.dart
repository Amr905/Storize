// T-014 R2-F2 / R2-F3 and the cross-isolate WebViewLease (T-015 AC "T-014
// follow-ups"): GovernorWebViewLease over GovernorLeaseRepo, key -1.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';

import '../page/support.dart' as ps;
import 'support.dart';

/// Fires the renewal callback by hand.
final class _Ticker {
  void Function()? tick;
  int created = 0;
  bool cancelled = false;

  Timer call(Duration interval, void Function() cb) {
    created++;
    tick = cb;
    cancelled = false;
    return _FakePeriodic(() => cancelled = true);
  }

  Future<void> fire() async {
    tick?.call();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

final class _FakePeriodic implements Timer {
  _FakePeriodic(this.onCancel);

  final void Function() onCancel;
  bool _active = true;

  @override
  void cancel() {
    _active = false;
    onCancel();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// A repo whose `acquire` waits for a gate.
final class _GatedRepo implements GovernorLeaseRepo {
  _GatedRepo(this.inner);

  final GovernorLeaseRepo inner;
  Completer<void>? gate;
  bool failAcquire = false;
  bool failRenew = false;
  bool failRelease = false;
  bool renewReturnsFalse = false;
  int acquires = 0;
  int renews = 0;

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) async {
    acquires++;
    final g = gate;
    if (g != null) await g.future;
    if (failAcquire) throw StateError('db down ZZFAKE');
    return inner.acquire(
      accountId: accountId,
      holder: holder,
      ttl: ttl,
      initialBucket: initialBucket,
    );
  }

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) async {
    renews++;
    if (failRenew) throw StateError('renew failed ZZFAKE');
    if (renewReturnsFalse) return false;
    return inner.renew(accountId: accountId, holder: holder, ttl: ttl);
  }

  @override
  Future<void> release({required int accountId, required String holder}) async {
    if (failRelease) throw StateError('release failed ZZFAKE');
    return inner.release(accountId: accountId, holder: holder);
  }

  @override
  Future<GovernorLease?> read(int accountId) => inner.read(accountId);

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) => inner.writeBucket(
    accountId: accountId,
    holder: holder,
    bucket: bucket,
  );
}

void main() {
  late FakeClock clock;
  late FakeGovernorLeaseRepo repo;
  late _GatedRepo gated;
  late FakeDiagnosticLog log;

  setUp(() {
    clock = FakeClock();
    repo = FakeGovernorLeaseRepo(clock);
    gated = _GatedRepo(repo);
    log = FakeDiagnosticLog();
  });

  GovernorWebViewLease lease(
    String instance, {
    GovernorLeaseRepo? over,
    _Ticker? ticker,
    Duration acquireTimeout = const Duration(milliseconds: 40),
    Duration maxHold = const Duration(seconds: 60),
  }) => GovernorWebViewLease(
    repo: over ?? gated,
    clock: clock,
    instanceId: instance,
    acquireTimeout: acquireTimeout,
    maxHold: maxHold,
    log: log,
    ticker: ticker?.call ?? _Ticker().call,
  );

  Future<bool> held() async {
    final row = await repo.read(GovernorWebViewLease.reservedAccountId);
    return row != null && row.isHeldAt(clock.now());
  }

  group('the lease row', () {
    test(
      'uses the reserved account id -1, holder = instance, ttl 2 min',
      () async {
        final l = lease('isolate-a');
        expect(GovernorWebViewLease.reservedAccountId, -1);
        expect(await l.tryAcquire('page_mode:1'), isTrue);
        final row = (await repo.read(-1))!;
        expect(row.holder, 'isolate-a');
        expect(row.expiresAt, clock.now().add(const Duration(minutes: 2)));
        expect(l.isHeld, isTrue);
        expect(l.owners, {'page_mode:1'});
      },
    );

    test(
      'release ends it (expiresAt is the epoch) and is idempotent',
      () async {
        final l = lease('a');
        await l.tryAcquire('x');
        await l.release('x');
        await l.release('x');
        expect(await held(), isFalse);
        expect(l.isHeld, isFalse);
      },
    );

    test('releasing an owner that never acquired changes nothing', () async {
      final l = lease('a');
      await l.tryAcquire('x');
      await l.release('someone_else');
      expect(await held(), isTrue);
    });

    test('does not touch the governor lease of a real account', () async {
      final governorHolder = await repo.acquire(
        accountId: 1,
        holder: 'governor',
        ttl: const Duration(minutes: 10),
        initialBucket: GovernorBucket(tokens: 6, lastRefillAt: clock.now()),
      );
      final l = lease('a');
      expect(await l.tryAcquire('x'), isTrue);
      await l.release('x');
      final row = (await repo.read(1))!;
      expect(row.holder, 'governor');
      expect(row.isHeldAt(clock.now()), isTrue);
      expect(governorHolder, isNotNull);
    });
  });

  group('exclusion', () {
    test(
      'another isolate cannot take it, even with the same owner name',
      () async {
        final a = lease('isolate-a');
        final b = lease('isolate-b');
        expect(await a.tryAcquire('page_mode:1'), isTrue);
        expect(await b.tryAcquire('page_mode:1'), isFalse);
        expect(await b.tryAcquire('login'), isFalse);
        await a.release('page_mode:1');
        expect(await b.tryAcquire('login'), isTrue);
      },
    );

    test(
      'in one isolate the login owner and page mode exclude each other',
      () async {
        final l = lease('a');
        expect(await l.tryAcquire('login'), isTrue);
        expect(await l.tryAcquire('page_mode:1'), isFalse);
        expect(await l.tryAcquire('login'), isTrue, reason: 're-entrant');
        await l.release('login');
        expect(await l.tryAcquire('page_mode:1'), isTrue);
      },
    );

    test('a crashed holder frees the lease by TTL', () async {
      final a = lease('a');
      final b = lease('b');
      await a.tryAcquire('x');
      expect(await b.tryAcquire('y'), isFalse);
      clock.advance(const Duration(minutes: 2, seconds: 1));
      expect(await b.tryAcquire('y'), isTrue);
    });

    test(
      'lastFailure names why acquire failed, and clears on success',
      () async {
        final a = lease('a');
        final b = lease('b');
        expect(await a.tryAcquire('x'), isTrue);
        expect(a.lastFailure, isNull);
        expect(await a.tryAcquire('y'), isFalse);
        expect(a.lastFailure, 'busy_here');
        expect(await b.tryAcquire('y'), isFalse);
        expect(b.lastFailure, 'held_by_other');
        await a.release('x');
        expect(await b.tryAcquire('y'), isTrue);
        expect(b.lastFailure, isNull);
      },
    );

    test('concurrent tryAcquire calls: exactly one wins', () async {
      final l = lease('a');
      final results = await Future.wait([
        l.tryAcquire('page_mode:1'),
        l.tryAcquire('login'),
      ]);
      expect(results.where((r) => r), hasLength(1));
    });
  });

  group('renewal during the run', () {
    test('a tick renews the row; without it the row would lapse', () async {
      final ticker = _Ticker();
      final l = lease('a', ticker: ticker);
      await l.tryAcquire('login');
      expect(ticker.created, 1);
      clock.advance(const Duration(minutes: 1, seconds: 30));
      await ticker.fire();
      clock.advance(const Duration(minutes: 1, seconds: 30));
      expect(await held(), isTrue, reason: '3 min in, ttl 2 min, renewed once');
      expect(await lease('b').tryAcquire('y'), isFalse);
    });

    test('the timer stops on release', () async {
      final ticker = _Ticker();
      final l = lease('a', ticker: ticker);
      await l.tryAcquire('login');
      await l.release('login');
      expect(ticker.cancelled, isTrue);
    });

    test('a lost row is re-acquired when free', () async {
      final ticker = _Ticker();
      final l = lease('a', over: gated, ticker: ticker);
      await l.tryAcquire('login');
      clock.advance(const Duration(minutes: 3)); // the row lapsed
      await ticker.fire();
      expect(l.isHeld, isTrue);
      expect(await held(), isTrue);
    });

    test(
      'a lost row taken by another isolate is logged and not stolen',
      () async {
        final ticker = _Ticker();
        final l = lease('a', ticker: ticker);
        await l.tryAcquire('login');
        clock.advance(const Duration(minutes: 3));
        expect(await lease('b').tryAcquire('y'), isTrue);
        await ticker.fire();
        expect(l.isHeld, isFalse);
        expect(logText(log), contains('lease_lost'));
        expect((await repo.read(-1))!.holder, 'b');
      },
    );

    test('a failing renewal is logged by type and retried next tick', () async {
      final ticker = _Ticker();
      final l = lease('a', ticker: ticker);
      await l.tryAcquire('login');
      gated.failRenew = true;
      await ticker.fire();
      expect(logText(log), contains('renew_failed type=StateError'));
      expect(logText(log), isNot(contains('ZZFAKE')));
      gated.failRenew = false;
      await ticker.fire();
      expect(l.isHeld, isTrue);
    });
  });

  group('R2-F3 a late tryAcquire answer is released', () {
    test('timeout: false now; the late lease is given back', () async {
      final l = lease('a');
      gated.gate = Completer<void>();
      expect(await l.tryAcquire('page_mode:1'), isFalse);
      expect(logText(log), contains('acquire_timeout'));
      gated.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await held(), isFalse, reason: 'released, not leaked');
      expect(l.isHeld, isFalse);
      gated.gate = null;
      expect(await lease('b').tryAcquire('y'), isTrue);
    });

    test('a late answer is NOT released if this isolate got the lease '
        'legitimately in the meantime', () async {
      final l = lease('a');
      gated.gate = Completer<void>();
      expect(await l.tryAcquire('page_mode:1'), isFalse);
      final late = gated.gate!;
      gated.gate = null;
      expect(await l.tryAcquire('login'), isTrue);
      late.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await held(), isTrue);
      expect(l.owners, {'login'});
    });

    test('a repo that throws is false, with the type only logged', () async {
      final l = lease('a');
      gated.failAcquire = true;
      expect(await l.tryAcquire('x'), isFalse);
      expect(logText(log), contains('acquire_failed type=StateError'));
      expect(logText(log), isNot(contains('ZZFAKE')));
    });

    test('tryAcquire answers within acquireTimeout, which is below the '
        "extractor's 5 s cleanup timeout", () async {
      final l = lease('a', acquireTimeout: const Duration(milliseconds: 30));
      gated.gate = Completer<void>();
      final sw = Stopwatch()..start();
      await l.tryAcquire('x');
      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(
        GovernorWebViewLease(
          repo: repo,
          clock: clock,
          instanceId: 'd',
        ).acquireTimeout,
        lessThan(const Duration(seconds: 5)),
      );
      gated.gate!.complete();
    });
  });

  group('R2-F2 a hold keeps the lease through a late open', () {
    test(
      'owner released, hold alive: still held and nobody else can acquire',
      () async {
        final l = lease('a');
        await l.tryAcquire('page_mode:1');
        final hold = l.beginHold();
        await l.release('page_mode:1');
        expect(await held(), isTrue);
        expect(await l.tryAcquire('page_mode:1'), isFalse);
        expect(await lease('b').tryAcquire('login'), isFalse);
        hold.release();
        await Future<void>.delayed(Duration.zero);
        expect(await held(), isFalse);
        expect(await lease('b').tryAcquire('login'), isTrue);
      },
    );

    test('release of a hold is idempotent', () async {
      final l = lease('a');
      await l.tryAcquire('x');
      final hold = l.beginHold();
      await l.release('x');
      hold
        ..release()
        ..release();
      await Future<void>.delayed(Duration.zero);
      expect(await held(), isFalse);
    });

    test('a hold that is never released lapses after maxHold', () async {
      final ticker = _Ticker();
      final l = lease(
        'a',
        ticker: ticker,
      );
      await l.tryAcquire('x');
      l.beginHold();
      await l.release('x');
      expect(await held(), isTrue);
      clock.advance(const Duration(seconds: 61));
      await ticker.fire();
      expect(await held(), isFalse, reason: 'the tick sees no live hold');
      expect(await lease('b').tryAcquire('y'), isTrue);
    });

    test('a hold without a held lease is a no-op', () async {
      final l = lease('a');
      l.beginHold().release();
      expect(await held(), isFalse);
    });
  });

  group('LeaseHoldingPageDriver', () {
    ps.FakePageDriver driver0({
      bool openThrows = false,
      Completer<void>? gate,
    }) => ps.FakePageDriver(
      (_, _) {},
      openThrows: openThrows,
      openGate: gate,
    );

    const config = PageSessionConfig(
      cookies: {},
      userAgent: 'ZZFAKE',
      hookSource: '',
      handlerName: 'h',
      allowedOrigins: {},
    );

    test('the hold lasts from open until dispose', () async {
      final l = lease('a');
      await l.tryAcquire('page_mode:1');
      final inner = driver0();
      final session = await LeaseHoldingPageDriver(inner, l).open(config);
      await l.release('page_mode:1');
      expect(await held(), isTrue, reason: 'session still open');
      session.events.listen((_) {}); // the fake closes its controller
      await session.clearData();
      await session.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(await held(), isFalse);
      expect(inner.log, ['open', 'clear', 'dispose']);
    });

    test('an open that throws releases the hold', () async {
      final l = lease('a');
      await l.tryAcquire('page_mode:1');
      final d = LeaseHoldingPageDriver(driver0(openThrows: true), l);
      await expectLater(d.open(config), throwsA(isA<StateError>()));
      await l.release('page_mode:1');
      await Future<void>.delayed(Duration.zero);
      expect(await held(), isFalse);
    });

    test('a slow open holds the lease while the owner is gone, then frees it '
        'when the late session is disposed', () async {
      final l = lease('a');
      await l.tryAcquire('page_mode:1');
      final gate = Completer<void>();
      final d = LeaseHoldingPageDriver(driver0(gate: gate), l);
      final opening = d.open(config);
      await l.release('page_mode:1'); // the extractor gave up and released
      expect(await held(), isTrue);
      gate.complete();
      final late = await opening;
      late.events.listen((_) {});
      expect(await held(), isTrue, reason: 'clean-up of the late session');
      await late.clearData();
      await late.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(await held(), isFalse);
    });

    test('dispose that throws still releases the hold', () async {
      final l = lease('a');
      await l.tryAcquire('x');
      final session = await LeaseHoldingPageDriver(
        _ThrowingDisposeDriver(),
        l,
      ).open(config);
      await l.release('x');
      expect(await held(), isTrue);
      await expectLater(session.dispose(), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      expect(await held(), isFalse);
    });
  });
}

final class _ThrowingDisposeDriver implements PageDriver {
  @override
  Future<PageSession> open(PageSessionConfig config) async =>
      _ThrowingSession();
}

final class _ThrowingSession implements PageSession {
  @override
  Stream<PageEvent> get events => const Stream.empty();

  @override
  Future<void> load(Uri url) async {}

  @override
  Future<Object?> collectDomMedia() async => null;

  @override
  Future<void> clearData() async {}

  @override
  Future<void> dispose() async => throw StateError('x');
}
