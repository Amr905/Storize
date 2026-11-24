// T-047: the refresher's account id, the extra stories load and the
// secret-free state log. Synthetic ZZFAKE_ values only.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/discovery_refresher.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/doc_id_resolver.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_instagram/page/page_discovery.dart';
import 'package:storize_model/storize_model.dart';

final _t0 = DateTime.utc(2026, 11, 24, 8);

final class _Rig {
  _Rig({
    this.storyAge = const Duration(hours: 2),
    this.trackStories = true,
    this.profileFails = false,
    this.pauseDuringProfile = false,
    this.storiesFail = false,
  }) {
    governor = RequestGovernor(
      leases: FakeGovernorLeaseRepo(clock),
      clock: clock,
      holder: 'test',
      config: const GovernorConfig(
        jitterMin: Duration.zero,
        jitterMax: Duration.zero,
      ),
    );
    refresher = DiscoveryRefresher(
      accounts: accounts,
      targets: targets,
      store: store,
      governor: governor,
      clock: clock,
      log: log,
      load: (id, username) async {
        loads.add(id);
        // The page records into a PageDiscovery of this account id.
        final d = PageDiscovery(clock: clock, store: store, accountId: id)
          ..record(
            friendlyName: 'PolarisProfilePostsTabContentQuery_connection',
            docId: '1234567',
            tokens: const {'fb_dtsg': 'ZZFAKE_dtsg_secret'},
          );
        await d.flush();
        if (profileFails) return const Err(NetworkFailure());
        if (pauseDuringProfile) {
          await governor.reportRateLimited(
            id,
            const RateLimited(Duration(hours: 1)),
          );
        }
        return const Ok(
          RemoteUser(
            remoteUserId: '200',
            username: 'zz_target',
            followedByViewer: true,
            blockedByViewer: false,
          ),
        );
      },
      profileStoryTime: (id, userId) =>
          storyAge == null ? null : clock.now().subtract(storyAge!),
      loadStories: (id, target) async {
        storyLoads.add(target.remoteUserId);
        if (storiesFail) return const Err(RateLimited(null));
        return const Ok(null);
      },
    );
    ready = Future(() async {
      final a = await accounts.upsert(
        LoginAccount(
          id: LoginAccount.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: '100',
          username: 'zz_own',
          status: AccountStatus.active,
          connectedAt: _t0,
        ),
      );
      accountId = a.id;
      await targets.insert(
        Target(
          id: Target.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: '200',
          username: 'zz_target',
          category: TargetCategory.public,
          trackStories: trackStories,
          postsWatermarkAt: _t0,
          addedAt: _t0,
        ),
      );
    });
  }

  final Duration? storyAge;
  final bool trackStories;
  final bool profileFails;
  final bool pauseDuringProfile;
  final bool storiesFail;
  final FakeClock clock = FakeClock(_t0);
  final FakeAccountRepo accounts = FakeAccountRepo();
  final FakeTargetRepo targets = FakeTargetRepo();
  final InMemoryDiscoveryStore store = InMemoryDiscoveryStore();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<int> loads = [];
  final List<String> storyLoads = [];
  int accountId = 0;
  late final Future<void> ready;
  late final RequestGovernor governor;
  late final DiscoveryRefresher refresher;
}

void main() {
  test(
    'what the refresher stores is what direct mode reads (account id)',
    () async {
      final r = _Rig();
      await r.ready;
      await r.refresher.refresh();
      expect(r.loads, [r.accountId]);
      final direct = PageDiscovery(
        clock: r.clock,
        store: r.store,
        accountId: r.accountId,
      );
      expect(await direct.docIdFor(GraphqlQuery.posts), '1234567');
      expect(await direct.tokens(), isNotNull);
      final other = PageDiscovery(
        clock: r.clock,
        store: r.store,
        accountId: r.accountId + 1,
      );
      expect(await other.docIdFor(GraphqlQuery.posts), isNull);
    },
  );

  test(
    'extra stories load: tracked target with a current story, once',
    () async {
      final r = _Rig();
      await r.ready;
      await r.refresher.refresh();
      expect(r.storyLoads, ['200']);
      // Throttled: the same 6 h window makes no further load of any kind.
      await r.refresher.refresh();
      r.clock.advance(const Duration(hours: 5));
      await r.refresher.refresh();
      expect(r.loads, hasLength(1));
      expect(r.storyLoads, hasLength(1));
    },
  );

  test('no extra stories load without a current story', () async {
    final none = _Rig(storyAge: null);
    await none.ready;
    await none.refresher.refresh();
    expect(none.storyLoads, isEmpty);

    final old = _Rig(storyAge: const Duration(hours: 30));
    await old.ready;
    await old.refresher.refresh();
    expect(old.storyLoads, isEmpty);
  });

  test('no extra stories load when stories are not tracked', () async {
    final r = _Rig(trackStories: false);
    await r.ready;
    await r.refresher.refresh();
    expect(r.loads, hasLength(1));
    expect(r.storyLoads, isEmpty);
  });

  test('the state log names queries and never a value', () async {
    final r = _Rig();
    await r.ready;
    await r.refresher.refresh();
    final text = r.log.entries.map((e) => e.message).join('\n');
    expect(text, contains('state doc_ids=posts'));
    expect(text, contains('missing=stories'));
    expect(text, contains('tokens=true'));
    expect(text, isNot(contains('1234567')));
    expect(text, isNot(contains('ZZFAKE')));
  });

  test('QA: a failed profile load makes no extra stories load', () async {
    final r = _Rig(profileFails: true);
    await r.ready;
    await r.refresher.refresh();
    expect(r.storyLoads, isEmpty);
  });

  test('QA: a paused governor makes no extra stories load', () async {
    final r = _Rig(pauseDuringProfile: true);
    await r.ready;
    await r.refresher.refresh();
    expect(r.loads, hasLength(1));
    expect(r.storyLoads, isEmpty);
  });

  test('QA: a failing stories load is logged by type only', () async {
    final r = _Rig(storiesFail: true);
    await r.ready;
    await r.refresher.refresh();
    expect(r.storyLoads, ['200']);
    final text = r.log.entries.map((e) => e.message).join('\n');
    expect(text, contains('stories_load failure=RateLimited'));
  });
}
