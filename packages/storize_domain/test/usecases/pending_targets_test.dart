import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

RemoteUser user({
  String id = '100',
  String name = 'nour_k',
  bool isPrivate = false,
  bool followed = false,
}) => RemoteUser(
  remoteUserId: id,
  username: name,
  displayName: 'Nour',
  isPrivate: isPrivate,
  followedByViewer: followed,
  blockedByViewer: false,
);

void main() {
  late FakeContentPlatform platform;
  late FakeTargetRepo targets;
  late FakeAccountRepo accounts;
  late FakeScheduler scheduler;
  late FakeClock clock;
  late AddTarget add;
  late ResolvePendingTargets resolve;
  var base = 0;

  setUp(() async {
    platform = FakeContentPlatform();
    targets = FakeTargetRepo();
    accounts = FakeAccountRepo();
    scheduler = FakeScheduler();
    base = 0;
    clock = FakeClock(DateTime.utc(2026, 11, 24, 12));
    await accounts.upsert(
      LoginAccount(
        id: LoginAccount.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: 'me',
        username: 'me',
        status: AccountStatus.active,
        connectedAt: s.t0,
      ),
    );
    add = AddTarget(
      platform: platform,
      targets: targets,
      scheduler: scheduler,
      clock: clock,
    );
    resolve = ResolvePendingTargets(
      platform: platform,
      targets: targets,
      accounts: accounts,
      history: BackfillHistory(
        platform: platform,
        targets: targets,
        content: FakeContentRepo(targets: targets),
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: clock,
      ),
      clock: clock,
    );
  });

  Future<AddTargetResult> addUser(
    String name, {
    HistoryRange range = HistoryRange.none,
    bool highlights = false,
  }) => add(
    name,
    category: TargetCategory.public,
    note: 'n',
    trackReels: false,
    historyRange: range,
    highlights: highlights,
  );

  Future<Target> pending(
    String name, {
    HistoryRange range = HistoryRange.none,
  }) async {
    platform.resolveUserResults.addFailure(const NetworkFailure());
    final r = await addUser(name, range: range) as AddTargetPending;
    return r.target;
  }

  group('AddTarget pending (FR-73)', () {
    for (final (label, failure) in <(String, Failure)>[
      ('rate limited', const RateLimited(Duration(minutes: 9))),
      // The governor pause and maxWait reach the use case as RateLimited.
      ('governor paused', const RateLimited(null)),
      ('network', const NetworkFailure()),
    ]) {
      test('$label saves a pending target with the chosen options', () async {
        platform.resolveUserResults.addFailure(failure);
        final r = await addUser(
          'Nour_K',
          range: HistoryRange.days7,
          highlights: true,
        );
        final p = r as AddTargetPending;
        final t = (await targets.getById(p.target.id))!;
        expect(t.status, TargetStatus.pendingLookup);
        expect(t.username, 'nour_k');
        expect(t.remoteUserId, AddTarget.pendingRemoteUserId('nour_k'));
        expect(t.category, TargetCategory.public);
        expect(t.note, 'n');
        expect(t.trackReels, isFalse);
        expect(t.historyRange, HistoryRange.days7);
        expect(t.highlightsEnabled, isTrue);
        expect(t.postsWatermarkAt, DateTime(2026, 11, 24).toUtc());
        expect(scheduler.checkNowCalls.single.scope, CheckScope.posts);
        expect(scheduler.checkNowCalls.single.targetId, t.id);
      });
    }

    test('two pending adds do not collide', () async {
      await pending('a');
      await pending('b');
      expect(await targets.watchAll().first, hasLength(2));
    });

    test('scheduler failure keeps the pending target', () async {
      final failing = AddTarget(
        platform: platform,
        targets: targets,
        scheduler: _ThrowingScheduler(),
        clock: clock,
      );
      platform.resolveUserResults.addFailure(const NetworkFailure());
      final r = await failing('x', category: TargetCategory.public);
      expect((r as AddTargetPending).schedulerError, 'StateError');
      expect(await targets.watchAll().first, hasLength(1));
    });

    test('not found fails inline and stores nothing', () async {
      platform.resolveUserResults.addFailure(const TargetNotFound());
      expect(await addUser('x'), isA<AddTargetNotFound>());
      expect(await targets.watchAll().first, isEmpty);
    });

    test('private fails inline and stores nothing', () async {
      platform.resolveUserResults.addOk(user(isPrivate: true));
      expect(await addUser('x'), isA<AddTargetNotVisible>());
      expect(await targets.watchAll().first, isEmpty);
    });

    test('session invalid fails inline', () async {
      platform.resolveUserResults.addFailure(
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(await addUser('x'), isA<AddTargetSessionNotActive>());
      expect(await targets.watchAll().first, isEmpty);
    });

    test('duplicate by username, case-insensitive, makes no call', () async {
      final first = await pending('nour_k');
      base = platform.calls.length;
      final r = await addUser('@NOUR_K');
      expect((r as AddTargetDuplicate).existingId, first.id);
      expect(platform.calls.length, base);
    });

    test('duplicate by username against an active target', () async {
      await targets.insert(s.target(username: 'Alice'));
      final r = await addUser('alice');
      expect(r, isA<AddTargetDuplicate>());
    });
  });

  group('ResolvePendingTargets', () {
    test('success fills the target, activates it and starts history', () async {
      final p = await pending('nour_k', range: HistoryRange.days30);
      platform.resolveUserResults.addOk(user(id: '555'));
      final r = await resolve.run();
      expect(r.resolved, 1);
      expect(r.remaining, 0);
      final t = (await targets.getById(p.id))!;
      expect(t.status, TargetStatus.active);
      expect(t.remoteUserId, '555');
      expect(t.displayName, 'Nour');
      expect(t.historyProgress?.state, HistoryState.running);
      expect(t.category, TargetCategory.public);
    });

    test('success without history leaves no backfill', () async {
      final p = await pending('nour_k');
      platform.resolveUserResults.addOk(user(id: '555'));
      await resolve.run();
      expect((await targets.getById(p.id))!.historyProgress, isNull);
    });

    test('still limited stops the run and keeps the rest pending', () async {
      final a = await pending('a');
      final b = await pending('b');
      platform.resolveUserResults.addFailure(const RateLimited(null));
      base = platform.calls.length;
      final r = await resolve.run();
      expect(r.stop, ResolveStop.rateLimited);
      expect(r.remaining, 2);
      expect(
        platform.calls.length - base,
        1,
      );
      expect((await targets.getById(a.id))!.status, TargetStatus.pendingLookup);
      expect((await targets.getById(b.id))!.status, TargetStatus.pendingLookup);
    });

    test('network failure stops the run', () async {
      await pending('a');
      platform.resolveUserResults.addFailure(const NetworkFailure());
      expect((await resolve.run()).stop, ResolveStop.network);
    });

    test('resolves oldest first and continues after a success', () async {
      final a = await pending('a');
      final b = await pending('b');
      platform.resolveUserResults
        ..addOk(user(id: '1', name: 'a'))
        ..addFailure(const NetworkFailure());
      final r = await resolve.run();
      expect(r.resolved, 1);
      expect(r.remaining, 1);
      expect((await targets.getById(a.id))!.status, TargetStatus.active);
      expect((await targets.getById(b.id))!.status, TargetStatus.pendingLookup);
    });

    test('not found becomes unavailable', () async {
      final p = await pending('a');
      platform.resolveUserResults.addFailure(const TargetNotFound());
      final r = await resolve.run();
      expect(r.unavailable, 1);
      expect((await targets.getById(p.id))!.status, TargetStatus.unavailable);
    });

    test('not visible failure and private user become notVisible', () async {
      final a = await pending('a');
      final b = await pending('b');
      platform.resolveUserResults
        ..addFailure(const TargetNotVisible())
        ..addOk(user(id: '9', name: 'b', isPrivate: true));
      final r = await resolve.run();
      expect(r.notVisible, 2);
      expect((await targets.getById(a.id))!.status, TargetStatus.notVisible);
      final tb = (await targets.getById(b.id))!;
      expect(tb.status, TargetStatus.notVisible);
      expect(tb.remoteUserId, '9');
    });

    test('merge: an existing target with that id wins', () async {
      final existing = await targets.insert(
        s.target(remoteUserId: '555', username: 'old_name'),
      );
      final p = await pending('new_name');
      platform.resolveUserResults.addOk(user(id: '555', name: 'new_name'));
      final r = await resolve.run();
      expect(r.merged, 1);
      expect(await targets.getById(p.id), isNull);
      final kept = (await targets.getById(existing.id))!;
      expect(kept.username, 'old_name');
      expect(await targets.watchAll().first, hasLength(1));
    });

    test('a target removed meanwhile is not recreated', () async {
      final p = await pending('a');
      await targets.delete(p.id);
      final r = await resolve.run();
      expect(r.resolved, 0);
      expect(await targets.watchAll().first, isEmpty);
    });

    test('no active session: no call, all stay pending', () async {
      await pending('a');
      final acc = (await accounts.getActive())!;
      await accounts.setStatus(acc.id, AccountStatus.needsRelogin);
      base = platform.calls.length;
      final r = await resolve.run();
      expect(r.stop, ResolveStop.session);
      expect(r.remaining, 1);
      expect(platform.calls.length, base);
    });

    test('nothing pending: no call', () async {
      final r = await resolve.run();
      expect(r.resolved, 0);
      expect(platform.calls.length, base);
    });
  });

  group('pending targets are skipped', () {
    late Target p;
    setUp(() async {
      platform.resolveUserResults.addFailure(const NetworkFailure());
      p = (await add(
        'a',
        category: TargetCategory.public,
        highlights: true,
        historyRange: HistoryRange.days7,
      ) as AddTargetPending).target;
      base = platform.calls.length;
    });

    test('listActive does not return it', () async {
      for (final scope in CheckScope.values) {
        expect(await targets.listActive(scope), isEmpty);
      }
    });

    test('RunCheck makes no call for it', () async {
      final check = RunCheck(
        platform: platform,
        signals: FakeContentSignals(),
        targets: targets,
        content: FakeContentRepo(targets: targets),
        accounts: accounts,
        checkRuns: FakeCheckRunRepo(),
        activity: FakeActivityRepo(clock),
        settings: FakeSettingsRepo(),
        clock: clock,
      );
      await check.call(
        scope: CheckScope.posts,
        trigger: CheckTrigger.manualOne,
        targetId: p.id,
      );
      expect(platform.calls.length, base);
    });

    test('SyncHighlights skips it', () async {
      final sync = SyncHighlights(
        platform: platform,
        targets: targets,
        content: FakeContentRepo(targets: targets),
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: clock,
      );
      expect((await sync.run(p.id)).outcome, HighlightsOutcome.skipped);
      expect(platform.calls.length, base);
    });

    test('BackfillHistory skips it even when running', () async {
      final history = BackfillHistory(
        platform: platform,
        targets: targets,
        content: FakeContentRepo(targets: targets),
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: clock,
      );
      await history.start(p.id, HistoryRange.days7);
      expect((await history.step(p.id)).outcome, BackfillOutcome.skipped);
      expect((await history.runDue()).running, 0);
      expect(platform.calls.length, base);
    });
  });
}

class _ThrowingScheduler implements Scheduler {
  @override
  Future<void> apply({
    required int storyMin,
    required int postMin,
    required bool wifiOnly,
  }) async {}

  @override
  Future<void> checkNow({
    CheckScope scope = CheckScope.all,
    int? targetId,
    bool unmetered = false,
  }) async => throw StateError('x');

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> kickHistory() async {}
}
