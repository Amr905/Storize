// QA (T-015): adversarial checks of GovernorWebViewLease (two isolates, TTL,
// renewal failure, crash, key -1 vs the governor, clock skew), the seen
// breaker store, and the UsernameCache overlay. Tests marked "PIN" record a
// behaviour QA reports as a finding.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

final class _Ticker {
  void Function()? tick;
  bool cancelled = false;

  Timer call(Duration interval, void Function() cb) {
    tick = cb;
    cancelled = false;
    return _T(() => cancelled = true);
  }

  Future<void> fire() async {
    if (cancelled) return;
    tick?.call();
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

final class _T implements Timer {
  _T(this.onCancel);
  final void Function() onCancel;
  @override
  void cancel() => onCancel();
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}

/// Processes `acquire` at once but answers only when its gate opens.
final class _SlowAnswerRepo implements GovernorLeaseRepo {
  _SlowAnswerRepo(this.inner);
  final GovernorLeaseRepo inner;
  final List<Completer<void>> gates = [];
  bool slow = false;
  bool failRenew = false;

  @override
  Future<GovernorLease?> acquire({
    required int accountId,
    required String holder,
    required Duration ttl,
    required GovernorBucket initialBucket,
  }) async {
    final r = await inner.acquire(
      accountId: accountId,
      holder: holder,
      ttl: ttl,
      initialBucket: initialBucket,
    );
    if (slow) {
      final g = Completer<void>();
      gates.add(g);
      await g.future;
    }
    return r;
  }

  @override
  Future<bool> renew({
    required int accountId,
    required String holder,
    required Duration ttl,
  }) async {
    if (failRenew) throw StateError('renew failed ZZFAKE');
    return inner.renew(accountId: accountId, holder: holder, ttl: ttl);
  }

  @override
  Future<void> release({required int accountId, required String holder}) =>
      inner.release(accountId: accountId, holder: holder);

  @override
  Future<GovernorLease?> read(int accountId) => inner.read(accountId);

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) => inner.writeBucket(accountId: accountId, holder: holder, bucket: bucket);
}

Target _target(String id, String name) => Target(
  id: 0,
  platform: PlatformId.instagram,
  remoteUserId: id,
  username: name,
  category: TargetCategory.public,
  postsWatermarkAt: DateTime.utc(2026),
  addedAt: DateTime.utc(2026),
);

void main() {
  late FakeClock clock;
  late FakeGovernorLeaseRepo repo;
  late FakeDiagnosticLog log;
  const key = GovernorWebViewLease.reservedAccountId;

  setUp(() {
    clock = FakeClock();
    repo = FakeGovernorLeaseRepo(clock);
    log = FakeDiagnosticLog();
  });

  GovernorWebViewLease lease(
    String id, {
    GovernorLeaseRepo? over,
    _Ticker? ticker,
    Duration ttl = const Duration(minutes: 2),
    Duration acquireTimeout = const Duration(milliseconds: 40),
  }) => GovernorWebViewLease(
    repo: over ?? repo,
    clock: clock,
    instanceId: id,
    ttl: ttl,
    acquireTimeout: acquireTimeout,
    log: log,
    ticker: ticker?.call ?? _Ticker().call,
  );

  group('two isolates', () {
    test('property: with healthy renewals, two isolates are never both '
        'holding (2000 random steps, 20 seeds)', () async {
      for (var seed = 0; seed < 20; seed++) {
        clock.set(DateTime.utc(2026));
        final rnd = Random(seed);
        final ta = _Ticker();
        final tb = _Ticker();
        final a = lease('iso-a', ticker: ta);
        final b = lease('iso-b', ticker: tb);
        for (var step = 0; step < 100; step++) {
          final who = rnd.nextBool() ? a : b;
          final owner = rnd.nextBool() ? 'page_mode:1' : 'login';
          switch (rnd.nextInt(4)) {
            case 0:
              await who.tryAcquire(owner);
            case 1:
              await who.release(owner);
            case 2:
              // healthy: a renewal fires at least every ttl/3
              clock.advance(Duration(seconds: rnd.nextInt(40)));
              await ta.fire();
              await tb.fire();
            case 3:
              clock.advance(Duration(seconds: rnd.nextInt(30)));
              await ta.fire();
              await tb.fire();
          }
          expect(
            a.isHeld && b.isHeld,
            isFalse,
            reason: 'seed $seed step $step',
          );
        }
        await a.release('page_mode:1');
        await a.release('login');
        await b.release('page_mode:1');
        await b.release('login');
      }
    });

    test('same owner name in two isolates still excludes (holder is the '
        'instance, not the owner)', () async {
      final a = lease('iso-a');
      final b = lease('iso-b');
      expect(await a.tryAcquire('page_mode:1'), isTrue);
      expect(await b.tryAcquire('page_mode:1'), isFalse);
    });

    test('release by the wrong instance does not free the row', () async {
      final a = lease('iso-a');
      final b = lease('iso-b');
      await a.tryAcquire('login');
      await b.release('login');
      await repo.release(accountId: key, holder: 'iso-b');
      expect(await b.tryAcquire('login'), isFalse);
    });
  });

  group('TTL, freeze and renewal failure', () {
    test('a crashed holder: blocked until exactly ttl, then free', () async {
      final a = lease('iso-a');
      final b = lease('iso-b');
      await a.tryAcquire('login');
      // a is gone (no ticks, no release)
      clock.advance(
        const Duration(minutes: 2) - const Duration(milliseconds: 1),
      );
      expect(await b.tryAcquire('login'), isFalse);
      clock.advance(const Duration(milliseconds: 1));
      expect(await b.tryAcquire('login'), isTrue);
    });

    test(
      'FIXED (QA-T015-F2): the process is frozen past the TTL (no renewal '
      'ticks), another isolate takes the row; at the next tick the loss is '
      'signalled, and tryAcquire of the old owner really asks again',
      () async {
        final ta = _Ticker();
        final a = lease('iso-a', ticker: ta);
        final b = lease('iso-b');
        expect(await a.tryAcquire('login'), isTrue);
        clock.advance(const Duration(minutes: 3));
        expect(await b.tryAcquire('page_mode:1'), isTrue);
        expect(a.isHeld && b.isHeld, isTrue, reason: 'both believe they hold');
        var lost = 0;
        final sub = a.onLost.listen((_) => lost++);
        await ta.fire();
        await Future<void>.delayed(Duration.zero);
        expect(lost, 1);
        await sub.cancel();
        expect(a.isHeld, isFalse);
        expect(a.owners, isEmpty);
        expect(logText(log), contains('lease_lost'));
        // b holds the row: the old owner does not get a stale true.
        expect(await a.tryAcquire('login'), isFalse);
        // The stale owner no longer blocks another owner here once b is gone.
        await b.release('page_mode:1');
        expect(await a.tryAcquire('page_mode:1'), isTrue);
      },
    );

    test('renewals that throw for longer than the TTL: the row lapses, '
        'another isolate takes it, the loss is detected at the next good '
        'tick', () async {
      final slow = _SlowAnswerRepo(repo);
      final ta = _Ticker();
      final a = lease('iso-a', over: slow, ticker: ta);
      final b = lease('iso-b');
      await a.tryAcquire('login');
      slow.failRenew = true;
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 40));
        await ta.fire();
      }
      expect(logText(log), contains('renew_failed type=StateError'));
      expect(logText(log), isNot(contains('ZZFAKE')));
      expect(await b.tryAcquire('page_mode:1'), isTrue);
      slow.failRenew = false;
      await ta.fire();
      expect(a.isHeld, isFalse);
      expect(logText(log), contains('lease_lost'));
    });

    test('a healthy S-02 that renews at ttl/3 for 30 minutes is never '
        'taken over', () async {
      final ta = _Ticker();
      final a = lease('iso-a', ticker: ta);
      final b = lease('iso-b');
      await a.tryAcquire('login');
      for (var i = 0; i < 45; i++) {
        clock.advance(const Duration(seconds: 40));
        await ta.fire();
        expect(await b.tryAcquire('page_mode:1'), isFalse, reason: 'tick $i');
      }
    });

    test('a hold that lapsed (maxHold) frees the row at the next tick, not '
        'before', () async {
      final ta = _Ticker();
      final a = lease('iso-a', ticker: ta);
      final b = lease('iso-b');
      await a.tryAcquire('page_mode:1');
      final hold = a.beginHold();
      await a.release('page_mode:1');
      expect(await b.tryAcquire('login'), isFalse);
      clock.advance(const Duration(seconds: 61));
      await ta.fire();
      expect(await b.tryAcquire('login'), isTrue);
      hold.release();
    });
  });

  group('clock skew (T-012a rule on key -1)', () {
    test('wall clock jumps back 1 h while a crashed holder has the row: a '
        'new isolate recovers at once', () async {
      final a = lease('iso-a');
      final b = lease('iso-b');
      await a.tryAcquire('login');
      clock.advance(const Duration(hours: -1));
      expect(await b.tryAcquire('login'), isTrue);
    });

    test('a release is never blocked by skew: epoch row, any clock', () async {
      final a = lease('iso-a');
      final b = lease('iso-b');
      await a.tryAcquire('login');
      await a.release('login');
      clock.advance(const Duration(days: -400));
      expect(await b.tryAcquire('login'), isTrue);
    });

    test('PIN (info): isolates with DIFFERENT ttls do not exclude each '
        'other (the repo treats the longer lease as skewed)', () async {
      final a = lease('iso-a', ttl: const Duration(minutes: 5));
      final b = lease('iso-b');
      expect(await a.tryAcquire('login'), isTrue);
      expect(await b.tryAcquire('page_mode:1'), isTrue);
      expect(a.isHeld && b.isHeld, isTrue);
    });
  });

  group('key -1 and the governor rows', () {
    test('the WebView lease and the governor lease of account 1 never block '
        'each other, and each keeps its own row', () async {
      final a = lease('iso-a');
      await a.tryAcquire('login');
      final g = await repo.acquire(
        accountId: 1,
        holder: 'gov-a',
        ttl: const Duration(minutes: 2),
        initialBucket: GovernorBucket(tokens: 6, lastRefillAt: clock.now()),
      );
      expect(g, isNotNull);
      expect((await repo.read(1))!.holder, 'gov-a');
      expect((await repo.read(key))!.holder, 'iso-a');
      await a.release('login');
      expect((await repo.read(1))!.isHeldAt(clock.now()), isTrue);
      expect((await repo.read(1))!.bucket.tokens, 6);
    });

    test('the lease never writes a bucket into a real account row and '
        'its own bucket stays empty', () async {
      final a = lease('iso-a');
      await a.tryAcquire('login');
      await a.release('login');
      expect((await repo.read(key))!.bucket.tokens, 0);
      expect(await repo.read(0), isNull);
      expect(await repo.read(1), isNull);
    });
  });

  group('late acquire answers', () {
    test('FIXED (QA-T015-F5): a late answer of attempt 1 does NOT release the '
        'row while attempt 2 (same isolate, same holder) is in flight; '
        'another isolate cannot take it', () async {
      final slow = _SlowAnswerRepo(repo)..slow = true;
      final a = lease('iso-a', over: slow);
      final b = lease('iso-b');
      // 1: processed by the repo, answer withheld, times out.
      expect(await a.tryAcquire('page_mode:1'), isFalse);
      // 2: processed (re-entrant), answer withheld.
      final second = a.tryAcquire('login');
      await Future<void>.delayed(Duration.zero);
      expect(slow.gates, hasLength(2));
      slow.gates[0].complete(); // the late answer of attempt 1
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      slow.gates[1].complete();
      expect(await second, isTrue);
      expect(await b.tryAcquire('page_mode:1'), isFalse);
      expect(a.isHeld, isTrue);
      expect(b.isHeld, isFalse);
    });
  });

  group('SeenBreakerStore and SeenGuard', () {
    test('a store that throws SYNCHRONOUSLY fails closed', () async {
      final g = SeenGuard(store: _SyncThrowStore());
      expect(await g.refresh(), isTrue);
      expect(g.tripped, isTrue);
    });

    test('trip is visible in memory at once even when the write is slow; the '
        'store changes only when the write completes; flush waits', () async {
      final store = _SlowWriteStore();
      final g = SeenGuard(store: store);
      g.trip();
      expect(g.tripped, isTrue);
      expect(store.value, isFalse);
      var flushed = false;
      unawaited(g.flush().then((_) => flushed = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(flushed, isFalse);
      store.gate.complete();
      await g.flush();
      expect(store.value, isTrue);
    });

    test('a stale "not tripped" read that completes AFTER a trip does not '
        'clear it', () async {
      final store = _SlowReadStore();
      final g = SeenGuard(store: store);
      final refresh = g.refresh();
      g.trip();
      store.readGate.complete(false);
      expect(await refresh, isTrue);
      expect(g.tripped, isTrue);
    });

    test('FIXED (QA-T015-F6): a store read that never completes times out '
        'and fails closed for this load, with a log line', () async {
      final log = FakeDiagnosticLog();
      final g = SeenGuard(
        store: _HangStore(),
        refreshTimeout: const Duration(milliseconds: 50),
        log: log,
      );
      expect(await g.refresh().timeout(const Duration(seconds: 2)), isTrue);
      expect(g.tripped, isTrue);
      expect(logText(log), contains('refresh_timeout'));
    });

    test('reset: a failing clear leaves memory tripped; a pending trip write '
        'is awaited first and the end state is "not tripped"', () async {
      final bad = CountingSeenStore()..throwOnClear = true;
      final g = SeenGuard(store: bad)..trip();
      await g.flush();
      await expectLater(g.reset(), throwsStateError);
      expect(g.tripped, isTrue);
      expect(bad.value, isTrue);

      final store = _SlowWriteStore();
      final g2 = SeenGuard(store: store)..trip();
      final reset = g2.reset();
      store.gate.complete();
      await reset;
      expect(g2.tripped, isFalse);
      expect(store.value, isFalse);
    });
  });

  group('TargetRepoUsernameCache and EC-5', () {
    test('rename: remember(new) never rewrites the row, so RunCheck still '
        'sees old != new', () async {
      final targets = FakeTargetRepo();
      await targets.insert(_target('u1', 'old_name'));
      final cache = TargetRepoUsernameCache(targets);
      await cache.remember('u1', 'new_name');
      expect(
        (await targets.getByRemoteUserId(PlatformId.instagram, 'u1'))!.username,
        'old_name',
      );
      expect(await cache.usernameOf('u1'), 'new_name');
    });

    test('FIXED (QA-T015-F7): a rename recorded in the repo after the overlay '
        'was learned (by another isolate) is newer and wins', () async {
      final targets = FakeTargetRepo();
      final t = await targets.insert(_target('u1', 'old_name'));
      final cache = TargetRepoUsernameCache(targets);
      await cache.remember('u1', 'second_name');
      // The background isolate records the NEWER rename in the repo.
      await targets.update(t.copyWith(username: 'third_name'));
      expect(await cache.usernameOf('u1'), 'third_name');
    });

    test('an empty stored username is a miss, not an empty name', () async {
      final targets = FakeTargetRepo();
      await targets.insert(_target('u1', ''));
      expect(await TargetRepoUsernameCache(targets).usernameOf('u1'), isNull);
    });
  });
}

final class _SyncThrowStore implements SeenBreakerStore {
  @override
  Future<bool> isTripped() => throw StateError('sync ZZFAKE');
  @override
  Future<void> markTripped() => throw StateError('sync');
  @override
  Future<void> clear() => throw StateError('sync');
}

final class _HangStore implements SeenBreakerStore {
  @override
  Future<bool> isTripped() => Completer<bool>().future;
  @override
  Future<void> markTripped() async {}
  @override
  Future<void> clear() async {}
}

final class _SlowWriteStore implements SeenBreakerStore {
  final Completer<void> gate = Completer<void>();
  bool value = false;
  @override
  Future<bool> isTripped() async => value;
  @override
  Future<void> markTripped() async {
    await gate.future;
    value = true;
  }

  @override
  Future<void> clear() async => value = false;
}

final class _SlowReadStore implements SeenBreakerStore {
  final Completer<bool> readGate = Completer<bool>();
  @override
  Future<bool> isTripped() => readGate.future;
  @override
  Future<void> markTripped() async {}
  @override
  Future<void> clear() async {}
}
