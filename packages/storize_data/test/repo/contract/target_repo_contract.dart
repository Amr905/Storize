import 'package:flutter_test/flutter_test.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import '../support/builders.dart';
import '../support/harness.dart';

/// Behaviour every [TargetRepo] must show. Runs against the fake and drift.
void runTargetRepoContract(RepoHarness Function() create) {
  late RepoHarness h;
  late TargetRepo repo;
  setUp(() {
    h = create();
    repo = h.targets;
  });
  tearDown(() => h.dispose());

  group('insert / read', () {
    test(
      'assigns distinct non-zero ids and returns the stored entity',
      () async {
        final a = await repo.insert(aTarget());
        final b = await repo.insert(
          aTarget(remoteUserId: 'u-2', username: 'b'),
        );
        expect(a.id, isNot(Target.unsavedId));
        expect(b.id, isNot(a.id));
        expect(await repo.getById(a.id), a);
        expect(await repo.getById(b.id), b);
      },
    );

    test('ignores the id on the entity passed to insert', () async {
      final stored = await repo.insert(aTarget(id: 99));
      expect(stored.id, isNot(99));
      expect(await repo.getById(99), isNull);
      expect(await repo.getById(stored.id), stored);
    });

    test('round-trips every field', () async {
      final accountId = (await h.accounts.upsert(_account())).id;
      final stored = await repo.insert(aFullTarget(loginAccountId: accountId));
      expect(await repo.getById(stored.id), stored);
      expect(stored.lastNewPostAt, at(6));
    });

    test(
      'a duplicate (platform, remoteUserId) is DuplicateEntityException',
      () async {
        await repo.insert(aTarget());
        await expectLater(
          repo.insert(aTarget(username: 'other')),
          throwsA(isA<DuplicateEntityException>()),
        );
        expect((await repo.watchAll().first).length, 1);
      },
    );

    test('getByRemoteUserId finds the row or returns null', () async {
      final stored = await repo.insert(aTarget());
      expect(
        await repo.getByRemoteUserId(PlatformId.instagram, 'u-1'),
        stored,
      );
      expect(await repo.getByRemoteUserId(PlatformId.instagram, 'zz'), isNull);
    });

    test('getById of an unknown id is null', () async {
      expect(await repo.getById(12345), isNull);
    });
  });

  group('update / delete', () {
    test(
      'update replaces the row, including clearing optional fields',
      () async {
        final stored = await repo.insert(aFullTarget());
        final changed = stored.copyWith(
          username: 'renamed',
          note: null,
          displayName: null,
          lastStoriesCheckAt: at(50),
          status: TargetStatus.error,
        );
        await repo.update(changed);
        final read = await repo.getById(stored.id);
        expect(read, changed);
        expect(read!.note, isNull);
        expect(
          read.lastPostsCheckAt,
          at(4),
          reason: 'untouched field survives',
        );
      },
    );

    test("update onto another target's (platform, remoteUserId) is a "
        'DuplicateEntityException and changes nothing', () async {
      await repo.insert(aTarget());
      final other = await repo.insert(
        aTarget(remoteUserId: 'u-2', username: 'b'),
      );
      final clash = Target(
        id: other.id,
        platform: PlatformId.instagram,
        remoteUserId: 'u-1',
        username: 'b',
        category: TargetCategory.public,
        postsWatermarkAt: t0,
        addedAt: t0,
      );
      await expectLater(
        repo.update(clash),
        throwsA(isA<DuplicateEntityException>()),
      );
      expect((await repo.getById(other.id))!.remoteUserId, 'u-2');
      // Updating a row to its own key is fine.
      await repo.update(other.copyWith(username: 'renamed'));
    });

    test('update of an unknown id is a StateError', () async {
      await expectLater(
        repo.update(aTarget(id: 777)),
        throwsA(isA<StateError>()),
      );
    });

    test('delete removes the row; deleting an unknown id is a no-op', () async {
      final stored = await repo.insert(aTarget());
      await repo.delete(stored.id);
      expect(await repo.getById(stored.id), isNull);
      await repo.delete(stored.id);
      await repo.delete(4242);
    });
  });

  group('streams', () {
    test(
      'watchAll emits on subscribe and after insert, update and delete',
      () async {
        final w = Watch(repo.watchAll());
        addTearDown(w.cancel);
        expect(await w.until((l) => l.isEmpty), isEmpty);

        w.mark();
        final a = await repo.insert(aTarget());
        await w.until((l) => l.length == 1 && l.single == a);

        w.mark();
        final renamed = a.copyWith(username: 'zed');
        await repo.update(renamed);
        await w.until((l) => l.length == 1 && l.single.username == 'zed');

        w.mark();
        await repo.delete(a.id);
        await w.until((l) => l.isEmpty);
      },
    );

    test('watchAll orders by username (case-insensitive), then id', () async {
      final b = await repo.insert(
        aTarget(remoteUserId: '1', username: 'bob'),
      );
      final upperA = await repo.insert(
        aTarget(remoteUserId: '2', username: 'Alice'),
      );
      final lowerA = await repo.insert(
        aTarget(remoteUserId: '3', username: 'alice'),
      );
      final w = Watch(repo.watchAll());
      addTearDown(w.cancel);
      final list = await w.until((l) => l.length == 3);
      expect(list.map((t) => t.id), [upperA.id, lowerA.id, b.id]);
    });

    test(
      'watchById: null first for an unknown id, then the row, then null',
      () async {
        final stored = await repo.insert(aTarget());
        final missing = Watch(repo.watchById(stored.id + 100));
        addTearDown(missing.cancel);
        await missing.until((t) => t == null);

        final w = Watch(repo.watchById(stored.id));
        addTearDown(w.cancel);
        await w.until((t) => t == stored);

        w.mark();
        await repo.update(stored.copyWith(note: 'n'));
        await w.until((t) => t?.note == 'n');

        w.mark();
        await repo.delete(stored.id);
        await w.until((t) => t == null);
      },
    );

    test('every watch call returns a new stream', () {
      expect(identical(repo.watchAll(), repo.watchAll()), isFalse);
      expect(identical(repo.watchById(1), repo.watchById(1)), isFalse);
    });
  });

  group('listActive', () {
    test('stories scope: active targets that track stories, least recently '
        'checked first, never-checked first, ties by id', () async {
      final never2 = await repo.insert(
        aTarget(remoteUserId: '1', username: 'a'),
      );
      final old = await repo.insert(
        aTarget(
          remoteUserId: '2',
          username: 'b',
          lastStoriesCheckAt: at(5),
        ),
      );
      final never1 = await repo.insert(
        aTarget(remoteUserId: '3', username: 'c'),
      );
      final recent = await repo.insert(
        aTarget(
          remoteUserId: '4',
          username: 'd',
          lastStoriesCheckAt: at(9),
        ),
      );
      await repo.insert(
        aTarget(
          remoteUserId: '5',
          username: 'paused',
          status: TargetStatus.paused,
        ),
      );
      await repo.insert(
        aTarget(remoteUserId: '6', username: 'noStories', trackStories: false),
      );
      final ids = (await repo.listActive(CheckScope.stories)).map((t) => t.id);
      expect(ids, [never2.id, never1.id, old.id, recent.id]);
    });

    test('posts scope includes reels-only targets and orders by the posts '
        'check time', () async {
      final postsOnly = await repo.insert(
        aTarget(
          remoteUserId: '1',
          username: 'a',
          trackStories: false,
          trackReels: false,
          lastPostsCheckAt: at(8),
        ),
      );
      final reelsOnly = await repo.insert(
        aTarget(
          remoteUserId: '2',
          username: 'b',
          trackStories: false,
          trackPosts: false,
          lastPostsCheckAt: at(2),
        ),
      );
      final storiesOnly = await repo.insert(
        aTarget(
          remoteUserId: '3',
          username: 'c',
          trackPosts: false,
          trackReels: false,
        ),
      );
      final both = await repo.insert(
        aTarget(remoteUserId: '4', username: 'd', lastStoriesCheckAt: at(1)),
      );
      final posts = await repo.listActive(CheckScope.posts);
      expect(posts.map((t) => t.id), [both.id, reelsOnly.id, postsOnly.id]);
      expect(posts.map((t) => t.id), isNot(contains(storiesOnly.id)));
    });

    test(
      'stories ordering ignores the posts check time and vice versa',
      () async {
        final a = await repo.insert(
          aTarget(
            remoteUserId: '1',
            username: 'a',
            lastStoriesCheckAt: at(1),
            lastPostsCheckAt: at(9),
          ),
        );
        final b = await repo.insert(
          aTarget(
            remoteUserId: '2',
            username: 'b',
            lastStoriesCheckAt: at(9),
            lastPostsCheckAt: at(1),
          ),
        );
        expect(
          (await repo.listActive(CheckScope.stories)).map((t) => t.id),
          [a.id, b.id],
        );
        expect(
          (await repo.listActive(CheckScope.posts)).map((t) => t.id),
          [b.id, a.id],
        );
      },
    );

    test('all scope: any tracked kind, by id', () async {
      final a = await repo.insert(aTarget(remoteUserId: '1', username: 'z'));
      final b = await repo.insert(
        aTarget(
          remoteUserId: '2',
          username: 'a',
          trackStories: false,
          trackPosts: false,
        ),
      );
      await repo.insert(
        aTarget(
          remoteUserId: '3',
          status: TargetStatus.notVisible,
        ),
      );
      expect(
        (await repo.listActive(CheckScope.all)).map((t) => t.id),
        [a.id, b.id],
      );
    });

    test('empty repo gives an empty list', () async {
      expect(await repo.listActive(CheckScope.stories), isEmpty);
    });
  });
}

LoginAccount _account() => LoginAccount(
  id: LoginAccount.unsavedId,
  platform: PlatformId.instagram,
  remoteUserId: 'acct-1',
  username: 'tester',
  status: AccountStatus.active,
  connectedAt: t0,
);
