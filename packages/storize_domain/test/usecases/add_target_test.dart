import 'package:storize_domain/src/usecases/add_target.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_domain/testing.dart';
import 'package:storize_model/storize_model.dart';
import 'package:test/test.dart';

RemoteUser user({
  String id = '100',
  String name = 'nour_k',
  bool isPrivate = false,
  bool followed = false,
  bool blocked = false,
}) => RemoteUser(
  remoteUserId: id,
  username: name,
  displayName: 'Nour',
  isPrivate: isPrivate,
  followedByViewer: followed,
  blockedByViewer: blocked,
);

class ThrowingScheduler implements Scheduler {
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
  }) async => throw StateError('secret-ish detail');

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late FakePlatformHolder h;
  setUp(() => h = FakePlatformHolder());

  group('AC1 normalization (table)', () {
    final valid = <String, String>{
      'nour_k': 'nour_k',
      '@nour_k': 'nour_k',
      '  Nour_K  ': 'nour_k',
      '@NOUR.K': 'nour.k',
      'a': 'a',
      'a.b': 'a.b',
      '_a_': '_a_',
      'a' * 30: 'a' * 30,
      'user123': 'user123',
      '1234': '1234',
      'instagram.com/nour_k': 'nour_k',
      'www.instagram.com/nour_k': 'nour_k',
      'm.instagram.com/nour_k': 'nour_k',
      'https://instagram.com/nour_k': 'nour_k',
      'http://www.instagram.com/nour_k/': 'nour_k',
      'HTTPS://WWW.INSTAGRAM.COM/Nour_K': 'nour_k',
      'https://m.instagram.com/nour_k/?hl=en': 'nour_k',
      'https://www.instagram.com/nour_k?igsh=abc': 'nour_k',
      'https://www.instagram.com/nour_k#top': 'nour_k',
      'instagram.com/nour_k/reels/': 'nour_k',
      'https://www.instagram.com/stories/nour_k/123456/': 'nour_k',
      'ftp://instagram.com/nour_k': 'nour_k',
      ' https://instagram.com/nour_k ': 'nour_k',
    };
    for (final MapEntry(key: input, value: expected) in valid.entries) {
      test('accepts "$input"', () {
        expect(AddTarget.normalizeUsername(input), expected);
      });
    }

    final invalid = <String>[
      '',
      '   ',
      '@',
      '@@nour',
      'a' * 31,
      '.nour',
      'nour.',
      'no..ur',
      'nour k',
      'nour-k',
      'nour/k',
      'nour?x',
      'nour#x',
      'نور',
      'nöur',
      'Kelvin', // Kelvin sign must not become "k"
      'https://example.com/nour_k',
      'https://notinstagram.com/nour_k',
      'https://instagram.com.evil.test/nour_k',
      'instagram.com',
      'https://www.instagram.com/',
      'https://www.instagram.com/p/ABC123/',
      'https://www.instagram.com/reel/ABC123/',
      'https://www.instagram.com/explore/',
      'https://www.instagram.com/stories/',
      'https://www.instagram.com/.bad/',
      'https://www.instagram.com/${'a' * 31}',
      'nour_k@x',
      'nour\nk',
    ];
    for (final input in invalid) {
      test(
        'rejects ${input.length > 20 ? '${input.length} chars' : input}',
        () {
          expect(AddTarget.normalizeUsername(input), isNull);
        },
      );
    }

    test('table has at least 30 cases', () {
      expect(valid.length + invalid.length, greaterThanOrEqualTo(30));
    });

    test(
      'invalid input is an outcome, not a throw, and calls no network',
      () async {
        final r = await h.add('no..ur', category: TargetCategory.public);
        expect(r, isA<AddTargetInvalidUsername>());
        expect(h.platform.calls, isEmpty);
        expect((h.scheduler as FakeScheduler).checkNowCalls, isEmpty);
      },
    );
  });

  group('AC2 outcomes', () {
    test(
      'added: stores resolved id, canonical username, display data',
      () async {
        h.platform.resolveUserResults.addOk(
          user(name: 'Nour_K', isPrivate: true, followed: true),
        );
        h.platform.latestPostTimeResults.addOk(DateTime.utc(2026, 1, 2));
        final r = await h.add(
          '@nour_k',
          category: TargetCategory.consented,
          note: ' hi ',
        );
        final added = r as AddTargetAdded;
        final t = (await h.targets.getById(added.target.id))!;
        expect(t.remoteUserId, '100');
        expect(t.username, 'Nour_K');
        expect(t.displayName, 'Nour');
        expect(t.isPrivate, isTrue);
        expect(t.category, TargetCategory.consented);
        expect(t.note, 'hi');
        expect(t.status, TargetStatus.active);
        expect(h.platform.callsTo('resolveUser').single.args, ['nour_k']);
      },
    );

    test('already tracked: by user id, even after a rename (AC7)', () async {
      h.platform.resolveUserResults
        ..addOk(user(name: 'old_name'))
        ..addOk(user(name: 'new_name'));
      h.platform.latestPostTimeResults.fallback = const Ok<DateTime?>(null);
      final first = await h.add('old_name', category: TargetCategory.public);
      final second = await h.add('new_name', category: TargetCategory.public);
      final dup = second as AddTargetDuplicate;
      expect(dup.existingId, (first as AddTargetAdded).target.id);
      expect(dup.existingUsername, 'old_name');
      expect(await h.targets.watchAll().first, hasLength(1));
      expect((h.scheduler as FakeScheduler).checkNowCalls, hasLength(1));
    });

    test('duplicate insert race maps to duplicate', () async {
      final racing = RacingTargetRepo(h.targets);
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r = await h.add(
        'nour_k',
        category: TargetCategory.public,
        repo: racing,
      );
      expect(r, isA<AddTargetDuplicate>());
    });

    test('not found', () async {
      h.platform.resolveUserResults.addFailure(const TargetNotFound());
      expect(
        await h.add('x', category: TargetCategory.public),
        isA<AddTargetNotFound>(),
      );
    });

    test('username_mismatch is not found', () async {
      h.platform.resolveUserResults.addFailure(
        const UnknownFailure(null, 'username_mismatch'),
      );
      expect(
        await h.add('x', category: TargetCategory.public),
        isA<AddTargetNotFound>(),
      );
    });

    test('private and not followed', () async {
      h.platform.resolveUserResults.addOk(user(isPrivate: true));
      final r = await h.add('x', category: TargetCategory.public);
      expect(
        (r as AddTargetNotVisible).reason,
        NotVisibleReason.privateNotFollowed,
      );
      expect(await h.targets.watchAll().first, isEmpty);
    });

    test('TargetNotVisible failure', () async {
      h.platform.resolveUserResults.addFailure(const TargetNotVisible());
      final r = await h.add('x', category: TargetCategory.public);
      expect(r, isA<AddTargetNotVisible>());
    });

    test('blocked', () async {
      h.platform.resolveUserResults.addOk(user(blocked: true, followed: true));
      final r = await h.add('x', category: TargetCategory.public);
      expect((r as AddTargetNotVisible).reason, NotVisibleReason.blocked);
    });

    test('private but followed is added', () async {
      h.platform.resolveUserResults.addOk(
        user(isPrivate: true, followed: true),
      );
      h.platform.latestPostTimeResults.addOk(null);
      expect(
        await h.add('x', category: TargetCategory.public),
        isA<AddTargetAdded>(),
      );
    });

    test('session invalid keeps the reason', () async {
      h.platform.resolveUserResults.addFailure(
        const SessionInvalid(SessionReason.challenge),
      );
      final r = await h.add('x', category: TargetCategory.public);
      expect((r as AddTargetSessionNotActive).reason, SessionReason.challenge);
    });

    test('account restricted', () async {
      h.platform.resolveUserResults.addFailure(const AccountRestricted());
      expect(
        await h.add('x', category: TargetCategory.public),
        isA<AddTargetAccountRestricted>(),
      );
    });

    test('rate limited keeps retryAfter', () async {
      h.platform.resolveUserResults.addFailure(
        const RateLimited(Duration(minutes: 9)),
      );
      final r = await h.add('x', category: TargetCategory.public);
      expect(
        (r as AddTargetRateLimited).retryAfter,
        const Duration(minutes: 9),
      );
    });

    test('network', () async {
      h.platform.resolveUserResults.addFailure(const NetworkFailure());
      expect(
        await h.add('x', category: TargetCategory.public),
        isA<AddTargetNetwork>(),
      );
    });

    test('schema changed', () async {
      h.platform.resolveUserResults.addFailure(const SchemaChanged('user.pk'));
      final r = await h.add('x', category: TargetCategory.public);
      expect((r as AddTargetSchemaChanged).where, 'user.pk');
    });

    test('unknown failure', () async {
      h.platform.resolveUserResults.addFailure(
        const UnknownFailure(500, 'http_500'),
      );
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetUnknown;
      expect(r.code, 500);
      expect(r.message, 'http_500');
    });

    test('failures store nothing and schedule nothing', () async {
      h.platform.resolveUserResults.addFailure(const NetworkFailure());
      await h.add('x', category: TargetCategory.public);
      expect(await h.targets.watchAll().first, isEmpty);
      expect((h.scheduler as FakeScheduler).checkNowCalls, isEmpty);
    });
  });

  group('AC3 category, flags, note', () {
    test('category required', () async {
      final r = await h.add('x', category: null);
      expect(r, isA<AddTargetMissingCategory>());
      expect(h.platform.calls, isEmpty);
    });

    test('at least one flag', () async {
      final r = await h.add(
        'x',
        category: TargetCategory.public,
        stories: false,
        posts: false,
        reels: false,
      );
      expect(r, isA<AddTargetNoTrackFlag>());
      expect(h.platform.calls, isEmpty);
    });

    test('reels only is allowed and stored', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r = await h.add(
        'x',
        category: TargetCategory.public,
        stories: false,
        posts: false,
      ) as AddTargetAdded;
      expect(r.target.trackStories, isFalse);
      expect(r.target.trackPosts, isFalse);
      expect(r.target.trackReels, isTrue);
    });

    test('note over 200 is rejected, 200 is accepted', () async {
      expect(
        await h.add('x', category: TargetCategory.public, note: 'a' * 201),
        isA<AddTargetNoteTooLong>(),
      );
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      expect(
        await h.add('x', category: TargetCategory.public, note: 'a' * 200),
        isA<AddTargetAdded>(),
      );
    });

    test('blank note is stored as null', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r = await h.add(
        'x',
        category: TargetCategory.public,
        note: '   ',
      ) as AddTargetAdded;
      expect(r.target.note, isNull);
    });
  });

  group('AC4 watermark', () {
    test('uses latestPostTime', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(DateTime.utc(2025, 5, 5, 5));
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.target.postsWatermarkAt, DateTime.utc(2025, 5, 5, 5));
      expect(r.target.addedAt, h.clock.now());
      expect(h.platform.callsTo('latestPostTime').single.args, ['100']);
    });

    test('no posts uses now', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.target.postsWatermarkAt, h.clock.now());
    });

    test('failure uses now and still adds', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addFailure(const RateLimited(null));
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.target.postsWatermarkAt, h.clock.now());
    });
  });

  group('AC5 over-50 warning', () {
    Future<void> seed(int n) async {
      for (var i = 0; i < n; i++) {
        await h.targets.insert(
          Target(
            id: Target.unsavedId,
            platform: PlatformId.instagram,
            remoteUserId: 's$i',
            username: 'seed$i',
            category: TargetCategory.public,
            postsWatermarkAt: h.clock.now(),
            addedAt: h.clock.now(),
          ),
        );
      }
    }

    test('49 existing: no warning', () async {
      await seed(49);
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.overLimitWarning, isFalse);
    });

    test('50 existing: warning, still added', () async {
      await seed(50);
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.overLimitWarning, isTrue);
      expect(await h.targets.watchAll().first, hasLength(51));
    });
  });

  group('AC6 first check', () {
    test('checkNow for this target', () async {
      h.platform.resolveUserResults.addOk(user());
      h.platform.latestPostTimeResults.addOk(null);
      final r =
          await h.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.firstCheckScheduled, isTrue);
      expect(r.schedulerError, isNull);
      expect((h.scheduler as FakeScheduler).checkNowCalls.single, (
        scope: CheckScope.all,
        targetId: r.target.id,
      ));
    });

    test('scheduler failure does not undo the add', () async {
      final bad = FakePlatformHolder(scheduler: ThrowingScheduler());
      bad.platform.resolveUserResults.addOk(user());
      bad.platform.latestPostTimeResults.addOk(null);
      final r =
          await bad.add('x', category: TargetCategory.public) as AddTargetAdded;
      expect(r.firstCheckScheduled, isFalse);
      expect(r.schedulerError, 'StateError');
      expect(await bad.targets.getById(r.target.id), isNotNull);
    });
  });
}

class FakePlatformHolder {
  FakePlatformHolder({Scheduler? scheduler})
    : scheduler = scheduler ?? FakeScheduler();

  final FakeContentPlatform platform = FakeContentPlatform();
  final FakeTargetRepo targets = FakeTargetRepo();
  final Scheduler scheduler;
  final FakeClock clock = FakeClock(DateTime.utc(2026, 11, 19, 10));

  Future<AddTargetResult> add(
    String raw, {
    required TargetCategory? category,
    bool stories = true,
    bool posts = true,
    bool reels = true,
    String? note,
    TargetRepo? repo,
  }) =>
      AddTarget(
        platform: platform,
        targets: repo ?? targets,
        scheduler: scheduler,
        clock: clock,
      )(
        raw,
        category: category,
        trackStories: stories,
        trackPosts: posts,
        trackReels: reels,
        note: note,
      );
}

/// Reports "none" on the first lookup, then throws on insert as if another
/// writer won the race; later lookups see the winner.
class RacingTargetRepo implements TargetRepo {
  RacingTargetRepo(this._inner);
  final FakeTargetRepo _inner;
  bool _raced = false;

  @override
  Future<Target?> getByRemoteUserId(PlatformId p, String id) async =>
      _raced ? _inner.getByRemoteUserId(p, id) : null;

  @override
  Future<Target> insert(Target target) async {
    await _inner.insert(target);
    _raced = true;
    throw const DuplicateEntityException(
      'target',
      '(platform, remote_user_id)',
    );
  }

  @override
  Stream<List<Target>> watchAll() => _inner.watchAll();
  @override
  Stream<Target?> watchById(int id) => _inner.watchById(id);
  @override
  Future<Target?> getById(int id) => _inner.getById(id);
  @override
  Future<void> update(Target target) => _inner.update(target);
  @override
  Future<void> delete(int id) => _inner.delete(id);
  @override
  Future<List<Target>> listActive(CheckScope scope) => _inner.listActive(scope);
}
