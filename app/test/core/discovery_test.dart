// T-045: the foreground discovery refresher, the secure discovery store and
// the logout hook. Synthetic names only.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storize_app/core/discovery_refresher.dart';
import 'package:storize_app/core/discovery_secure_store.dart';
import 'package:storize_app/core/foreground_db_refresher.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/governor/governor.dart';
import 'package:storize_instagram/page/discovery_store.dart';
import 'package:storize_model/storize_model.dart';

import 'composition_rig.dart';

final _t0 = DateTime.utc(2026, 11, 24, 8);

SessionBlob _blob() => SessionBlob(
  cookies: const {'sessionid': 'ZZFAKE_sid', 'ds_user_id': '100'},
  userAgent: 'ZZFAKE-Agent',
  capturedAt: _t0,
);

DiscoverySnapshot _snap(DateTime at, {bool tokens = true}) => DiscoverySnapshot(
  docIds: {'stories': (docId: 'ZZFAKE_doc', at: at)},
  tokens: tokens ? const {'fb_dtsg': 'ZZFAKE_dtsg'} : null,
  tokensAt: tokens ? at : null,
);

final class _Rig {
  _Rig({AccountStatus status = AccountStatus.active, bool withAccount = true}) {
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
        loads.add((id, username));
        await gate?.future;
        return loadResult;
      },
    );
    ready = withAccount
        ? accounts
              .upsert(
                LoginAccount(
                  id: LoginAccount.unsavedId,
                  platform: PlatformId.instagram,
                  remoteUserId: '100',
                  username: 'zz_own',
                  status: status,
                  connectedAt: _t0,
                ),
              )
              .then((a) => accountId = a.id)
        : Future<void>.value();
  }

  final FakeClock clock = FakeClock(_t0);
  final FakeAccountRepo accounts = FakeAccountRepo();
  final FakeTargetRepo targets = FakeTargetRepo();
  final InMemoryDiscoveryStore store = InMemoryDiscoveryStore();
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final List<(int, String)> loads = [];
  Completer<void>? gate;
  Result<RemoteUser> loadResult = const Err(NetworkFailure());
  int accountId = 0;
  late final Future<void> ready;
  late final RequestGovernor governor;
  late final DiscoveryRefresher refresher;

  Future<void> addTarget(String username) async {
    await targets.insert(
      Target(
        id: Target.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: '200',
        username: username,
        category: TargetCategory.public,
        postsWatermarkAt: _t0,
        addedAt: _t0,
      ),
    );
  }
}

final class _ThrowingDiscovery implements DiscoveryStore {
  @override
  Future<DiscoverySnapshot?> load(int accountId) async => null;

  @override
  Future<void> save(int accountId, DiscoverySnapshot snapshot) async {}

  @override
  Future<void> clear(int accountId) async =>
      throw StateError('ZZFAKE_secret_in_error');
}

void main() {
  group('DiscoveryRefresher', () {
    test(
      'missing discovery: one governed load, at most once per 6 h',
      () async {
        final r = _Rig();
        await r.ready;
        expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.loaded);
        expect(r.loads, hasLength(1));

        expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.throttled);
        r.clock.advance(const Duration(hours: 5, minutes: 59));
        expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.throttled);
        expect(r.loads, hasLength(1), reason: 'a failed load is not retried');

        r.clock.advance(const Duration(minutes: 2));
        expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.loaded);
        expect(r.loads, hasLength(2));
      },
    );

    test('fresh stored discovery: no load; older than 6 h: load', () async {
      final r = _Rig();
      await r.ready;
      await r.store.save(r.accountId, _snap(_t0));
      r.clock.advance(const Duration(hours: 5));
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.fresh);
      expect(r.loads, isEmpty);

      r.clock.advance(const Duration(hours: 2));
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.loaded);
      expect(r.loads, hasLength(1));
    });

    test('stored doc_ids without tokens count as missing', () async {
      final r = _Rig();
      await r.ready;
      await r.store.save(r.accountId, _snap(_t0, tokens: false));
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.loaded);
    });

    test('skipped while the governor is paused for the account', () async {
      final r = _Rig();
      await r.ready;
      await r.governor.reportRateLimited(
        r.accountId,
        const RateLimited(Duration(minutes: 20)),
      );
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.paused);
      expect(r.loads, isEmpty);

      r.clock.advance(const Duration(minutes: 21));
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.loaded);
    });

    test('no account, or a logged-out one: nothing is loaded', () async {
      final none = _Rig(withAccount: false);
      expect(await none.refresher.refresh(), DiscoveryRefreshOutcome.noAccount);
      final out = _Rig(status: AccountStatus.loggedOut);
      await out.ready;
      expect(await out.refresher.refresh(), DiscoveryRefreshOutcome.noAccount);
      expect(none.loads, isEmpty);
      expect(out.loads, isEmpty);
    });

    test('loads a tracked profile, else the own one', () async {
      final own = _Rig();
      await own.ready;
      await own.refresher.refresh();
      expect(own.loads.single, (own.accountId, 'zz_own'));

      final tracked = _Rig();
      await tracked.ready;
      await tracked.addTarget('zz_target');
      await tracked.refresher.refresh();
      expect(tracked.loads.single, (tracked.accountId, 'zz_target'));
    });

    test('two calls at once start one load', () async {
      final r = _Rig()..gate = Completer<void>();
      await r.ready;
      final first = r.refresher.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(await r.refresher.refresh(), DiscoveryRefreshOutcome.busy);
      r.gate!.complete();
      expect(await first, DiscoveryRefreshOutcome.loaded);
      expect(r.loads, hasLength(1));
    });

    test('the log has outcome types only, no username', () async {
      final r = _Rig();
      await r.ready;
      await r.addTarget('zz_target');
      await r.refresher.refresh();
      final text = r.log.entries.map((e) => e.message).join('\n');
      expect(text, contains('refresh_done failure=NetworkFailure'));
      expect(text, isNot(contains('zz_target')));
      expect(text, isNot(contains('zz_own')));
    });

    test('a throwing load is contained', () async {
      final r = _Rig();
      await r.ready;
      final bad = DiscoveryRefresher(
        accounts: r.accounts,
        targets: r.targets,
        store: r.store,
        governor: r.governor,
        clock: r.clock,
        log: r.log,
        load: (_, _) async => throw StateError('ZZFAKE_secret'),
      );
      await bad.refresh();
      final text = r.log.entries.map((e) => e.message).join('\n');
      expect(text, contains('refresh_failed type=StateError'));
      expect(text, isNot(contains('ZZFAKE_secret')));
    });
  });

  group('SecureStorageDiscoveryStore', () {
    test('round trips under its own key and clears', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureStorageDiscoveryStore(const FlutterSecureStorage());
      await store.save(3, _snap(_t0));
      final back = (await store.load(3))!;
      expect(back.docIds['stories']!.docId, 'ZZFAKE_doc');
      expect(back.tokens, {'fb_dtsg': 'ZZFAKE_dtsg'});
      expect(SecureStorageDiscoveryStore.keyFor(3), 'storize.discovery.3');
      expect(await store.load(4), isNull);
      await store.clear(3);
      expect(await store.load(3), isNull);
      expect('$store', isNot(contains('ZZFAKE')));
    });

    test('a corrupt value reads as nothing, never throws', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureStorageDiscoveryStore.keyFor(1): '{not json ZZFAKE',
      });
      final store = SecureStorageDiscoveryStore(const FlutterSecureStorage());
      expect(await store.load(1), isNull);
    });
  });

  group('DiscoveryClearingSessionStore', () {
    test('clear (logout, account removal) forgets the discovery', () async {
      final sessions = FakeSessionStore();
      final discovery = InMemoryDiscoveryStore();
      final store = DiscoveryClearingSessionStore(sessions, discovery);
      await sessions.save(1, _blob());
      await discovery.save(1, _snap(_t0));
      await discovery.save(2, _snap(_t0));

      await store.clear(1);

      expect(sessions.accountIds, isEmpty);
      expect(await discovery.load(1), isNull);
      expect(await discovery.load(2), isNotNull, reason: 'other account kept');
    });

    test('a new login (save) drops the discovery of the old session', () async {
      final discovery = InMemoryDiscoveryStore();
      final store = DiscoveryClearingSessionStore(
        FakeSessionStore(),
        discovery,
      );
      await discovery.save(1, _snap(_t0));
      await store.save(1, _blob());
      expect(await discovery.load(1), isNull);
      expect(await store.load(1), isNotNull);
    });

    test(
      'a failing discovery clear does not break the session clear',
      () async {
        final sessions = FakeSessionStore();
        await sessions.save(1, _blob());
        final store = DiscoveryClearingSessionStore(
          sessions,
          _ThrowingDiscovery(),
        );
        await store.clear(1);
        expect(sessions.accountIds, isEmpty);
      },
    );
  });

  group('wiring', () {
    testWidgets('a refresh is requested at open and on every resume', (
      t,
    ) async {
      var calls = 0;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRefreshProvider.overrideWithValue(() async => calls++),
          ],
          child: const ForegroundDbRefresher(child: SizedBox()),
        ),
      );
      expect(calls, 1, reason: 'at open');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(calls, 2, reason: 'on resume');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a throwing refresh never reaches the UI', (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryRefreshProvider.overrideWithValue(
              () async => throw StateError('ZZFAKE'),
            ),
          ],
          child: const ForegroundDbRefresher(child: SizedBox()),
        ),
      );
      await t.pump();
      await t.pumpWidget(const SizedBox());
    });

    test(
      'only a foreground composition with a store has a refresher',
      () async {
        final fg = CompositionRig();
        final bg = CompositionRig(background: true);
        addTearDown(fg.dispose);
        addTearDown(bg.dispose);
        expect(fg.composition.discoveryRefresher, isNull, reason: 'no store');
        expect(bg.composition.discoveryRefresher, isNull);
      },
    );
  });
}
