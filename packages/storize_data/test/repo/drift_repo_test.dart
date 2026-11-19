// Behaviour specific to the drift repositories: error mapping, mapping duties
// from the T-005 review, the debounce, pruning and what is not covered.
import 'dart:async';

import 'package:drift/drift.dart'
    show DriftWrappedException, Value, driftRuntimeOptions;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo_support.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'contract/account_activity_contract.dart';
import 'support/builders.dart';
import 'support/harness.dart';

SqliteException _sqlite(int code) =>
    SqliteException(extendedResultCode: code, message: 'test');

void main() {
  // The debounce test opens a second in-memory database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftHarness h;
  setUp(() => h = DriftHarness());
  tearDown(() => h.dispose());

  group('error mapping', () {
    test('UNIQUE (2067), also when wrapped by drift, is a duplicate', () async {
      expect(isUniqueViolation(_sqlite(2067)), isTrue);
      expect(
        isUniqueViolation(
          DriftWrappedException(message: 'm', cause: _sqlite(2067)),
        ),
        isTrue,
      );
      await expectLater(
        mapUniqueViolation<void>('x', 'k', () => throw _sqlite(2067)),
        throwsA(
          isA<DuplicateEntityException>()
              .having((e) => e.entity, 'entity', 'x')
              .having((e) => e.key, 'key', 'k'),
        ),
      );
    });

    test('other constraint codes and other errors are not duplicates', () {
      // 1555 PRIMARYKEY, 275 CHECK, 787 FOREIGNKEY, 19 generic constraint.
      for (final code in [1555, 275, 787, 19, 1]) {
        expect(isUniqueViolation(_sqlite(code)), isFalse, reason: '$code');
      }
      expect(isUniqueViolation(StateError('x')), isFalse);
      expect(isUniqueViolation(DriftWrappedException(message: 'm')), isFalse);
      expect(
        () => mapUniqueViolation<void>('x', 'k', () => throw _sqlite(275)),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a real CHECK violation stays a SqliteException', () async {
      // The Target entity cannot be built with no track flag, so go through
      // the DAO. The repo's UNIQUE mapping must not swallow the CHECK error.
      Future<void> insertNoTracking() => mapUniqueViolation(
        'target',
        'k',
        () => h.db.targetsDao.insert(
          TargetsCompanion.insert(
            platform: PlatformId.instagram,
            remoteUserId: 'u-x',
            username: 'x',
            category: TargetCategory.public,
            status: TargetStatus.active,
            postsWatermarkAt: t0,
            addedAt: t0,
            trackStories: const Value(false),
            trackPosts: const Value(false),
            trackReels: const Value(false),
          ),
        ),
      );
      await expectLater(
        insertNoTracking(),
        throwsA(
          allOf(
            isA<SqliteException>(),
            isNot(isA<DuplicateEntityException>()),
            predicate<SqliteException>((e) => e.extendedResultCode == 275),
          ),
        ),
      );
    });

    test(
      'a duplicate content (target, kind, remoteId) via updateContent',
      () async {
        final t = (await h.targets.insert(aTarget())).id;
        final a = (await h.content.insertIfNew(
          aContent(t, remoteId: 'a'),
          [],
        )).contentId;
        await h.content.insertIfNew(aContent(t, remoteId: 'b'), []);
        final clash = (await h.content.getById(a))!.content;
        await expectLater(
          h.content.updateContent(
            Content(
              id: clash.id,
              targetId: t,
              kind: clash.kind,
              remoteId: 'b',
              postedAt: t0,
              slideCount: 1,
              detectedAt: t0,
            ),
          ),
          throwsA(isA<DuplicateEntityException>()),
        );
      },
    );
  });

  group('mapping duties', () {
    test('an explicit id of 0 is never stored as row 0', () async {
      final target = await h.targets.insert(aTarget());
      final account = await h.accounts.upsert(anAccount());
      final content = await h.content.insertIfNew(aContent(target.id), [
        aMedia(),
      ]);
      final event = await h.activity.add(anEvent(at: t0));
      final run = await h.checkRuns.start(
        scope: CheckScope.stories,
        trigger: CheckTrigger.periodic,
        startedAt: t0,
      );
      expect(target.id, 1);
      expect(account.id, 1);
      expect(content.contentId, 1);
      expect(event.id, 1);
      expect(run.id, 1);
      for (final table in [
        'target',
        'login_account',
        'content',
        'media_file',
        'activity_event',
        'check_run',
      ]) {
        final rows = await h.db
            .customSelect('SELECT COUNT(*) AS n FROM $table WHERE id = 0')
            .getSingle();
        expect(rows.read<int>('n'), 0, reason: table);
      }
    });

    test('dates are stored as UTC epoch milliseconds', () async {
      final local = DateTime.utc(2026, 3, 10, 12, 0, 0, 5).toLocal();
      final target = await h.targets.insert(
        aTarget().copyWith(lastNewPostAt: local),
      );
      final raw = await h.db
          .customSelect('SELECT last_new_post_at AS v FROM target')
          .getSingle();
      expect(raw.read<int>('v'), local.millisecondsSinceEpoch);
      final read = (await h.targets.getById(target.id))!;
      expect(read.lastNewPostAt!.isUtc, isTrue);
      expect(read.lastNewPostAt, DateTime.utc(2026, 3, 10, 12, 0, 0, 5));
    });

    test('extras and payload are stored as JSON text; empty is NULL', () async {
      final t = (await h.targets.insert(aTarget())).id;
      await h.content.insertIfNew(
        aContent(
          t,
          extras: {
            'a': 1,
            'b': [true, null],
          },
        ),
        [],
      );
      await h.content.insertIfNew(aContent(t, remoteId: 'plain'), []);
      await h.activity.add(anEvent(at: t0, payload: {'k': 'v'}));
      await h.activity.add(anEvent(at: t0));
      final extras = await h.db
          .customSelect('SELECT extras_json AS v FROM content ORDER BY id')
          .get();
      expect(extras[0].read<String>('v'), '{"a":1,"b":[true,null]}');
      expect(extras[1].readNullable<String>('v'), isNull);
      final payloads = await h.db
          .customSelect(
            'SELECT payload_json AS v FROM activity_event ORDER BY id',
          )
          .get();
      expect(payloads[0].read<String>('v'), '{"k":"v"}');
      expect(payloads[1].readNullable<String>('v'), isNull);
      expect(decodeJsonMap(null), isEmpty);
      expect(() => decodeJsonMap('[1]'), throwsFormatException);
    });

    test('enums are stored through their dbValue', () async {
      await h.targets.insert(aTarget(status: TargetStatus.notVisible));
      final raw = await h.db
          .customSelect('SELECT status AS v, category AS c FROM target')
          .getSingle();
      expect(raw.read<String>('v'), 'NOT_VISIBLE');
      expect(raw.read<String>('c'), 'PUBLIC');
    });

    test('updates are one short statement: a partial write touches only '
        'the present columns', () async {
      final t = await h.targets.insert(aFullTarget());
      // What the use cases do for a watermark bump goes through update(); the
      // DAO partial write the repo uses must leave unlisted columns alone.
      await h.db.targetsDao.updatePartial(
        t.id,
        TargetsCompanion(lastPostsCheckAt: Value(at(99))),
      );
      final read = (await h.targets.getById(t.id))!;
      expect(read.lastPostsCheckAt, at(99));
      expect(read.username, t.username);
    });
  });

  group('settings are out of scope', () {
    test('the database has no settings table', () async {
      final names = h.db.allTables.map((t) => t.actualTableName).toSet();
      expect(names.any((n) => n.contains('setting')), isFalse);
    });
  });

  group('activity pruning helper', () {
    test(
      'pruneExpired deletes events older than 7 days from the clock',
      () async {
        final now = h.clock.now();
        final old = await h.activity.add(
          anEvent(
            at: now.subtract(
              ActivityEvent.retention + const Duration(milliseconds: 1),
            ),
          ),
        );
        final edge = await h.activity.add(
          anEvent(at: now.subtract(ActivityEvent.retention)),
        );
        final fresh = await h.activity.add(anEvent(at: now));
        expect(await h.activity.pruneExpired(), 1);
        expect(await h.db.activityDao.getById(old.id), isNull);
        expect(await h.db.activityDao.getById(edge.id), isNotNull);
        expect(await h.db.activityDao.getById(fresh.id), isNotNull);

        h.clock.advance(const Duration(days: 8));
        expect(await h.activity.pruneExpired(), 2);
        expect(await h.activity.pruneExpired(), 0);
      },
    );
  });

  group('library stream debounce', () {
    test('the first value is immediate, a burst collapses to one trailing '
        'emission with the final state', () async {
      final db = DriftHarness(
        libraryDebounce: const Duration(milliseconds: 200),
      );
      addTearDown(db.dispose);
      final t = (await db.targets.insert(aTarget())).id;
      final w = Watch(db.content.watchLibrary(ContentFilter()));
      addTearDown(w.cancel);
      final sw = Stopwatch()..start();
      await w.until((l) => l.isEmpty);
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 190)));

      w.mark();
      for (var i = 0; i < 8; i++) {
        await db.content.insertIfNew(aContent(t, remoteId: 'r$i'), [aMedia()]);
      }
      await w.until((l) => l.length == 8);
      // 8 changes, at most a couple of emissions.
      expect(w.values.length - 1, lessThanOrEqualTo(3));
    });

    test('debounceAfterFirst: leading value, trailing latest, errors pass, '
        'cancel stops timers', () async {
      final source = StreamController<int>();
      final out = <int>[];
      final errors = <Object>[];
      final sub = debounceAfterFirst(
        source.stream,
        const Duration(milliseconds: 40),
      ).listen(out.add, onError: errors.add);
      source
        ..add(1)
        ..add(2)
        ..add(3)
        ..addError('boom');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(out, [1]);
      expect(errors, ['boom']);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(out, [1, 3]);

      source.add(4);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(out, [1, 3], reason: 'a cancelled stream emits nothing more');
      await source.close();
    });

    test(
      'debounceAfterFirst flushes the pending value when the source ends',
      () async {
        final source = StreamController<int>();
        final done = Completer<void>();
        final out = <int>[];
        debounceAfterFirst(
          source.stream,
          const Duration(seconds: 5),
        ).listen(out.add, onDone: done.complete);
        source
          ..add(1)
          ..add(2);
        await source.close();
        await done.future.timeout(const Duration(seconds: 2));
        expect(out, [1, 2]);
      },
    );
  });

  group('streams', () {
    test('watch streams are single-subscription like the fakes', () async {
      final stream = h.targets.watchAll();
      final sub = stream.listen((_) {});
      expect(() => stream.listen((_) {}), throwsStateError);
      await sub.cancel();
    });
  });
}
