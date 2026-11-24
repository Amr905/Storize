import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart' as s;

RemoteUser user(String id, String name) => RemoteUser(
  remoteUserId: id,
  username: name,
  displayName: 'N',
  followedByViewer: false,
  blockedByViewer: false,
);

void main() {
  late FakeContentPlatform platform;
  late FakeTargetRepo targets;
  late FakeAccountRepo accounts;
  late FakeClock clock;
  late FakeContentRepo content;
  late AddTarget add;
  late ResolvePendingTargets resolve;

  setUp(() async {
    platform = FakeContentPlatform();
    targets = FakeTargetRepo();
    accounts = FakeAccountRepo();
    content = FakeContentRepo(targets: targets);
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
      scheduler: FakeScheduler(),
      clock: clock,
    );
    resolve = ResolvePendingTargets(
      platform: platform,
      targets: targets,
      accounts: accounts,
      history: BackfillHistory(
        platform: platform,
        targets: targets,
        content: content,
        accounts: accounts,
        settings: FakeSettingsRepo(),
        clock: clock,
      ),
      clock: clock,
    );
  });

  Future<Target> pend(String name, {HistoryRange r = HistoryRange.none}) async {
    platform.resolveUserResults.addFailure(const RateLimited(null));
    return (await add(
      name,
      category: TargetCategory.public,
      historyRange: r,
      highlights: true,
    ) as AddTargetPending).target;
  }

  test('watermark stays at add-day start after a later resolve', () async {
    final p = await pend('Nour');
    final mark = p.postsWatermarkAt;
    clock.advance(const Duration(days: 2));
    platform.resolveUserResults.addOk(user('9', 'Nour'));
    await resolve.run();
    final t = (await targets.getById(p.id))!;
    expect(t.postsWatermarkAt, mark);
    expect(t.status, TargetStatus.active);
    expect(t.highlightsEnabled, isTrue);
  });

  test(
    'real username differing only in case is applied, no duplicate',
    () async {
      final p = await pend('nour');
      platform.resolveUserResults.addOk(user('9', 'Nour'));
      await resolve.run();
      expect((await targets.getById(p.id))!.username, 'Nour');
      expect(await targets.watchAll().first, hasLength(1));
      expect(
        await add('NOUR', category: TargetCategory.public),
        isA<AddTargetDuplicate>(),
      );
    },
  );

  test('placeholder id never reaches platform in resolve', () async {
    final p = await pend('abc');
    platform.resolveUserResults.addFailure(const RateLimited(null));
    await resolve.run();
    expect(platform.calls.join(' '), isNot(contains('pending:')));
    expect(p.remoteUserId, 'pending:abc');
  });

  test('merge leaves existing target and its content intact', () async {
    final existing = await targets.insert(
      s.target(remoteUserId: '555', username: 'old'),
    );
    final p = await pend('newname');
    platform.resolveUserResults.addOk(user('555', 'newname'));
    await resolve.run();
    expect(await targets.getById(p.id), isNull);
    expect(await targets.getById(existing.id), isNotNull);
  });

  test('RemoveTarget of pending removes only that row', () async {
    final other = await targets.insert(
      s.target(remoteUserId: '1', username: 'o'),
    );
    final p = await pend('abc');
    final r = await RemoveTarget(
      targets: targets,
      content: content,
      deleteContent: DeleteContent(
        content: content,
        gallery: FakeGalleryStore(),
        cache: FakeMediaCache(),
      ),
    ).call(p.id, deleteMedia: true);
    expect(r.targetRemoved, isTrue);
    expect(await targets.getById(other.id), isNotNull);
    expect(await targets.watchAll().first, hasLength(1));
  });

  test('concurrent runs: one activation, history started once', () async {
    final p = await pend('abc', r: HistoryRange.days7);
    platform.resolveUserResults
      ..addOk(user('9', 'abc'))
      ..addOk(user('9', 'abc'));
    final rs = await Future.wait([resolve.run(), resolve.run()]);
    // QA finding F-1: both runs may report a resolve (non-atomic re-read).
    expect(rs.fold<int>(0, (a, b) => a + b.resolved), inInclusiveRange(1, 2));
    final t = (await targets.getById(p.id))!;
    expect(t.status, TargetStatus.active);
    expect(t.historyProgress?.state, HistoryState.running);
    expect(await targets.watchAll().first, hasLength(1));
  });

  test('pending add of tracked username refused without call', () async {
    await targets.insert(s.target(remoteUserId: '1', username: 'bob'));
    final before = platform.calls.length;
    expect(
      await add('BOB', category: TargetCategory.public),
      isA<AddTargetDuplicate>(),
    );
    expect(platform.calls.length, before);
  });
}
