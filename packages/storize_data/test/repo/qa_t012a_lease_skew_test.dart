// QA T-012a: adversarial checks of the drift lease skew rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';

import 'support/builders.dart';
import 'support/harness.dart';

const _ttl = Duration(minutes: 10);

void main() {
  late DriftHarness h;
  setUp(() => h = DriftHarness());
  tearDown(() => h.dispose());

  Future<GovernorLease?> take(
    GovernorLeaseRepo r,
    String holder, {
    Duration ttl = _ttl,
  }) => r.acquire(
    accountId: 1,
    holder: holder,
    ttl: ttl,
    initialBucket: GovernorBucket(tokens: 6, lastRefillAt: t0),
  );

  test(
    'race after a back-jump: two repos, one database, exactly one wins',
    () async {
      final repoA = DriftGovernorLeaseRepo(h.db, h.clock);
      final repoB = DriftGovernorLeaseRepo(h.db, h.clock);
      final repoC = DriftGovernorLeaseRepo(h.db, h.clock);
      expect(await take(repoA, 'A'), isNotNull);
      h.clock.advance(const Duration(hours: -3));
      final results = await Future.wait([
        take(repoB, 'B'),
        take(repoC, 'C'),
        take(repoB, 'B'),
        take(repoC, 'C'),
      ]);
      final holders = results.whereType<GovernorLease>().map((l) => l.holder);
      expect(holders.toSet().length, 1, reason: 'one holder only: $holders');
      final stored = await repoA.read(1);
      expect(stored!.holder, holders.first);
      expect(await take(repoA, 'A'), isNull);
    },
  );

  test('race on a fresh row (no lease yet): exactly one holder', () async {
    final r1 = DriftGovernorLeaseRepo(h.db, h.clock);
    final r2 = DriftGovernorLeaseRepo(h.db, h.clock);
    final results = await Future.wait([take(r1, 'X'), take(r2, 'Y')]);
    expect(results.whereType<GovernorLease>().length, 1);
  });

  test(
    'forward jump: expired lease is taken, unexpired one still blocks',
    () async {
      await take(h.leases, 'A');
      h.clock.advance(const Duration(minutes: 9, seconds: 59));
      expect(await take(h.leases, 'B'), isNull);
      h.clock.advance(const Duration(seconds: 1));
      expect(await take(h.leases, 'B'), isNotNull);
      h.clock.advance(const Duration(days: 30));
      expect(await take(h.leases, 'C'), isNotNull);
    },
  );

  test('ttl mismatch: shorter-ttl taker treats a longer lease as expired '
      '(documents the behaviour)', () async {
    await take(h.leases, 'A', ttl: const Duration(minutes: 30));
    expect(await take(h.leases, 'B'), isNotNull);
  });

  test(
    'ttl mismatch: longer-ttl taker still blocked by a shorter lease',
    () async {
      await take(h.leases, 'A');
      expect(
        await take(h.leases, 'B', ttl: const Duration(minutes: 30)),
        isNull,
      );
    },
  );

  test('release: twice is safe, non-holder is a no-op, epoch is UTC 0 and '
      'survives drift', () async {
    await take(h.leases, 'A');
    await h.leases.release(accountId: 1, holder: 'B');
    expect((await h.leases.read(1))!.holder, 'A');
    expect((await h.leases.read(1))!.expiresAt, h.clock.now().add(_ttl));
    await h.leases.release(accountId: 1, holder: 'A');
    await h.leases.release(accountId: 1, holder: 'A');
    final read = (await h.leases.read(1))!;
    expect(read.expiresAt.millisecondsSinceEpoch, 0);
    expect(read.expiresAt.isUtc, isTrue);
    expect(read.bucket.tokens, 6);
    // Released by a holder: lease can be retaken, even right now.
    expect(await take(h.leases, 'B'), isNotNull);
    // release on a missing account is fine.
    await h.leases.release(accountId: 99, holder: 'Z');
    expect(await h.leases.read(99), isNull);
  });

  test(
    'a released lease cannot be renewed or written by the old holder',
    () async {
      await take(h.leases, 'A');
      await h.leases.release(accountId: 1, holder: 'A');
      expect(
        await h.leases.renew(accountId: 1, holder: 'A', ttl: _ttl),
        isFalse,
      );
      expect(
        await h.leases.writeBucket(
          accountId: 1,
          holder: 'A',
          bucket: GovernorBucket(tokens: 1, lastRefillAt: t0),
        ),
        isFalse,
      );
    },
  );

  test('old holder after a skewed takeover cannot renew or write', () async {
    await take(h.leases, 'A');
    h.clock.advance(const Duration(hours: -2));
    expect(await take(h.leases, 'B'), isNotNull);
    expect(await h.leases.renew(accountId: 1, holder: 'A', ttl: _ttl), isFalse);
    expect(
      await h.leases.writeBucket(
        accountId: 1,
        holder: 'A',
        bucket: GovernorBucket(tokens: 0, lastRefillAt: t0),
      ),
      isFalse,
    );
  });

  test(
    'skewed takeover keeps the stored bucket incl. far-future backoff',
    () async {
      await take(h.leases, 'A');
      final far = h.clock.now().add(const Duration(days: 20));
      final bucket = GovernorBucket(
        tokens: 1,
        lastRefillAt: h.clock.now(),
        backoffUntil: far,
        backoffMultiplier: 4,
      );
      await h.leases.writeBucket(accountId: 1, holder: 'A', bucket: bucket);
      h.clock.advance(const Duration(days: -1));
      final b = await take(h.leases, 'B');
      expect(b!.bucket, bucket);
    },
  );

  test('fake and drift agree on the same skew script', () async {
    final fake = FakeGovernorLeaseRepo(h.clock);
    final steps = <Duration>[
      Duration.zero,
      const Duration(hours: -1),
      const Duration(minutes: 11),
      const Duration(days: -2),
    ];
    final fakeOut = <String?>[];
    final driftOut = <String?>[];
    for (final s in steps) {
      h.clock.advance(s);
      for (final who in ['A', 'B']) {
        fakeOut.add((await take(fake, who))?.holder);
        driftOut.add((await take(h.leases, who))?.holder);
      }
    }
    expect(driftOut, fakeOut);
  });
}
