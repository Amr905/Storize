// QA tests for T-045 (secure discovery store, foreground refresher).
// Synthetic ZZFAKE_ values only.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_app/core/discovery_refresher.dart';
import 'package:storize_app/core/discovery_secure_store.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_model/storize_model.dart';

final _t0 = DateTime.utc(2026, 11, 24, 8);

DiscoverySnapshot _snap(DateTime docAt, DateTime tokAt) => DiscoverySnapshot(
  docIds: {'stories': (docId: 'ZZFAKE_doc', at: docAt)},
  tokens: const {'fb_dtsg': 'ZZFAKE_dtsg'},
  tokensAt: tokAt,
);

final class _Rig {
  _Rig() {
    governor = RequestGovernor(
      leases: FakeGovernorLeaseRepo(clock),
      clock: clock,
      holder: 'test',
      config: const GovernorConfig(
        jitterMin: Duration.zero,
        jitterMax: Duration.zero,
      ),
    );
    ready = accounts
        .upsert(
          LoginAccount(
            id: LoginAccount.unsavedId,
            platform: PlatformId.instagram,
            remoteUserId: '100',
            username: 'zz_own',
            status: AccountStatus.active,
            connectedAt: _t0,
          ),
        )
        .then((a) => id = a.id);
  }

  final FakeClock clock = FakeClock(_t0);
  final FakeAccountRepo accounts = FakeAccountRepo();
  final FakeTargetRepo targets = FakeTargetRepo();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final DiscoveryStore store = InMemoryDiscoveryStore();
  final List<String> loads = [];
  int id = 0;
  late final Future<void> ready;
  late final RequestGovernor governor;

  DiscoveryRefresher refresher() => DiscoveryRefresher(
    accounts: accounts,
    targets: targets,
    store: store,
    governor: governor,
    clock: clock,
    log: log,
    load: (i, u) async {
      loads.add(u);
      return const Err(NetworkFailure());
    },
  );
}

void main() {
  group('secrets', () {
    test('only the discovery key reaches secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final store = SecureStorageDiscoveryStore(storage);
      await store.save(7, _snap(_t0, _t0));
      expect((await storage.readAll()).keys, [
        SecureStorageDiscoveryStore.keyFor(7),
      ]);
    });

    test('the discovery sources never touch prefs, files, print or logs', () {
      for (final f in [
        'lib/core/discovery_secure_store.dart',
        'lib/core/discovery_refresher.dart',
        '../packages/storize_instagram/lib/page/discovery_store.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, isNot(contains('shared_preferences')), reason: f);
        expect(src, isNot(contains('dart:io')), reason: f);
        expect(src, isNot(contains('print(')), reason: f);
        expect(src, isNot(contains('debugPrint')), reason: f);
        expect(src, isNot(contains('drift')), reason: f);
      }
    });

    test('toString of every type shows no value', () async {
      final snap = _snap(_t0, _t0);
      final text = [
        '$snap',
        '${SecureStorageDiscoveryStore(const FlutterSecureStorage())}',
        '${DiscoveryClearingSessionStore(
          FakeSessionStore(),
          InMemoryDiscoveryStore(),
        )}',
      ].join();
      expect(text, isNot(contains('ZZFAKE')));
    });

    test('a failing inner clear still clears discovery and rethrows', () async {
      final discovery = InMemoryDiscoveryStore();
      await discovery.save(1, _snap(_t0, _t0));
      final store = DiscoveryClearingSessionStore(
        _ThrowingSessions(),
        discovery,
      );
      await expectLater(store.clear(1), throwsStateError);
      expect(await discovery.load(1), isNull);
    });

    test(
      'a throwing secure-storage read is nothing, without the text',
      () async {
        final store = SecureStorageDiscoveryStore(const _ThrowingStorage());
        expect(await store.load(1), isNull);
      },
    );
  });

  group('refresher traffic', () {
    test(
      'a failing load is not retried on 30 resumes; again after 6 h',
      () async {
        final r = _Rig();
        await r.ready;
        final f = r.refresher();
        for (var i = 0; i < 30; i++) {
          await f.refresh();
          r.clock.advance(const Duration(minutes: 5));
        }
        expect(r.loads, hasLength(1));
        r.clock.advance(const Duration(hours: 6));
        await f.refresh();
        expect(r.loads, hasLength(2));
      },
    );

    test('paused governor: zero loads, however often it is asked', () async {
      final r = _Rig();
      await r.ready;
      await r.governor.reportRateLimited(
        r.id,
        const RateLimited(Duration(minutes: 15)),
      );
      final f = r.refresher();
      for (var i = 0; i < 5; i++) {
        await f.refresh();
      }
      expect(r.loads, isEmpty);
    });

    test('fresh complete discovery: zero loads', () async {
      final r = _Rig();
      await r.ready;
      await r.store.save(r.id, _snap(_t0, _t0));
      expect(await r.refresher().refresh(), DiscoveryRefreshOutcome.fresh);
      expect(r.loads, isEmpty);
    });

    test(
      'expired tokens next to a fresh doc_id still trigger a load',
      () async {
        final r = _Rig();
        await r.ready;
        // tokens 13 h old (past the 12 h life), doc_id 1 h old.
        await r.store.save(
          r.id,
          _snap(
            _t0.subtract(const Duration(hours: 1)),
            _t0.subtract(const Duration(hours: 13)),
          ),
        );
        expect(await r.refresher().refresh(), DiscoveryRefreshOutcome.loaded);
      },
      skip: 'QA-4: newestAt ignores token expiry, see T-045.md',
    );

    test(
      'app restart (new refresher) after a failed load loads again',
      () async {
        final r = _Rig();
        await r.ready;
        await r.refresher().refresh();
        await r
            .refresher()
            .refresh(); // a process restart: memory throttle lost
        expect(
          r.loads,
          hasLength(1),
          reason: 'throttle is per process: every app start retries a failure',
        );
      },
      skip: 'QA-3: throttle is in memory only, see T-045.md',
    );

    test('logs are outcome types only', () async {
      final r = _Rig();
      await r.ready;
      await r.targets.insert(
        Target(
          id: Target.unsavedId,
          platform: PlatformId.instagram,
          remoteUserId: '200',
          username: 'zz_target_secretish',
          category: TargetCategory.public,
          postsWatermarkAt: _t0,
          addedAt: _t0,
        ),
      );
      await r.refresher().refresh();
      final text = r.log.entries.map((e) => e.message).join('\n');
      expect(text, contains('refresh_done failure=NetworkFailure'));
      expect(text, isNot(contains('zz_target')));
      expect(text, isNot(contains('zz_own')));
    });
  });
}

final class _ThrowingSessions implements SessionStore {
  @override
  Future<void> save(int accountId, SessionBlob session) async {}

  @override
  Future<SessionBlob?> load(int accountId) async => null;

  @override
  Future<void> clear(int accountId) async => throw StateError('x');
}

final class _ThrowingStorage implements FlutterSecureStorage {
  const _ThrowingStorage();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<String?>.error(StateError('ZZFAKE_secret_in_error'));
}
