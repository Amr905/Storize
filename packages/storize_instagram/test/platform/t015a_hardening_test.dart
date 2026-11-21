// T-015a: hardening of InstagramPlatform (F1 multi-user page stories, I2 use
// counting, F2 lease loss, F5 acquire race, F7 username overlay, F6 timeout).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/direct/direct.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_instagram/platform/platform.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _schema = SchemaChanged('doc_id:ZZFAKE');

final class _Names implements UsernameCache {
  _Names(this.map);
  final Map<String, String> map;
  @override
  Future<String?> usernameOf(String userId) async => map[userId];
  @override
  Future<void> remember(String userId, String username) async {}
}

final class _Rig {
  _Rig({Map<String, String>? names, SeenGuard? guard}) {
    platform = InstagramPlatform(
      direct: direct,
      page: page,
      media: CdnMediaOpener(http: FakeCdnHttp((_, _) => throw StateError('x'))),
      seenGuard: guard ?? SeenGuard(),
      log: log,
      usernames: names == null ? null : _Names(names),
    );
    direct.stories = (_) => const Err(_schema);
    direct.user = () => const Err(_schema);
  }

  final calls = <String>[];
  late final direct = FakeMode('direct', calls);
  late final page = FakeMode('page', calls);
  final log = FakeDiagnosticLog();
  late final InstagramPlatform platform;

  Future<Result<Map<String, List<RemoteContent>>>> stories(List<String> ids) =>
      platform.fetchStories(ids, policy: ExtractionPolicy.directThenPage);

  int get pageLoads => calls.where((c) => c == 'page.fetchStories').length;
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

RemoteContent _item(String id) => RemoteContent(
  remoteId: id,
  kind: ContentKind.story,
  postedAt: DateTime.utc(2026),
  slides: const [],
);

void main() {
  group('F1 multi-user page stories', () {
    test('AC: a username_unknown anywhere aborts before the first load, '
        'returns the direct SchemaChanged and counts no use', () async {
      final rig = _Rig(names: {'u1': 'name_one'}); // u2 has no username
      final r = await rig.stories(['u1', 'u2']);
      expect(rig.pageLoads, 0);
      expect(r.failureOrNull, _schema);
      expect(rig.platform.takeSignals().pageModeUses, 0);
      expect(rig.platform.takePartialStories(), isNull);
    });

    test('AC: a bad username shape also aborts before any load', () async {
      final rig = _Rig(names: {'u1': 'name_one', 'u2': 'bad name!'});
      final r = await rig.stories(['u1', 'u2']);
      expect(rig.pageLoads, 0);
      expect(r.failureOrNull, _schema);
    });

    test('AC: all names known -> every user loads, merged, one use, no '
        'partial record', () async {
      final rig = _Rig(names: {'u1': 'name_one', 'u2': 'name_two'});
      rig.page.stories = (ids) => Ok({
        ids.single: [_item('m_${ids.single}')],
      });
      final r = await rig.stories(['u1', 'u2']);
      expect(r.valueOrNull!.keys, ['u1', 'u2']);
      expect(rig.platform.takeSignals().pageModeUses, 1);
      expect(rig.platform.takePartialStories(), isNull);
    });

    test('AC: a failure after user 1 loaded is returned (never hidden), the '
        'use is counted once and the loaded data is kept with the skipped '
        'count', () async {
      final rig = _Rig(names: {'u1': 'a_1', 'u2': 'a_2', 'u3': 'a_3'});
      rig.page.stories = (ids) => ids.single == 'u1'
          ? Ok({
              'u1': [_item('m1')],
            })
          : const Err(SessionInvalid(SessionReason.loginRequired));
      final r = await rig.stories(['u1', 'u2', 'u3']);
      expect(r.failureOrNull, isA<SessionInvalid>());
      expect(rig.pageLoads, 2, reason: 'the loop stops at the failure');
      expect(rig.platform.takeSignals().pageModeUses, 1);
      final partial = rig.platform.takePartialStories()!;
      expect(partial.loaded.keys, ['u1']);
      expect(partial.loaded['u1']!.single.remoteId, 'm1');
      expect(partial.skipped, 2);
      expect(rig.platform.takePartialStories(), isNull, reason: 'read once');
      expect(logText(rig.log), contains('page_stories_partial loaded=1'));
      expect(logText(rig.log), isNot(contains('u1')));
    });

    test('a failure of the FIRST user keeps no partial record and counts the '
        'use when the page opened', () async {
      final rig = _Rig();
      rig.page.pagesOpened = 0;
      rig.page.stories = (_) {
        rig.page.pagesOpened = rig.page.pagesOpened! + 1;
        return const Err(NetworkFailure());
      };
      final r = await rig.stories(['u1']);
      expect(r.failureOrNull, isA<NetworkFailure>());
      expect(rig.platform.takePartialStories(), isNull);
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });
  });

  group('I2 page-mode use counting', () {
    Future<_Rig> run(Failure f, {required bool opened}) async {
      final rig = _Rig();
      rig.page.pagesOpened = 0;
      rig.page.user = () {
        if (opened) rig.page.pagesOpened = rig.page.pagesOpened! + 1;
        return Err(f);
      };
      await rig.platform.resolveUser('someone');
      return rig;
    }

    test('RateLimited from a paused governor (no page opened) is surfaced '
        'but is not a use', () async {
      final rig = _Rig();
      rig.page.pagesOpened = 0;
      rig.page.user = () => const Err(RateLimited(Duration(minutes: 5)));
      final r = await rig.platform.resolveUser('someone');
      expect(r.failureOrNull, const RateLimited(Duration(minutes: 5)));
      expect(rig.platform.takeSignals().pageModeUses, 0);
    });

    test('a missing session (nothing loaded) is not a use', () async {
      final rig = await run(
        const SessionInvalid(SessionReason.loginRequired),
        opened: false,
      );
      expect(rig.platform.takeSignals().pageModeUses, 0);
    });

    test('the same failures after a page was opened ARE a use', () async {
      for (final f in <Failure>[
        const RateLimited(null),
        const SessionInvalid(SessionReason.loginRequired),
      ]) {
        final rig = await run(f, opened: true);
        expect(rig.platform.takeSignals().pageModeUses, 1, reason: '$f');
      }
    });

    test('PageOpenCounter counts every open of CountingPageDriver, also a '
        'failing one', () async {
      final counter = PageOpenCounter();
      final ok = CountingPageDriver(_Driver(fail: false), counter);
      final bad = CountingPageDriver(_Driver(fail: true), counter);
      unawaited(ok.open(_config));
      await expectLater(bad.open(_config), throwsStateError);
      expect(counter.opened, 2);
    });
  });

  group('F2 lease loss', () {
    late FakeClock clock;
    late FakeGovernorLeaseRepo repo;
    late _Repo wrapped;
    late FakeDiagnosticLog log;
    late void Function() tick;
    final ticks = <String, void Function()>{};

    setUp(() {
      clock = FakeClock();
      repo = FakeGovernorLeaseRepo(clock);
      wrapped = _Repo(repo);
      log = FakeDiagnosticLog();
    });

    GovernorWebViewLease make(String id, {GovernorLeaseRepo? over}) =>
        GovernorWebViewLease(
          repo: over ?? repo,
          clock: clock,
          instanceId: id,
          acquireTimeout: const Duration(milliseconds: 40),
          log: log,
          ticker: (_, cb) {
            tick = cb;
            ticks[id] = cb;
            return _NoTimer();
          },
        );

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('renewals failing for a full TTL are a loss: onLost fires once, '
        'isHeld is false at once, the owner is dropped', () async {
      final a = make('iso-a', over: wrapped);
      var lost = 0;
      a.onLost.listen((_) => lost++);
      expect(await a.tryAcquire('login'), isTrue);
      wrapped.failRenew = true;
      clock.advance(const Duration(seconds: 40));
      tick();
      await settle();
      expect(a.isHeld, isTrue, reason: 'one failure is inside the TTL');
      expect(lost, 0);
      clock.advance(const Duration(seconds: 80));
      tick();
      await settle();
      expect(lost, 1);
      expect(a.isHeld, isFalse);
      expect(a.owners, isEmpty);
      // The row expired, so a really new acquire works again.
      wrapped.failRenew = false;
      expect(await a.tryAcquire('login'), isTrue);
      expect(a.isHeld, isTrue);
    });

    test(
      'a healthy lease never fires onLost; a release does not either',
      () async {
        final a = make('iso-a');
        var lost = 0;
        a.onLost.listen((_) => lost++);
        await a.tryAcquire('login');
        for (var i = 0; i < 10; i++) {
          clock.advance(const Duration(seconds: 40));
          tick();
          await settle();
        }
        await a.release('login');
        await settle();
        expect(lost, 0);
      },
    );

    test('a stale owner after a loss does not block another owner in the '
        'isolate', () async {
      final a = make('iso-a');
      final b = make('iso-b');
      await a.tryAcquire('login');
      clock.advance(const Duration(minutes: 3));
      expect(await b.tryAcquire('page_mode:1'), isTrue);
      ticks['iso-a']!();
      await settle();
      expect(a.owners, isEmpty);
      await b.release('page_mode:1');
      expect(await a.tryAcquire('page_mode:1'), isTrue);
    });
  });

  group('F5 acquire race', () {
    test('two late answers: only the newest attempt may release', () async {
      final clock = FakeClock();
      final repo = FakeGovernorLeaseRepo(clock);
      final slow = _Repo(repo)..slow = true;
      final a = GovernorWebViewLease(
        repo: slow,
        clock: clock,
        instanceId: 'iso-a',
        acquireTimeout: const Duration(milliseconds: 30),
        ticker: (_, _) => _NoTimer(),
      );
      final b = GovernorWebViewLease(
        repo: repo,
        clock: clock,
        instanceId: 'iso-b',
        ticker: (_, _) => _NoTimer(),
      );
      expect(await a.tryAcquire('x'), isFalse); // attempt 1 times out
      expect(await a.tryAcquire('x'), isFalse); // attempt 2 times out
      slow.gates[0].complete(); // late answer of 1: not the newest, no release
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(await b.tryAcquire('y'), isFalse, reason: 'row still held');
      slow.gates[1].complete(); // late answer of 2: newest, nobody holds
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(await b.tryAcquire('y'), isTrue, reason: 'now released');
    });
  });

  group('F7 username overlay', () {
    test('EC-5: the overlay name is used while the row is unchanged', () async {
      final targets = FakeTargetRepo();
      await targets.insert(_target('u1', 'old_name'));
      final cache = TargetRepoUsernameCache(targets);
      await cache.remember('u1', 'new_name');
      expect(await cache.usernameOf('u1'), 'new_name');
      expect(await cache.usernameOf('u1'), 'new_name');
      expect(
        (await targets.getByRemoteUserId(PlatformId.instagram, 'u1'))!.username,
        'old_name',
      );
    });

    test(
      'once RunCheck records the rename in the row, the row is used',
      () async {
        final targets = FakeTargetRepo();
        final t = await targets.insert(_target('u1', 'old_name'));
        final cache = TargetRepoUsernameCache(targets);
        await cache.remember('u1', 'new_name');
        await targets.update(t.copyWith(username: 'new_name'));
        expect(await cache.usernameOf('u1'), 'new_name');
        // A later remember after that starts from the new row value.
        await cache.remember('u1', 'newer_name');
        expect(await cache.usernameOf('u1'), 'newer_name');
      },
    );

    test('a user that is not a target yet uses the overlay; when the target '
        'is added the row wins', () async {
      final targets = FakeTargetRepo();
      final cache = TargetRepoUsernameCache(targets);
      await cache.remember('u9', 'typed_name');
      expect(await cache.usernameOf('u9'), 'typed_name');
      await targets.insert(_target('u9', 'row_name'));
      expect(await cache.usernameOf('u9'), 'row_name');
    });

    test('a repo that throws: the overlay answers, no throw', () async {
      final cache = TargetRepoUsernameCache(_ThrowingTargets());
      await cache.remember('u1', 'kept_name');
      expect(await cache.usernameOf('u1'), 'kept_name');
      await expectLater(cache.usernameOf('other'), throwsStateError);
    });
  });

  group('F6 SeenGuard timeout', () {
    test('the default timeout is 3 s', () {
      expect(SeenGuard().refreshTimeout, const Duration(seconds: 3));
    });

    test('a hanging store stops a stories fallback before the first load '
        '(fail closed), the use is not counted', () async {
      final rig = _Rig(
        guard: SeenGuard(
          store: _Hang(),
          refreshTimeout: const Duration(milliseconds: 30),
        ),
      );
      // The real extractor refuses once the guard is tripped; the fake page
      // does the same.
      rig.page.stories = (_) => const Err(
        UnknownFailure(null, 'seen_guard_tripped'),
      );
      final r = await rig.stories(['u1']).timeout(const Duration(seconds: 2));
      expect(r.failureOrNull, _schema);
      expect(rig.platform.takeSignals().pageModeUses, 0);
    });
  });
}

final class _Hang implements SeenBreakerStore {
  @override
  Future<bool> isTripped() => Completer<bool>().future;
  @override
  Future<void> markTripped() async {}
  @override
  Future<void> clear() async {}
}

final class _ThrowingTargets implements TargetRepo {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('repo down');
}

const _config = PageSessionConfig(
  cookies: {},
  userAgent: 'ua',
  hookSource: '',
  handlerName: 'h',
  allowedOrigins: {},
);

final class _Driver implements PageDriver {
  _Driver({required this.fail});
  final bool fail;
  @override
  Future<PageSession> open(PageSessionConfig config) =>
      fail ? throw StateError('no') : Completer<PageSession>().future;
}

final class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}

/// A lease repo whose renewals can fail and whose `acquire` answers can be
/// withheld until a gate opens (the work is done at once).
final class _Repo implements GovernorLeaseRepo {
  _Repo(this.inner);
  final GovernorLeaseRepo inner;
  bool failRenew = false;
  bool slow = false;
  final gates = <Completer<void>>[];

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
    if (failRenew) throw StateError('renew down ZZFAKE');
    return inner.renew(accountId: accountId, holder: holder, ttl: ttl);
  }

  @override
  Future<GovernorLease?> read(int accountId) => inner.read(accountId);

  @override
  Future<void> release({required int accountId, required String holder}) =>
      inner.release(accountId: accountId, holder: holder);

  @override
  Future<bool> writeBucket({
    required int accountId,
    required String holder,
    required GovernorBucket bucket,
  }) => inner.writeBucket(accountId: accountId, holder: holder, bucket: bucket);
}
