// T-056 (FR-75): mapping of the Health read model over a real drift database.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';

import 'support/builders.dart';
import 'support/harness.dart';

void main() {
  late DriftHarness h;
  late DriftHealthReadModel model;

  setUp(() {
    h = DriftHarness();
    model = DriftHealthReadModel(
      h.db,
      clock: h.clock,
      settingsRepo: FakeSettingsRepo(),
    );
  });
  tearDown(() => h.dispose());

  Future<LoginAccount> login({AccountStatus status = AccountStatus.active}) =>
      h.accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: 'self-1',
          username: 'storize_archive',
          status: status,
          connectedAt: t0,
        ),
      );

  test('an empty database reads as a fresh, unpaused budget', () async {
    final s = await model.read();
    expect(s.session, isNull);
    expect(s.budget.burst, 6);
    expect(s.budget.callsPerHour, 60);
    expect(s.budget.availableNow, 6);
    expect(s.budget.pausedUntil, isNull);
    expect(s.schedule.storyIntervalMin, 30);
    expect(s.schedule.postIntervalMin, 180);
    expect(s.schedule.lastRunAt, isNull);
    expect(s.targets, isEmpty);
  });

  test('the session shows the login account and its status', () async {
    await login(status: AccountStatus.needsRelogin);
    final s = await model.read();
    expect(s.session?.username, 'storize_archive');
    expect(s.session?.status, AccountStatus.needsRelogin);
  });

  test('a paused governor shows the pause end and no tokens left', () async {
    final account = await login();
    final now = h.clock.now();
    await h.leases.acquire(
      accountId: account.id,
      holder: 'test',
      ttl: const Duration(minutes: 10),
      initialBucket: GovernorBucket(
        tokens: 0,
        lastRefillAt: now,
        backoffUntil: now.add(const Duration(hours: 2)),
        backoffMultiplier: 2,
      ),
    );
    final s = await model.read();
    expect(s.budget.pausedUntil, now.add(const Duration(hours: 2)));
    expect(s.budget.availableNow, 0);
  });

  test('tokens refill at the hourly rate, capped at the burst', () async {
    final account = await login();
    final now = h.clock.now();
    await h.leases.acquire(
      accountId: account.id,
      holder: 'test',
      ttl: const Duration(minutes: 10),
      initialBucket: GovernorBucket(tokens: 0, lastRefillAt: now),
    );
    // 3 minutes at 60 per hour is 3 tokens.
    h.clock.advance(const Duration(minutes: 3));
    final later = await model.read();
    expect(later.budget.availableNow, 3);
    expect(later.budget.pausedUntil, isNull);

    // Far later the bucket is full at the burst of 6.
    h.clock.advance(const Duration(hours: 5));
    expect((await model.read()).budget.availableNow, 6);
  });

  test('a failed target carries its reason; saved today counts DONE '
      'media from today only', () async {
    final now = h.clock.now();
    final failed = await h.targets.insert(
      aTarget(username: 'failed_one').copyWith(
        lastSuccessAt: now.subtract(const Duration(days: 1)),
        lastCheckOutcome: TargetCheckOutcome.failed,
        lastCheckCode: 'network',
      ),
    );
    final busy = await h.targets.insert(
      aTarget(remoteUserId: 'u-2', username: 'busy_one').copyWith(
        lastSuccessAt: now,
        lastCheckOutcome: TargetCheckOutcome.ok,
      ),
    );

    // Two items for `busy` today (one with two slides, one file each), one
    // done yesterday, and one still pending today.
    await h.content.insertIfNew(aContent(busy.id, remoteId: 'today-1'), [
      aMedia(status: MediaFileStatus.done),
    ]);
    await h.content.insertIfNew(aContent(busy.id, remoteId: 'today-2'), [
      aMedia(status: MediaFileStatus.done),
    ]);
    await h.content.insertIfNew(aContent(busy.id, remoteId: 'old'), [
      aMedia(status: MediaFileStatus.done),
    ]);
    await h.content.insertIfNew(aContent(busy.id, remoteId: 'queued'), [
      aMedia(),
    ]);
    await h.db.customStatement(
      'UPDATE media_file SET downloaded_at = ? WHERE content_id IN '
      "(SELECT id FROM content WHERE remote_id = 'old')",
      [now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch],
    );
    await h.db.customStatement(
      'UPDATE media_file SET downloaded_at = ? WHERE content_id IN '
      "(SELECT id FROM content WHERE remote_id IN ('today-1', 'today-2'))",
      [now.millisecondsSinceEpoch],
    );

    final s = await model.read();
    final byId = {for (final t in s.targets) t.id: t};
    final f = byId[failed.id]!;
    expect(f.lastOutcome, TargetCheckOutcome.failed);
    expect(f.lastCode, 'network');
    expect(f.savedToday, 0);
    expect(f.lastSuccessAt, isNotNull);

    final b = byId[busy.id]!;
    expect(b.lastOutcome, TargetCheckOutcome.ok);
    expect(b.lastCode, isNull);
    expect(b.savedToday, 2);
  });
}
