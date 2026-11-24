// QA (T-015): adversarial checks of the mode selection of InstagramPlatform:
// every failure x every method x every policy, masking of the session problem,
// EC-14 reachability, PAGE_MODE_USED counted exactly once, and the stories
// loop. Tests marked "PIN" record a behaviour QA reports as a finding; they
// must be changed together with the fix.
// ignore_for_file: unnecessary_ignore, unnecessary_string_interpolations,
// ignore_for_file: unnecessary_parenthesis, prefer_const_constructors,
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports, port not in the barrel yet.
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _schema = SchemaChanged('doc_id:ZZFAKE');
final _wm = DateTime.utc(2026);

/// Every concrete failure the map knows, one value of each kind.
final Map<String, Failure> _allFailures = {
  'NetworkFailure': const NetworkFailure(),
  'RateLimited': const RateLimited(Duration(minutes: 1)),
  'RateLimited(null)': const RateLimited(null),
  'SessionInvalid(login)': const SessionInvalid(SessionReason.loginRequired),
  'SessionInvalid(challenge)': const SessionInvalid(SessionReason.challenge),
  'AccountRestricted': const AccountRestricted(),
  'TargetNotFound': const TargetNotFound(),
  'TargetNotVisible': const TargetNotVisible(),
  'SchemaChanged': _schema,
  'Unknown(500)': const UnknownFailure(500, 'http_500'),
  'Unknown(null,x)': const UnknownFailure(null, 'x'),
  // Page-mode reasons coming from DIRECT mode must be treated like any
  // direct failure.
  'Unknown(seen_guard_tripped)': const UnknownFailure(
    null,
    'seen_guard_tripped',
  ),
  'Unknown(username_unknown)': const UnknownFailure(null, 'username_unknown'),
};

class _Rig {
  _Rig({
    this.lookupPolicy = ExtractionPolicy.directThenPage,
    bool withActivity = false,
    SeenGuard? guard,
  }) {
    activity = FakeActivityRepo(clock);
    platform = InstagramPlatform(
      direct: direct,
      page: page,
      media: CdnMediaOpener(http: FakeCdnHttp((_, _) => throw StateError('x'))),
      seenGuard: guard ?? SeenGuard(),
      log: log,
      activity: withActivity ? activity : null,
      clock: clock,
      lookupPolicy: lookupPolicy,
    );
  }

  final ExtractionPolicy lookupPolicy;
  final List<String> calls = [];
  late final FakeMode direct = FakeMode('direct', calls);
  late final FakeMode page = FakeMode('page', calls);
  final FakeDiagnosticLog log = FakeDiagnosticLog();
  final FakeClock clock = FakeClock();
  late final FakeActivityRepo activity;
  late final InstagramPlatform platform;

  void directFails(Failure f) {
    direct
      ..user = (() => Err(f))
      ..verify = (() => Err(f))
      ..stories = ((_) => Err(f))
      ..posts = (() => Err(f))
      ..latest = (() => Err(f));
  }

  void pageFails(Failure f) {
    page
      ..user = (() => Err(f))
      ..stories = ((_) => Err(f))
      ..posts = (() => Err(f))
      ..latest = (() => Err(f));
  }

  bool get pageRan => calls.any((c) => c.startsWith('page.'));

  /// Each method as a thunk, so a test can run one at a time.
  Map<String, Future<Result<Object?>> Function()> methods(ExtractionPolicy p) =>
      {
        'resolveUser': () => platform.resolveUser('x'),
        'refreshUser': () => platform.refreshUser('1', 'x'),
        'fetchStories': () => platform.fetchStories(['1'], policy: p),
        'fetchNewPosts': () => platform.fetchNewPosts('1', _wm, policy: p),
        'latestPostTime': () => platform.latestPostTime('1'),
      };
}

void main() {
  group('mode matrix: failure x method x policy', () {
    for (final policy in ExtractionPolicy.values) {
      for (final MapEntry(key: name, value: failure) in _allFailures.entries) {
        test('direct fails with $name, policy $policy', () async {
          final rig = _Rig(lookupPolicy: policy)..directFails(failure);
          final isSchema = failure is SchemaChanged;
          final mayFallBack =
              isSchema && policy == ExtractionPolicy.directThenPage;
          for (final MapEntry(key: method, value: call)
              in rig.methods(policy).entries) {
            rig.calls.clear();
            rig.platform.takeSignals();
            rig.pageFails(const SessionInvalid(SessionReason.loginRequired));
            final r = await call();
            final failureOut = r.failureOrNull;
            if (mayFallBack) {
              expect(rig.calls, ['direct.$method', 'page.$method']);
              expect(failureOut, isA<SessionInvalid>(), reason: method);
              expect(rig.platform.takeSignals().pageModeUses, 1);
            } else {
              // direct only, the direct failure is returned untouched.
              expect(rig.calls, ['direct.$method'], reason: '$name $method');
              expect(failureOut, failure, reason: '$name $method');
              expect(rig.platform.takeSignals().pageModeUses, 0);
            }
          }
          if (!mayFallBack) {
            expect(logText(rig.log), isNot(contains('PAGE_MODE_USED')));
          }
          // verifySession is direct only, whatever the failure and policy.
          rig.calls.clear();
          final v = await rig.platform.verifySession();
          expect(rig.calls, ['direct.verifySession']);
          expect(v.failureOrNull, failure);
        });
      }
    }

    test('an Ok from direct mode never reaches page mode', () async {
      final rig = _Rig();
      for (final call in rig.methods(ExtractionPolicy.directThenPage).values) {
        expect((await call()).isOk, isTrue);
      }
      expect(rig.pageRan, isFalse);
    });

    test('a THROWING direct mode (a bug) is UnknownFailure, no page mode, '
        'no leak of the error text', () async {
      final rig = _Rig()
        ..direct.throwWith = Exception('https://secret.example/ZZFAKE');
      for (final call in rig.methods(ExtractionPolicy.directThenPage).values) {
        final r = await call();
        expect(r.failureOrNull, isA<UnknownFailure>());
        expect('${r.failureOrNull}', isNot(contains('ZZFAKE')));
      }
      expect(rig.pageRan, isFalse);
      expect(logText(rig.log), isNot(contains('ZZFAKE')));
    });
  });

  group('SchemaChanged -> page mode -> any other failure', () {
    final pageFailures = {
      'SessionInvalid(login)': const SessionInvalid(
        SessionReason.loginRequired,
      ),
      'SessionInvalid(challenge)': const SessionInvalid(
        SessionReason.challenge,
      ),
      'RateLimited': const RateLimited(Duration(minutes: 3)),
      'AccountRestricted': const AccountRestricted(),
      'NetworkFailure': const NetworkFailure(),
      'TargetNotFound': const TargetNotFound(),
      'TargetNotVisible': const TargetNotVisible(),
      'SchemaChanged(page)': const SchemaChanged('page_timeout'),
      'seen_block_leak': const UnknownFailure(null, 'seen_block_leak'),
      'unexpected_error': const UnknownFailure(null, 'unexpected_error'),
    };
    for (final MapEntry(key: name, value: failure) in pageFailures.entries) {
      test('page mode returns $name: surfaced as is on every method, counted '
          'as a use', () async {
        for (final entry in _Rig(
          withActivity: true,
        ).methods(ExtractionPolicy.directThenPage).keys) {
          final rig = _Rig(withActivity: true)
            ..directFails(_schema)
            ..pageFails(failure);
          final r = await rig
              .methods(ExtractionPolicy.directThenPage)[entry]!
              .call();
          expect(r.failureOrNull, failure, reason: '$name via $entry');
          expect(rig.platform.takeSignals().pageModeUses, 1);
        }
      });
    }

    test('the direct SchemaChanged detail does not hide a page-mode '
        'SessionInvalid, and the page SessionInvalid is not downgraded by '
        'verifySession ordering', () async {
      final rig = _Rig()
        ..directFails(const SchemaChanged('doc_id:AAA'))
        ..pageFails(const SessionInvalid(SessionReason.loginRequired));
      final r = await rig.platform.fetchNewPosts(
        '1',
        _wm,
        policy: ExtractionPolicy.directThenPage,
      );
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      // Whole sequence stays free of an UnknownFailure or a SchemaChanged.
      expect('${r.failureOrNull}', isNot(contains('doc_id')));
    });
  });

  group('EC-14 stays reachable when page mode did not run', () {
    const reasons = [
      'page_mode_background_disabled',
      'seen_guard_tripped',
      'username_unknown',
    ];
    for (final reason in reasons) {
      test('$reason on every method returns the DIRECT SchemaChanged with its '
          'detail', () async {
        final rig0 = _Rig();
        for (final entry
            in rig0.methods(ExtractionPolicy.directThenPage).keys) {
          final rig = _Rig()
            ..directFails(const SchemaChanged('doc_id:DETAIL'))
            ..pageFails(UnknownFailure(null, reason));
          final r = await rig
              .methods(ExtractionPolicy.directThenPage)[entry]!
              .call();
          expect(r.failureOrNull, const SchemaChanged('doc_id:DETAIL'));
          expect(rig.platform.takeSignals().pageModeUses, 0);
        }
      });
    }

    test('a reason with a CODE is not "did not run": it is a real failure '
        '(no spoofing by status codes)', () async {
      final rig = _Rig()
        ..directFails(_schema)
        ..pageFails(const UnknownFailure(403, 'seen_guard_tripped'));
      final r = await rig.platform.resolveUser('x');
      expect(r.failureOrNull, const UnknownFailure(403, 'seen_guard_tripped'));
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });

    test('busy page mode is NetworkFailure, never RateLimited or '
        'SchemaChanged, and is not a use', () async {
      for (final busy in ['webview_busy', 'governor_busy']) {
        final rig0 = _Rig();
        for (final entry
            in rig0.methods(ExtractionPolicy.directThenPage).keys) {
          final rig = _Rig()
            ..directFails(_schema)
            ..pageFails(UnknownFailure(null, busy));
          final r = await rig
              .methods(ExtractionPolicy.directThenPage)[entry]!
              .call();
          expect(r.failureOrNull, const NetworkFailure(), reason: '$busy');
          expect(rig.platform.takeSignals().pageModeUses, 0);
        }
      }
    });
  });

  group('PAGE_MODE_USED exactly once per fallback', () {
    test(
      'one log line, one signal and one activity event per method',
      () async {
        final rig0 = _Rig();
        for (final entry
            in rig0.methods(ExtractionPolicy.directThenPage).keys) {
          final rig = _Rig(withActivity: true)..directFails(_schema);
          await rig.methods(ExtractionPolicy.directThenPage)[entry]!.call();
          final lines = logText(rig.log)
              .split('\n')
              .where((l) => l.contains('PAGE_MODE_USED'))
              .toList();
          expect(lines, hasLength(1), reason: entry);
          expect(lines.single, contains('op=$entry'));
          expect(rig.platform.takeSignals().pageModeUses, 1);
          final events = await rig.activity.watchRecent().first;
          expect(events, hasLength(1), reason: entry);
          expect(events.single.type, ActivityType.pageModeUsed);
        }
      },
    );

    test(
      'a 25-user stories fallback is ONE use, not one per page load',
      () async {
        final rig = _Rig(withActivity: true)..directFails(_schema);
        final ids = [for (var i = 0; i < 25; i++) 'u$i'];
        await rig.platform.fetchStories(
          ids,
          policy: ExtractionPolicy.directThenPage,
        );
        expect(rig.calls.where((c) => c == 'page.fetchStories'), hasLength(25));
        expect(rig.platform.takeSignals().pageModeUses, 1);
        expect((await rig.activity.watchRecent().first), hasLength(1));
      },
    );

    test('takeSignals is read-and-reset: a second take is zero', () async {
      final rig = _Rig()..directFails(_schema);
      await rig.platform.resolveUser('x');
      expect(rig.platform.takeSignals().pageModeUses, 1);
      expect(rig.platform.takeSignals().pageModeUses, 0);
    });

    test('an activity repo that throws still counts one use and returns the '
        'page result', () async {
      final rig = _Rig(withActivity: true)..directFails(_schema);
      // FakeActivityRepo accepts everything; use a throwing stand-in.
      final throwing = InstagramPlatform(
        direct: rig.direct,
        page: rig.page,
        media: CdnMediaOpener(
          http: FakeCdnHttp((_, _) => throw StateError('x')),
        ),
        seenGuard: SeenGuard(),
        log: rig.log,
        activity: _ThrowingActivity(),
      );
      final r = await throwing.resolveUser('x');
      expect(r.isOk, isTrue);
      expect(throwing.takeSignals().pageModeUses, 1);
      expect(logText(rig.log), isNot(contains('ZZFAKE')));
    });
  });

  group('stories loop (one page load per user)', () {
    test('FIXED (QA-T015-F1): user 1 loads, user 2 is username_unknown -> the '
        'platform reports the direct SchemaChanged, counts the page mode use '
        'once (one page was loaded) and keeps what was loaded', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page.stories = (ids) => ids.single == 'u1'
          ? Ok({'u1': const <RemoteContent>[]})
          : const Err(UnknownFailure(null, 'username_unknown'));
      final r = await rig.platform.fetchStories([
        'u1',
        'u2',
      ], policy: ExtractionPolicy.directThenPage);
      expect(rig.calls.where((c) => c == 'page.fetchStories'), hasLength(2));
      expect(rig.platform.takeSignals().pageModeUses, 1);
      expect(r.failureOrNull, _schema);
      final partial = rig.platform.takePartialStories()!;
      expect(partial.loaded.keys, ['u1']);
      expect(partial.skipped, 1);
    });

    test('FIXED (QA-T015-F1): same for a breaker that trips (other isolate) '
        'between two users: page 1 loaded, the use is counted', () async {
      final store = CountingSeenStore();
      final rig = _Rig(guard: SeenGuard(store: store))..directFails(_schema);
      rig.page.stories = (ids) {
        // The other isolate trips the breaker while u1 loads.
        store.value = true;
        return ids.single == 'u1'
            ? Ok({'u1': const <RemoteContent>[]})
            : const Err(UnknownFailure(null, 'seen_guard_tripped'));
      };
      // The platform itself reads the breaker before each user; user 2 is
      // refused inside the platform loop only if the fake page honours it.
      final r = await rig.platform.fetchStories([
        'u1',
        'u2',
      ], policy: ExtractionPolicy.directThenPage);
      expect(r.failureOrNull, _schema);
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });

    test(
      'an empty and a blank id list loads nothing and is an empty Ok',
      () async {
        final rig = _Rig()..directFails(_schema);
        final r = await rig.platform.fetchStories([
          '',
          '  ',
        ], policy: ExtractionPolicy.directThenPage);
        // Direct says SchemaChanged first; page loop has nothing to load.
        expect(rig.calls.where((c) => c == 'page.fetchStories'), isEmpty);
        expect(r.isOk, isTrue);
      },
    );

    test('duplicate ids are loaded once', () async {
      final rig = _Rig()..directFails(_schema);
      await rig.platform.fetchStories([
        'u1',
        ' u1 ',
        'u1',
      ], policy: ExtractionPolicy.directThenPage);
      expect(rig.calls.where((c) => c == 'page.fetchStories'), hasLength(1));
    });
  });

  group('ContentSignals contract', () {
    test('the platform is a ContentSignals and exposes only counters', () {
      final p = _Rig().platform;
      expect(p, isA<ContentSignals>());
      final s = p.takeSignals();
      expect(s.toString(), isNot(contains('http')));
    });
  });
}

final class _ThrowingActivity implements ActivityRepo {
  @override
  Stream<List<ActivityEvent>> watchRecent({
    Set<ActivityType> types = const {},
  }) => const Stream.empty();

  @override
  Future<ActivityEvent> add(ActivityEvent event) async =>
      throw StateError('https://secret.example/ZZFAKE');

  @override
  Future<int> pruneOlderThan(DateTime cutoff) async => 0;
}
