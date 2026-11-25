// Const literals add noise to test data.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  group('Target', () {
    test('equal values are equal and share a hash code', () {
      final a = target(id: 1);
      final b = target(id: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(target(id: 2)));
    });

    test('copyWith changes fields and can clear nullable ones', () {
      final a = target(id: 1, lastStoriesCheckAt: t0);
      final b = a.copyWith(
        username: 'bob',
        status: TargetStatus.paused,
        lastStoriesCheckAt: null,
        note: 'hi',
      );
      expect(b.username, 'bob');
      expect(b.status, TargetStatus.paused);
      expect(b.lastStoriesCheckAt, isNull);
      expect(b.note, 'hi');
      expect(b.remoteUserId, a.remoteUserId);
      expect(a.copyWith(), a);
    });

    test('rejects all track flags off', () {
      expect(
        () => target(trackStories: false, trackPosts: false, trackReels: false),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Content', () {
    test('equality includes extras by value', () {
      final a = Content(
        id: 1,
        targetId: 1,
        kind: ContentKind.post,
        remoteId: 'x',
        postedAt: t0,
        slideCount: 1,
        detectedAt: t0,
        extras: {
          'tags': ['a'],
        },
      );
      final b = a.copyWith(
        extras: {
          'tags': ['a'],
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(viewed: true)));
    });

    test('extras are unmodifiable and toString hides the caption', () {
      final c = Content(
        id: 1,
        targetId: 1,
        kind: ContentKind.post,
        remoteId: 'x',
        postedAt: t0,
        slideCount: 1,
        detectedAt: t0,
        caption: 'secret words',
        extras: {'a': 1},
      );
      expect(() => c.extras['b'] = 2, throwsUnsupportedError);
      expect(c.toString(), isNot(contains('secret')));
    });

    test('copyWith keeps the identity key', () {
      final c = content(targetId: 3)
          .copyWith(status: ContentStatus.done, shortcode: 'abc');
      expect(c.targetId, 3);
      expect(c.remoteId, 'r1');
      expect(c.status, ContentStatus.done);
      expect(c.shortcode, 'abc');
    });
  });

  group('MediaFile', () {
    test('equality, copyWith and redacted toString', () {
      final a = media();
      expect(a, media());
      final b = a.copyWith(
        status: MediaFileStatus.done,
        attempts: 2,
        contentUri: 'content://x',
        sizeBytes: 10,
      );
      expect(b.status, MediaFileStatus.done);
      expect(b.attempts, 2);
      expect(b.contentUri, 'content://x');
      expect(b.copyWith(contentUri: null).contentUri, isNull);
      expect(a, isNot(b));
      expect(a.toString(), isNot(contains('example.invalid')));
    });
  });

  group('LoginAccount', () {
    test('equality and copyWith', () {
      final a = LoginAccount(
        id: 1,
        platform: PlatformId.instagram,
        remoteUserId: '9',
        username: 'me',
        status: AccountStatus.active,
        connectedAt: t0,
      );
      final b = a.copyWith(
        status: AccountStatus.needsRelogin,
        statusReason: 'expired',
      );
      expect(b.status, AccountStatus.needsRelogin);
      expect(b.statusReason, 'expired');
      expect(a.copyWith(), a);
      expect(a.hashCode, a.copyWith().hashCode);
      expect(a, isNot(b));
    });
  });

  group('CheckRun', () {
    test('rejects scope ALL, equality, copyWith', () {
      expect(
        () => CheckRun(
          id: 1,
          scope: CheckScope.all,
          trigger: CheckTrigger.periodic,
          startedAt: t0,
        ),
        throwsA(isA<AssertionError>()),
      );
      final run = CheckRun(
        id: 1,
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: t0,
      );
      expect(run.isFinished, isFalse);
      final done = run.copyWith(
        finishedAt: t0,
        result: CheckResult.ok,
        newItems: 2,
      );
      expect(done.isFinished, isTrue);
      expect(done, isNot(run));
      expect(done.copyWith(), done);
      expect(done.hashCode, done.copyWith().hashCode);
    });
  });

  group('ActivityEvent', () {
    test('equality compares payload by value; copyWith', () {
      final a = ActivityEvent(
        id: 1,
        at: t0,
        type: ActivityType.gap,
        payload: {
          'n': [1],
        },
      );
      final b = a.copyWith(
        payload: {
          'n': [1],
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(count: 5).count, 5);
      expect(a.copyWith(targetId: 3).targetId, 3);
      expect(a, isNot(a.copyWith(severity: Severity.error)));
    });
  });

  group('GovernorLease', () {
    test('equality, copyWith and isHeldAt', () {
      final bucket = GovernorBucket(tokens: 3, lastRefillAt: t0);
      final lease = GovernorLease(
        loginAccountId: 1,
        holder: 'ui',
        expiresAt: t0.add(const Duration(minutes: 1)),
        bucket: bucket,
      );
      expect(lease.isHeldAt(t0), isTrue);
      expect(lease.isHeldAt(lease.expiresAt), isFalse);
      expect(lease.copyWith(), lease);
      expect(lease.hashCode, lease.copyWith().hashCode);
      expect(lease.copyWith(holder: 'bg'), isNot(lease));
      expect(bucket, GovernorBucket(tokens: 3, lastRefillAt: t0));
    });
  });

  group('AppSettings', () {
    test('defaults match TECH_SPEC section 3', () {
      const s = AppSettings();
      expect(s.storyIntervalMin, 30);
      expect(s.postIntervalMin, 180);
      expect(s.wifiOnly, isFalse);
      expect(s.notifyStories && s.notifyPosts && s.notifyLogin, isTrue);
      expect(s.retentionDays, isNull);
      expect(s.pageModeInBackground, isFalse);
      expect(s.isValid, isTrue);
    });

    test('allowed sets match the spec', () {
      expect(AppSettings.storyIntervalOptions, {15, 30, 60, 120, 180, 360});
      expect(AppSettings.postIntervalOptions, {60, 120, 180, 360, 720, 1440});
    });

    test('validation flags bad intervals and retention', () {
      expect(const AppSettings(storyIntervalMin: 10).isValid, isFalse);
      expect(const AppSettings(postIntervalMin: 30).isValid, isFalse);
      expect(const AppSettings(retentionDays: 0).isValid, isFalse);
      expect(const AppSettings(retentionDays: 30).isValid, isTrue);
    });

    test('copyWith clears nullable fields; equality', () {
      const a = AppSettings(retentionDays: 7);
      expect(a.copyWith(retentionDays: null).retentionDays, isNull);
      expect(a.copyWith(wifiOnly: true).wifiOnly, isTrue);
      expect(a.copyWith(), a);
      expect(a.hashCode, a.copyWith().hashCode);
      expect(a, isNot(a.copyWith(wifiOnly: true)));
    });
  });

  group('ContentFilter', () {
    final c = content(targetId: 1, kind: ContentKind.post);

    test('empty filter matches everything', () {
      expect(ContentFilter().matches(c, [media()]), isTrue);
    });

    test('each field narrows the result', () {
      expect(ContentFilter(kind: ContentKind.story).matches(c, []), isFalse);
      expect(ContentFilter(targetIds: {2}).matches(c, []), isFalse);
      expect(ContentFilter(targetIds: {1}).matches(c, []), isTrue);
      expect(ContentFilter(from: t0).matches(c, []), isTrue);
      expect(
        ContentFilter(from: t0.add(const Duration(seconds: 1))).matches(c, []),
        isFalse,
      );
      expect(ContentFilter(to: t0).matches(c, []), isFalse);
      expect(
        ContentFilter(mediaType: MediaType.video).matches(c, [media()]),
        isFalse,
      );
      expect(
        ContentFilter(mediaType: MediaType.video)
            .matches(c, [media(type: MediaType.video)]),
        isTrue,
      );
      expect(
        ContentFilter(statuses: {ContentStatus.done}).matches(c, []),
        isFalse,
      );
    });

    test('equality is by value, sets are unordered', () {
      expect(
        ContentFilter(targetIds: {1, 2}),
        ContentFilter(targetIds: {2, 1}),
      );
      expect(
        ContentFilter(targetIds: {1}).hashCode,
        ContentFilter(targetIds: {1}).hashCode,
      );
      expect(ContentFilter(kind: ContentKind.post), isNot(ContentFilter()));
      expect(
        ContentFilter(kind: ContentKind.post).copyWith(kind: null),
        ContentFilter(),
      );
    });
  });
}
