import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../support/builders.dart';
import '../support/harness.dart';

LoginAccount anAccount({
  String remoteUserId = 'acct-1',
  String username = 'tester',
  DateTime? connectedAt,
  AccountStatus status = AccountStatus.active,
  String? userAgent,
  String? statusReason,
  DateTime? lastSuccessAt,
}) => LoginAccount(
  id: LoginAccount.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: remoteUserId,
  username: username,
  status: status,
  statusReason: statusReason,
  connectedAt: connectedAt ?? t0,
  lastSuccessAt: lastSuccessAt,
  userAgent: userAgent,
);

/// Behaviour every [AccountRepo] must show.
void runAccountRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late AccountRepo repo;
  setUp(() {
    h = create();
    repo = h.accounts;
  });
  tearDown(() => h.dispose());

  test('no account yet: getActive and watchActive give null', () async {
    expect(await repo.getActive(), isNull);
    final w = Watch(repo.watchActive());
    addTearDown(w.cancel);
    await w.until((a) => a == null);
  });

  test('upsert inserts, assigns an id and round-trips every field', () async {
    final stored = await repo.upsert(
      anAccount(
        userAgent: 'UA',
        statusReason: 'why',
        lastSuccessAt: at(4),
        status: AccountStatus.restricted,
      ),
    );
    expect(stored.id, isNot(LoginAccount.unsavedId));
    expect(await repo.getActive(), stored);
    expect(stored.userAgent, 'UA');
    expect(stored.lastSuccessAt, at(4));
  });

  test(
    'upsert on the same remoteUserId keeps the id and replaces the row',
    () async {
      final first = await repo.upsert(
        anAccount(userAgent: 'UA', lastSuccessAt: at(1), statusReason: 'x'),
      );
      final second = await repo.upsert(
        anAccount(username: 'renamed', connectedAt: at(9)),
      );
      expect(second.id, first.id);
      expect(second.username, 'renamed');
      expect(second.userAgent, isNull);
      expect(second.lastSuccessAt, isNull);
      expect(await repo.getActive(), second);
    },
  );

  test(
    'the active account is the latest connectedAt, ties by higher id',
    () async {
      await repo.upsert(anAccount(remoteUserId: 'a', connectedAt: at(5)));
      final newest = await repo.upsert(
        anAccount(remoteUserId: 'b', connectedAt: at(8)),
      );
      expect((await repo.getActive())!.id, newest.id);
      final tie = await repo.upsert(
        anAccount(remoteUserId: 'c', connectedAt: at(8)),
      );
      expect((await repo.getActive())!.id, tie.id);
    },
  );

  test('setStatus updates status and reason; null reason clears; null '
      'lastSuccessAt keeps the stored value', () async {
    final stored = await repo.upsert(anAccount(lastSuccessAt: at(1)));
    await repo.setStatus(
      stored.id,
      AccountStatus.needsRelogin,
      reason: 'expired',
    );
    var read = (await repo.getActive())!;
    expect(read.status, AccountStatus.needsRelogin);
    expect(read.statusReason, 'expired');
    expect(read.lastSuccessAt, at(1));

    await repo.setStatus(stored.id, AccountStatus.active, lastSuccessAt: at(7));
    read = (await repo.getActive())!;
    expect(read.status, AccountStatus.active);
    expect(read.statusReason, isNull);
    expect(read.lastSuccessAt, at(7));
  });

  test('setStatus of an unknown id is a StateError', () async {
    await expectLater(
      repo.setStatus(55, AccountStatus.active),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'watchActive emits on subscribe and after upsert and setStatus',
    () async {
      final w = Watch(repo.watchActive());
      addTearDown(w.cancel);
      await w.until((a) => a == null);
      w.mark();
      final stored = await repo.upsert(anAccount());
      await w.until((a) => a?.id == stored.id);
      w.mark();
      await repo.setStatus(stored.id, AccountStatus.loggedOut, reason: 'bye');
      await w.until((a) => a?.status == AccountStatus.loggedOut);
    },
  );

  test('every watch call returns a new stream', () {
    expect(identical(repo.watchActive(), repo.watchActive()), isFalse);
  });
}

ActivityEvent anEvent({
  required DateTime at,
  ActivityType type = ActivityType.checkDone,
  int? targetId,
  int? checkRunId,
  Map<String, Object?> payload = const {},
  int count = 1,
  Severity severity = Severity.info,
}) => ActivityEvent(
  id: ActivityEvent.unsavedId,
  at: at,
  type: type,
  severity: severity,
  targetId: targetId,
  checkRunId: checkRunId,
  count: count,
  payload: payload,
);

/// Behaviour every [ActivityRepo] must show. The clock starts at
/// 2026-01-01T00:00Z.
void runActivityRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late ActivityRepo repo;
  setUp(() {
    h = create();
    repo = h.activity;
  });
  tearDown(() => h.dispose());

  DateTime now() => h.clock.now();
  Duration ago(int minutes) => Duration(minutes: minutes);

  Future<List<ActivityEvent>> recent([
    Set<ActivityType> types = const {},
  ]) async {
    final w = Watch(repo.watchRecent(types: types));
    addTearDown(w.cancel);
    return w.until((_) => true);
  }

  test(
    'add assigns ids and round-trips every field, incl. the payload',
    () async {
      final target = await h.targets.insert(aTarget());
      final run = await h.checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: now(),
      );
      final stored = await repo.add(
        anEvent(
          at: now().subtract(ago(5)),
          type: ActivityType.gap,
          severity: Severity.warn,
          targetId: target.id,
          checkRunId: run.id,
          count: 4,
          payload: {
            'n': 1,
            'nested': {
              'list': [1, 'two'],
            },
            'nothing': null,
          },
        ),
      );
      expect(stored.id, isNot(ActivityEvent.unsavedId));
      final read = (await recent()).single;
      expect(read, stored);
      expect(read.payload['nothing'], isNull);
    },
  );

  test('add ignores the id on the event passed in', () async {
    final stored = await repo.add(anEvent(at: now()).copyWith(id: 77));
    expect(stored.id, isNot(77));
  });

  test('watchRecent is newest first, ties by higher id', () async {
    final a = await repo.add(anEvent(at: now().subtract(ago(30))));
    final b = await repo.add(anEvent(at: now().subtract(ago(10))));
    final c = await repo.add(anEvent(at: now().subtract(ago(10))));
    expect((await recent()).map((e) => e.id), [c.id, b.id, a.id]);
  });

  test('type filter; an empty set means every type', () async {
    final a = await repo.add(anEvent(at: now(), type: ActivityType.gap));
    await repo.add(anEvent(at: now(), type: ActivityType.rateLimited));
    final c = await repo.add(
      anEvent(at: now(), type: ActivityType.targetStatus),
    );
    expect(
      (await recent({ActivityType.gap, ActivityType.targetStatus}))
          .map((e) => e.id)
          .toSet(),
      {a.id, c.id},
    );
    expect(await recent(), hasLength(3));
  });

  test('the window is the last 7 days: exactly 7 days is in, 1 ms older '
      'is out', () async {
    final edge = await repo.add(
      anEvent(at: now().subtract(ActivityEvent.retention)),
    );
    await repo.add(
      anEvent(
        at: now().subtract(
          ActivityEvent.retention + const Duration(milliseconds: 1),
        ),
      ),
    );
    expect((await recent()).map((e) => e.id), [edge.id]);
  });

  test(
    'the window follows the injected clock on every emission (F-4)',
    () async {
      final old = await repo.add(anEvent(at: now().subtract(ago(10))));
      final w = Watch(repo.watchRecent());
      addTearDown(w.cancel);
      await w.until((l) => l.length == 1);

      h.clock.advance(const Duration(days: 8));
      w.mark();
      final fresh = await repo.add(anEvent(at: now()));
      final list = await w.until((l) => l.any((e) => e.id == fresh.id));
      expect(list.map((e) => e.id), [fresh.id]);
      expect(list.map((e) => e.id), isNot(contains(old.id)));
    },
  );

  test('watchRecent emits on subscribe and after add and prune', () async {
    final w = Watch(repo.watchRecent());
    addTearDown(w.cancel);
    await w.until((l) => l.isEmpty);
    w.mark();
    final e = await repo.add(anEvent(at: now()));
    await w.until((l) => l.length == 1 && l.single.id == e.id);
    w.mark();
    expect(await repo.pruneOlderThan(now().add(ago(1))), 1);
    await w.until((l) => l.isEmpty);
  });

  test(
    'pruneOlderThan is exclusive of the cutoff and returns the count',
    () async {
      final cutoff = now().subtract(ago(60));
      await repo.add(anEvent(at: cutoff.subtract(ago(10))));
      await repo.add(
        anEvent(at: cutoff.subtract(const Duration(milliseconds: 1))),
      );
      final keep = await repo.add(anEvent(at: cutoff));
      expect(await repo.pruneOlderThan(cutoff), 2);
      expect((await recent()).map((e) => e.id), [keep.id]);
      expect(await repo.pruneOlderThan(cutoff), 0);
    },
  );

  test('every watch call returns a new stream', () {
    expect(identical(repo.watchRecent(), repo.watchRecent()), isFalse);
  });
}
