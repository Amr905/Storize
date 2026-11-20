// T-015 AC1, AC2, AC4, AC5 (+ the failure map and governor_busy): the mode
// selection of InstagramPlatform, tested with fake extraction modes.
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_instagram/instagram_platform.dart';
import 'package:storize_instagram/media/media.dart';
import 'package:storize_instagram/page/page.dart';
import 'package:storize_model/storize_model.dart';

import 'support.dart';

const _schema = SchemaChanged('doc_id:ZZFAKE');

final _watermark = DateTime.utc(2026);

class _Rig {
  _Rig({
    this.lookupPolicy = ExtractionPolicy.directThenPage,
    bool withActivity = false,
    SeenGuard? seenGuard,
  }) {
    activity = FakeActivityRepo(clock);
    platform = InstagramPlatform(
      direct: direct,
      page: page,
      media: CdnMediaOpener(http: FakeCdnHttp((_, _) => throw StateError('x'))),
      seenGuard: seenGuard ?? SeenGuard(),
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

  /// Makes direct mode fail with [failure] on every method.
  void directFails(Failure failure) {
    direct
      ..user = (() => Err(failure))
      ..verify = (() => Err(failure))
      ..stories = ((_) => Err(failure))
      ..posts = (() => Err(failure))
      ..latest = (() => Err(failure));
  }

  Future<Map<String, Result<Object?>>> allMethods(ExtractionPolicy p) async => {
    'resolveUser': await platform.resolveUser('x'),
    'refreshUser': await platform.refreshUser('1', 'x'),
    'fetchStories': await platform.fetchStories(['1'], policy: p),
    'fetchNewPosts': await platform.fetchNewPosts('1', _watermark, policy: p),
    'latestPostTime': await platform.latestPostTime('1'),
  };
}

void main() {
  group('AC1 implements ContentPlatform', () {
    test('is a ContentPlatform for Instagram', () {
      final ContentPlatform platform = _Rig().platform;
      expect(platform.id, PlatformId.instagram);
    });

    test('with Ok from direct, every method returns it and page mode is '
        'never touched', () async {
      final rig = _Rig();
      final out = await rig.allMethods(ExtractionPolicy.directThenPage);
      expect(out.values.every((r) => r.isOk), isTrue);
      expect(rig.calls.every((c) => c.startsWith('direct.')), isTrue);
      expect(rig.calls, hasLength(5));
      expect(rig.platform.takeSignals().pageModeUses, 0);
      expect(logText(rig.log), isNot(contains('PAGE_MODE_USED')));
    });

    test('verifySession goes to direct mode only', () async {
      final rig = _Rig();
      expect((await rig.platform.verifySession()).isOk, isTrue);
      expect(rig.calls, ['direct.verifySession']);
    });
  });

  group('AC2 directThenPage: page mode only after SchemaChanged', () {
    test('SchemaChanged: page mode answers for every method, one '
        'PAGE_MODE_USED each', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page
        ..user = (() => Ok(aUser('from_page')))
        ..posts = (() => const Ok([]))
        ..latest = (() => Ok(DateTime.utc(2026, 2)))
        ..stories = ((_) => const Ok({}));
      final out = await rig.allMethods(ExtractionPolicy.directThenPage);
      expect(out.values.every((r) => r.isOk), isTrue);
      expect(rig.calls, [
        for (final m in [
          'resolveUser',
          'refreshUser',
          'fetchStories',
          'fetchNewPosts',
          'latestPostTime',
        ]) ...['direct.$m', 'page.$m'],
      ]);
      final uses = rig.log.entries
          .where((e) => e.message.startsWith('PAGE_MODE_USED'))
          .toList();
      expect(uses, hasLength(5));
      expect(rig.platform.takeSignals().pageModeUses, 5);
    });

    test(
      'directOnly: SchemaChanged is returned, page mode is not called',
      () async {
        final rig = _Rig()..directFails(_schema);
        final r = await rig.platform.fetchNewPosts(
          '1',
          _watermark,
          policy: ExtractionPolicy.directOnly,
        );
        final s = await rig.platform.fetchStories([
          '1',
        ], policy: ExtractionPolicy.directOnly);
        expect(r.failureOrNull, _schema);
        expect(s.failureOrNull, _schema);
        expect(rig.calls.any((c) => c.startsWith('page.')), isFalse);
        expect(logText(rig.log), isNot(contains('PAGE_MODE_USED')));
      },
    );

    test(
      'lookupPolicy directOnly applies to the methods without a policy',
      () async {
        final rig = _Rig(lookupPolicy: ExtractionPolicy.directOnly)
          ..directFails(_schema);
        expect((await rig.platform.resolveUser('x')).failureOrNull, _schema);
        expect(
          (await rig.platform.refreshUser('1', 'x')).failureOrNull,
          _schema,
        );
        expect((await rig.platform.latestPostTime('1')).failureOrNull, _schema);
        expect(rig.calls.any((c) => c.startsWith('page.')), isFalse);
      },
    );

    final never = <String, Failure>{
      'SessionInvalid(loginRequired)': const SessionInvalid(
        SessionReason.loginRequired,
      ),
      'SessionInvalid(challenge)': const SessionInvalid(
        SessionReason.challenge,
      ),
      'RateLimited': const RateLimited(Duration(minutes: 5)),
      'RateLimited(no hint)': const RateLimited(null),
      'AccountRestricted': const AccountRestricted(),
      'NetworkFailure': const NetworkFailure(),
      'TargetNotFound': const TargetNotFound(),
      'TargetNotVisible': const TargetNotVisible(),
      'UnknownFailure': const UnknownFailure(500, 'http_500'),
    };
    for (final MapEntry(key: name, value: failure) in never.entries) {
      test('never page mode after $name, on any method', () async {
        final rig = _Rig()..directFails(failure);
        final out = await rig.allMethods(ExtractionPolicy.directThenPage);
        expect(out.values.map((r) => r.failureOrNull), everyElement(failure));
        expect(rig.calls.any((c) => c.startsWith('page.')), isFalse);
        expect(rig.platform.takeSignals().pageModeUses, 0);
        expect(logText(rig.log), isNot(contains('PAGE_MODE_USED')));
      });
    }

    test('page mode failing with its own failure: that failure is returned, '
        'and the use is logged', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page.posts = () =>
          const Err(SessionInvalid(SessionReason.loginRequired));
      final r = await rig.platform.fetchNewPosts(
        '1',
        _watermark,
        policy: ExtractionPolicy.directThenPage,
      );
      expect(
        r.failureOrNull,
        const SessionInvalid(SessionReason.loginRequired),
      );
      expect(rig.platform.takeSignals().pageModeUses, 1);
    });

    test(
      'both modes SchemaChanged: the page SchemaChanged (EC-14 input)',
      () async {
        final rig = _Rig()..directFails(_schema);
        rig.page.posts = () => const Err(SchemaChanged('page_timeout'));
        final r = await rig.platform.fetchNewPosts(
          '1',
          _watermark,
          policy: ExtractionPolicy.directThenPage,
        );
        expect(r.failureOrNull, const SchemaChanged('page_timeout'));
      },
    );

    for (final reason in [
      'page_mode_background_disabled',
      'seen_guard_tripped',
      'username_unknown',
    ]) {
      test('page mode not run ($reason): the direct SchemaChanged is returned, '
          'nothing is counted as a use', () async {
        final rig = _Rig()..directFails(_schema);
        rig.page.posts = () => Err(UnknownFailure(null, reason));
        final r = await rig.platform.fetchNewPosts(
          '1',
          _watermark,
          policy: ExtractionPolicy.directThenPage,
        );
        expect(r.failureOrNull, _schema);
        expect(rig.platform.takeSignals().pageModeUses, 0);
        expect(logText(rig.log), isNot(contains('PAGE_MODE_USED')));
        expect(logText(rig.log), contains('page_mode_skipped reason=$reason'));
      });
    }

    test('verifySession never falls back, even on SchemaChanged', () async {
      final rig = _Rig()..directFails(_schema);
      final r = await rig.platform.verifySession();
      expect(r.failureOrNull, _schema);
      expect(rig.calls, ['direct.verifySession']);
    });
  });

  group('governor_busy / webview_busy are retry-later (NetworkFailure)', () {
    test('governor_busy from direct mode', () async {
      final rig = _Rig()
        ..directFails(const UnknownFailure(null, 'governor_busy'));
      final out = await rig.allMethods(ExtractionPolicy.directThenPage);
      expect(
        out.values.map((r) => r.failureOrNull),
        everyElement(const NetworkFailure()),
      );
      expect(rig.calls.any((c) => c.startsWith('page.')), isFalse);
      expect(
        (await rig.platform.verifySession()).failureOrNull,
        const NetworkFailure(),
      );
    });

    test('webview_busy after SchemaChanged (login WebView open)', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page.posts = () => const Err(UnknownFailure(null, 'webview_busy'));
      final r = await rig.platform.fetchNewPosts(
        '1',
        _watermark,
        policy: ExtractionPolicy.directThenPage,
      );
      expect(r.failureOrNull, const NetworkFailure());
      expect(rig.platform.takeSignals().pageModeUses, 0);
    });

    test('other UnknownFailure codes are passed through unchanged', () async {
      final rig = _Rig()
        ..directFails(const UnknownFailure(null, 'username_mismatch'));
      expect(
        (await rig.platform.resolveUser('x')).failureOrNull,
        const UnknownFailure(null, 'username_mismatch'),
      );
    });
  });

  group('AC4 PAGE_MODE_USED is logged without values', () {
    test('diagnostic line has the operation only', () async {
      final rig = _Rig()
        ..directFails(const SchemaChanged('where:zz_secret_name'));
      rig.page.user = () => Ok(aUser());
      await rig.platform.resolveUser(secretName);
      final text = logText(rig.log);
      expect(text, contains('PAGE_MODE_USED op=resolveUser'));
      expect(text, isNot(contains(secretName)));
      expect(text, isNot(contains('where')));
      expect(text, isNot(contains('http')));
    });

    test('with an ActivityRepo: one pageModeUsed event, payload op only, '
        'no target', () async {
      final rig = _Rig(withActivity: true)..directFails(_schema);
      rig.page.posts = () => const Ok([]);
      await rig.platform.fetchNewPosts(
        '1',
        _watermark,
        policy: ExtractionPolicy.directThenPage,
      );
      final events = await rig.activity.watchRecent().first;
      expect(events, hasLength(1));
      expect(events.single.type, ActivityType.pageModeUsed);
      expect(events.single.severity, Severity.info);
      expect(events.single.payload, {'op': 'fetchNewPosts'});
      expect(events.single.targetId, isNull);
      expect(events.single.at, rig.clock.now());
    });

    test('a failing ActivityRepo does not fail the operation', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page.posts = () => const Ok([]);
      final platform = InstagramPlatform(
        direct: rig.direct,
        page: rig.page,
        media: CdnMediaOpener(
          http: FakeCdnHttp((_, _) => throw StateError('x')),
        ),
        seenGuard: SeenGuard(),
        log: rig.log,
        activity: _ThrowingActivity(),
      );
      final r = await platform.fetchNewPosts(
        '1',
        _watermark,
        policy: ExtractionPolicy.directThenPage,
      );
      expect(r.isOk, isTrue);
      expect(logText(rig.log), contains('activity_write_failed'));
      expect(logText(rig.log), isNot(contains('ZZFAKE')));
    });
  });

  group('robustness', () {
    test('a mode that throws becomes UnknownFailure, with only the type '
        'logged', () async {
      final rig = _Rig();
      rig.direct.throwWith = Exception('boom $secretName');
      final r = await rig.platform.resolveUser('x');
      expect(r.failureOrNull, const UnknownFailure(null, 'unexpected_error'));
      expect(logText(rig.log), contains('_Exception'));
      expect(logText(rig.log), isNot(contains(secretName)));
    });

    test('a page mode that throws after SchemaChanged is an '
        'unexpected_error', () async {
      final rig = _Rig()..directFails(_schema);
      rig.page.throwWith = Exception('boom');
      final r = await rig.platform.latestPostTime('1');
      expect(r.failureOrNull, const UnknownFailure(null, 'unexpected_error'));
    });
  });

  group('R2-F5 the seen breaker is read before each page-mode story load', () {
    test('one read per user, trip stops the next load, SchemaChanged is the '
        'answer', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store);
      final rig = _Rig(seenGuard: guard)..directFails(_schema);
      var loads = 0;
      rig.page.stories = (ids) {
        loads++;
        // The extractor's own behaviour: refuse when the guard has tripped.
        if (guard.tripped) {
          return const Err(UnknownFailure(null, 'seen_guard_tripped'));
        }
        // After the first user the other isolate trips the persisted breaker.
        store.value = true;
        return const Ok({});
      };
      final r = await rig.platform.fetchStories([
        'a',
        'b',
        'c',
      ], policy: ExtractionPolicy.directThenPage);
      expect(store.reads, 2, reason: 'a: not tripped; b: tripped, stop');
      expect(loads, 2);
      expect(r.failureOrNull, _schema);
      expect(guard.tripped, isTrue);
    });

    test('a healthy store: one page load per user, results merged', () async {
      final store = CountingSeenStore();
      final rig = _Rig(seenGuard: SeenGuard(store: store))
        ..directFails(_schema);
      rig.page.stories = (ids) => Ok({
        ids.single: [
          RemoteContent(
            remoteId: 'm_${ids.single}',
            kind: ContentKind.story,
            postedAt: DateTime.utc(2026),
            slides: const [],
          ),
        ],
      });
      final r = await rig.platform.fetchStories([
        'a',
        ' b ',
        'a',
        '',
      ], policy: ExtractionPolicy.directThenPage);
      expect(r.valueOrNull!.keys, ['a', 'b']);
      expect(store.reads, 2);
      expect(rig.calls.where((c) => c == 'page.fetchStories'), hasLength(2));
    });

    test('a trip during the loop is flushed to the store before the call '
        'returns', () async {
      final store = CountingSeenStore();
      final guard = SeenGuard(store: store);
      final rig = _Rig(seenGuard: guard)..directFails(_schema);
      rig.page.stories = (ids) {
        guard.trip();
        return const Err(UnknownFailure(null, 'seen_block_leak'));
      };
      final r = await rig.platform.fetchStories([
        'a',
      ], policy: ExtractionPolicy.directThenPage);
      expect(r.failureOrNull, const UnknownFailure(null, 'seen_block_leak'));
      expect(store.writes, 1, reason: 'written before the call returned');
      expect(store.value, isTrue);
    });
  });
}

final class _ThrowingActivity implements ActivityRepo {
  @override
  Future<ActivityEvent> add(ActivityEvent event) =>
      throw StateError('db down ZZFAKE');

  @override
  Future<int> pruneOlderThan(DateTime cutoff) async => 0;

  @override
  Stream<List<ActivityEvent>> watchRecent({
    Set<ActivityType> types = const {},
  }) => const Stream.empty();
}
