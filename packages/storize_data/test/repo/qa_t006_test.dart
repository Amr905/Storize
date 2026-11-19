// QA additions for T-006: gaps found in the shared contract suites, error
// mapping through the repos, stream coalescing and leaks.
import 'dart:async';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'contract/account_activity_contract.dart' show anEvent;
import 'support/builders.dart';
import 'support/harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final impls = <String, RepoHarness Function()>{
    'fake': FakeHarness.new,
    'drift': DriftHarness.new,
  };
  for (final MapEntry(key: name, value: create) in impls.entries) {
    group('$name:', () {
      late RepoHarness h;
      setUp(() => h = create());
      tearDown(() => h.dispose());

      test('ContentFilter from/to with mixed-timezone DateTimes', () async {
        final t = (await h.targets.insert(aTarget())).id;
        final a = (await h.content.insertIfNew(
          aContent(t, remoteId: 'a', postedAt: at(10)),
          [],
        )).contentId;
        final b = (await h.content.insertIfNew(
          aContent(t, remoteId: 'b', postedAt: at(20)),
          [],
        )).contentId;
        Future<List<int>> ids(ContentFilter f) async {
          final w = Watch(h.content.watchLibrary(f));
          final l = await w.until((_) => true);
          await w.cancel();
          return l.map((r) => r.content.id).toList()..sort();
        }

        // Same instant expressed as local time and as a +05:00-like UTC shift
        // is not constructible in Dart; local vs UTC is the real mix.
        expect(await ids(ContentFilter(from: at(10).toLocal())), [a, b]);
        expect(await ids(ContentFilter(from: at(20).toLocal())), [b]);
        expect(await ids(ContentFilter(to: at(20).toLocal())), [a]);
        expect(
          await ids(ContentFilter(from: at(10).toLocal(), to: at(20))),
          [a],
        );
        expect(
          await ids(ContentFilter(from: at(10), to: at(20).toLocal())),
          [a],
        );
        expect(
          await ids(
            ContentFilter(from: at(20).toLocal(), to: at(20).toLocal()),
          ),
          isEmpty,
        );
      });

      test('pendingMedia limit cuts across story/post boundaries', () async {
        final t = (await h.targets.insert(aTarget())).id;
        final post = (await h.content.insertIfNew(
          aContent(t, remoteId: 'p', kind: ContentKind.post, detectedAt: at(0)),
          [aMedia(), aMedia(slideIndex: 1)],
        )).contentId;
        final s1 = (await h.content.insertIfNew(
          aContent(t, remoteId: 's1', detectedAt: at(5)),
          [aMedia()],
        )).contentId;
        final s2 = (await h.content.insertIfNew(
          aContent(t, remoteId: 's2', detectedAt: at(6)),
          [aMedia(), aMedia(slideIndex: 1)],
        )).contentId;
        List<(int, int)> pairs(List<PendingMedia> l) => [
          for (final p in l) (p.content.id, p.file.slideIndex),
        ];
        // Stories first: s1/0, s2/0, s2/1, then post/0, post/1.
        final all = pairs(await h.content.pendingMedia());
        expect(all, [(s1, 0), (s2, 0), (s2, 1), (post, 0), (post, 1)]);
        for (var n = 1; n <= 5; n++) {
          expect(
            pairs(await h.content.pendingMedia(limit: n)),
            all.take(n).toList(),
            reason: 'limit $n',
          );
        }
        expect(pairs(await h.content.pendingMedia(limit: 4)).last, (post, 0));
      });

      test('listActive rotates after last*CheckAt updates', () async {
        final a = await h.targets.insert(
          aTarget(remoteUserId: 'a', username: 'a'),
        );
        final b = await h.targets.insert(
          aTarget(remoteUserId: 'b', username: 'b'),
        );
        final c = await h.targets.insert(
          aTarget(remoteUserId: 'c', username: 'c'),
        );
        for (final scope in [CheckScope.stories, CheckScope.posts]) {
          Future<void> stamp(Target t, int m) => h.targets.update(
            scope == CheckScope.stories
                ? t.copyWith(lastStoriesCheckAt: at(m))
                : t.copyWith(lastPostsCheckAt: at(m)),
          );
          List<int> order(List<Target> l) => l.map((t) => t.id).toList();
          // Never-checked first, by id.
          expect(order(await h.targets.listActive(scope)), [a.id, b.id, c.id]);
          var cur = (await h.targets.listActive(scope)).first;
          await stamp(cur, 1);
          expect(order(await h.targets.listActive(scope)), [b.id, c.id, a.id]);
          cur = (await h.targets.listActive(scope)).first;
          await stamp(cur, 2);
          cur = (await h.targets.listActive(scope)).first;
          await stamp(cur, 3);
          // a=1, b=2, c=3: oldest first, a is next again.
          expect(order(await h.targets.listActive(scope)), [a.id, b.id, c.id]);
          await stamp((await h.targets.listActive(scope)).first, 4);
          expect(order(await h.targets.listActive(scope)), [b.id, c.id, a.id]);
          // Reset for the next scope iteration (other column).
        }
      });

      test(
        'insertIfNew with 0 media: row, no media, second call not new',
        () async {
          final t = (await h.targets.insert(aTarget())).id;
          final r1 = await h.content.insertIfNew(aContent(t), []);
          final r2 = await h.content.insertIfNew(aContent(t), []);
          expect(r1.isNew, isTrue);
          expect(r2.isNew, isFalse);
          expect(r2.contentId, r1.contentId);
          final got = (await h.content.getById(r1.contentId))!;
          expect(got.media, isEmpty);
          expect(got.content.extras, isEmpty);
          expect(await h.content.pendingMedia(), isEmpty);
        },
      );

      test(
        'updates of non-existent ids are StateErrors (every repo)',
        () async {
          final t = await h.targets.insert(aTarget());
          await expectLater(
            h.targets.update(t.copyWith(id: 777)),
            throwsStateError,
          );
          await expectLater(
            h.content.updateContent(aContent(t.id).copyWith(id: 888)),
            throwsStateError,
          );
          await expectLater(
            h.content.updateMediaFile(aMedia().copyWith(id: 999)),
            throwsStateError,
          );
          await expectLater(
            h.accounts.setStatus(555, AccountStatus.active),
            throwsStateError,
          );
          await expectLater(
            h.checkRuns.finish(
              444,
              finishedAt: t0,
              result: CheckResult.ok,
            ),
            throwsStateError,
          );
        },
      );

      test(
        'watchRecent: old events drop out when the clock crosses 7 days',
        () async {
          final now = h.clock.now();
          await h.activity.add(
            anEvent(at: now.subtract(const Duration(days: 6, hours: 23))),
          );
          await h.activity.add(anEvent(at: now));
          final w = Watch(h.activity.watchRecent());
          await w.until((l) => l.length == 2);
          h.clock.advance(const Duration(hours: 2));
          // Any change triggers a new emission.
          await h.activity.add(anEvent(at: h.clock.now()));
          final l = await w.until(
            (l) => l.length == 2 && l.first.at == h.clock.now(),
          );
          expect(
            l
                .map((e) => e.at)
                .contains(now.subtract(const Duration(days: 6, hours: 23))),
            isFalse,
          );
          await w.cancel();
        },
      );

      test('fresh streams; cancel then resubscribe works', () async {
        final t = (await h.targets.insert(aTarget())).id;
        expect(identical(h.targets.watchAll(), h.targets.watchAll()), isFalse);
        expect(
          identical(
            h.content.watchLibrary(ContentFilter()),
            h.content.watchLibrary(ContentFilter()),
          ),
          isFalse,
        );
        final s = h.content.watchLibrary(ContentFilter());
        final w1 = Watch(s);
        await w1.until((l) => l.isEmpty);
        await w1.cancel();
        await h.content.insertIfNew(aContent(t), [aMedia()]);
        final w2 = Watch(h.content.watchLibrary(ContentFilter()));
        await w2.until((l) => l.length == 1);
        await w2.cancel();
      });
    });
  }

  group('drift error mapping through the repos', () {
    late DriftHarness h;
    setUp(() => h = DriftHarness());
    tearDown(() => h.dispose());

    Matcher sqlite(int code) => allOf(
      isA<SqliteException>(),
      isNot(isA<DuplicateEntityException>()),
      predicate<SqliteException>((e) => e.extendedResultCode == code),
    );

    test('UNIQUE: target insert, in and out of a transaction', () async {
      await h.targets.insert(aTarget());
      await expectLater(
        h.targets.insert(aTarget()),
        throwsA(isA<DuplicateEntityException>()),
      );
      await expectLater(
        h.db.transaction(() => h.targets.insert(aTarget())),
        throwsA(isA<DuplicateEntityException>()),
      );
      // The transaction rolled back; the db still works.
      expect(
        (await h.targets.insert(aTarget(remoteUserId: 'z', username: 'z'))).id,
        2,
      );
    });

    test(
      'UNIQUE: target update onto an existing key, in a transaction',
      () async {
        await h.targets.insert(aTarget());
        final b = await h.targets.insert(
          aTarget(remoteUserId: 'b', username: 'b'),
        );
        await expectLater(
          h.db.transaction(
            () => h.targets.update(aTarget().copyWith(id: b.id)),
          ),
          throwsA(isA<DuplicateEntityException>()),
        );
      },
    );

    test('CHECK (275): the entity asserts first; the DB check still holds '
        'and is not remapped, also inside a transaction', () async {
      final t = await h.targets.insert(aTarget());
      expect(
        () => t.copyWith(
          trackStories: false,
          trackPosts: false,
          trackReels: false,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'Target cannot be built with all flags off (debug)',
      );
      Future<void> raw() => h.db.targetsDao.updatePartial(
        t.id,
        const TargetsCompanion(
          trackStories: Value(false),
          trackPosts: Value(false),
          trackReels: Value(false),
        ),
      );
      await expectLater(
        mapUniqueViolation('target', 'k', raw),
        throwsA(sqlite(275)),
      );
      await expectLater(
        h.db.transaction(() => mapUniqueViolation('target', 'k', raw)),
        throwsA(sqlite(275)),
      );
      expect((await h.targets.getById(t.id))!.trackStories, isTrue);
    });

    test('FK (787): content for an unknown target, in a transaction', () async {
      await expectLater(
        h.content.insertIfNew(aContent(4242), []),
        throwsA(sqlite(787)),
      );
      await expectLater(
        h.db.transaction(() => h.content.insertIfNew(aContent(4242), [])),
        throwsA(sqlite(787)),
      );
      await expectLater(
        h.activity.add(anEvent(at: t0).copyWith(targetId: 4242)),
        throwsA(sqlite(787)),
      );
    });

    test('UNIQUE: content updateContent clash, in a transaction', () async {
      final t = (await h.targets.insert(aTarget())).id;
      final a = (await h.content.insertIfNew(
        aContent(t, remoteId: 'a'),
        [],
      )).contentId;
      await h.content.insertIfNew(aContent(t, remoteId: 'b'), []);
      final c = (await h.content.getById(a))!.content;
      await expectLater(
        h.db.transaction(
          () => h.content.updateContent(
            aContent(t, remoteId: 'b').copyWith(id: c.id),
          ),
        ),
        throwsA(isA<DuplicateEntityException>()),
      );
    });
  });

  group('drift streams', () {
    test(
      '50 media updates coalesce; final state wins; first not delayed',
      () async {
        final h = DriftHarness(
          libraryDebounce: const Duration(milliseconds: 75),
        );
        addTearDown(h.dispose);
        final t = (await h.targets.insert(aTarget())).id;
        final id = (await h.content.insertIfNew(aContent(t), [
          aMedia(),
        ])).contentId;
        final media = (await h.content.getById(id))!.media.single;

        final sw = Stopwatch()..start();
        final w = Watch(h.content.watchLibrary(ContentFilter()));
        await w.until((l) => l.isNotEmpty);
        final firstMs = sw.elapsedMilliseconds;

        w.mark();
        sw
          ..reset()
          ..start();
        for (var i = 1; i <= 50; i++) {
          await h.content.updateMediaFile(media.copyWith(attempts: i));
        }
        final loopMs = sw.elapsedMilliseconds;
        final last = await w.until(
          (l) => l.single.media.single.attempts == 50,
        );
        final settleMs = sw.elapsedMilliseconds;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final emissions = w.values.length - 1;
        // Measurement output for the QA review.
        // ignore: avoid_print
        print(
          'QA-METRIC first=${firstMs}ms loop=${loopMs}ms '
          'settle=${settleMs}ms emissions(50 updates)=$emissions',
        );
        expect(last.single.media.single.attempts, 50);
        expect(w.latest!.single.media.single.attempts, 50);
        expect(emissions, lessThan(10));
        expect(firstMs, lessThan(75), reason: 'first emission not debounced');
        await w.cancel();
      },
    );

    test(
      'no timers stay pending after every subscription is cancelled',
      () async {
        final timers = <Timer>[];
        await runZoned(
          () async {
            final h = DriftHarness(
              libraryDebounce: const Duration(milliseconds: 50),
            );
            final t = (await h.targets.insert(aTarget())).id;
            final subs = <Watch<Object?>>[
              Watch(h.targets.watchAll()),
              Watch(h.targets.watchById(t)),
              Watch(h.content.watchLibrary(ContentFilter())),
              Watch(h.accounts.watchActive()),
              Watch(h.activity.watchRecent()),
            ];
            await Future<void>.delayed(const Duration(milliseconds: 50));
            // Create a pending debounce timer, then cancel mid-flight.
            await h.content.insertIfNew(aContent(t, remoteId: 'x'), [aMedia()]);
            await h.content.insertIfNew(aContent(t, remoteId: 'y'), [aMedia()]);
            await Future<void>.delayed(const Duration(milliseconds: 15));
            for (final s in subs) {
              await s.cancel();
            }
            await h.dispose();
            await Future<void>.delayed(const Duration(milliseconds: 150));
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, d, f) {
              final timer = parent.createTimer(zone, d, f);
              timers.add(timer);
              return timer;
            },
          ),
        );
        expect(timers.where((t) => t.isActive), isEmpty);
        expect(timers, isNotEmpty);
      },
    );
  });
}
