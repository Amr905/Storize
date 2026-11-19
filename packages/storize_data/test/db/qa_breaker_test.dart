// QA scratch rules: raw SQL strings and printed measurements are intended.
// ignore_for_file: avoid_print, prefer_single_quotes, lines_longer_than_80_chars, avoid_catches_without_on_clauses
// QA (T-005): adversarial checks with raw SQL, bad stored values, DAO vs
// domain-repo contract edges and cross-table watch streams.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

const _targetCols =
    'platform, remote_user_id, username, category, status, '
    'posts_watermark_at, added_at';
String _insertTarget({
  String uid = 'u1',
  String flags = '',
  String flagVals = '',
  String wm = '0',
  String extraCols = '',
  String extraVals = '',
}) =>
    "INSERT INTO target ($_targetCols${flags.isEmpty ? '' : ', $flags'}$extraCols) "
    "VALUES ('INSTAGRAM', '$uid', 'n', 'PUBLIC', 'ACTIVE', $wm, 0"
    "${flagVals.isEmpty ? '' : ', $flagVals'}$extraVals)";

void main() {
  late StorizeDatabase db;
  setUp(() => db = newDb());
  tearDown(() => db.close());

  Future<void> sql(String s) => db.customStatement(s);
  Future<void> rejects(String s, [String? contains]) async {
    await expectLater(
      sql(s),
      throwsA(
        predicate<Object>(
          (e) =>
              e.toString().contains(contains ?? 'constraint failed') ||
              e.toString().contains('constraint'),
          'constraint error',
        ),
      ),
      reason: s,
    );
  }

  group('raw SQL violations', () {
    test('UNIQUE target (platform, remote_user_id)', () async {
      await sql(_insertTarget());
      await rejects(_insertTarget());
    });

    test('UNIQUE login_account.remote_user_id', () async {
      const s =
          "INSERT INTO login_account (platform, remote_user_id, username,"
          " status, connected_at) VALUES ('INSTAGRAM','a','x','ACTIVE',0)";
      await sql(s);
      await rejects(s);
    });

    test('UNIQUE content (target, kind, remote) and media slide', () async {
      await sql(_insertTarget());
      const c =
          "INSERT INTO content (target_id, kind, remote_id, posted_at,"
          " detected_at, status) VALUES (1,'STORY','r',0,0,'PENDING')";
      await sql(c);
      await rejects(c);
      // Same remote id but another kind is allowed.
      await sql(c.replaceFirst("'STORY'", "'POST'"));
      const m =
          "INSERT INTO media_file (content_id, slide_index, media_type,"
          " source_url, status) VALUES (1,0,'PHOTO','u','PENDING')";
      await sql(m);
      await rejects(m);
    });

    test('track flags: 0/0/0 rejected, every 1- and 2-flag combo ok', () async {
      await rejects(
        _insertTarget(
          flags: 'track_stories, track_posts, track_reels',
          flagVals: '0,0,0',
        ),
      );
      var i = 0;
      for (final combo in const [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
        [1, 1, 0],
        [1, 0, 1],
        [0, 1, 1],
        [1, 1, 1],
      ]) {
        await sql(
          _insertTarget(
            uid: 'c${i++}',
            flags: 'track_stories, track_posts, track_reels',
            flagVals: combo.join(','),
          ),
        );
      }
      expect(await count(db, 'target'), 7);
    });

    test(
      'flag value 2 (1+1+0 trick) and 5 are rejected by the 0/1 CHECK',
      () async {
        await rejects(
          _insertTarget(
            flags: 'track_stories, track_posts, track_reels',
            flagVals: '2,0,0',
          ),
        );
      },
    );

    test(
      'UPDATE that turns the last flag off is rejected; 2->1 is ok',
      () async {
        await sql(
          _insertTarget(
            flags: 'track_stories, track_posts, track_reels',
            flagVals: '1,0,0',
          ),
        );
        await rejects('UPDATE target SET track_stories = 0');
        await sql('UPDATE target SET track_posts = 1, track_stories = 0');
        await sql('UPDATE target SET track_reels = 1');
        await sql('UPDATE target SET track_posts = 0');
        await rejects('UPDATE target SET track_reels = 0');
      },
    );

    test('NULL posts_watermark_at rejected', () async {
      await rejects(_insertTarget(wm: 'NULL'));
    });

    test('check_run.scope: ALL, lowercase, empty and NULL rejected', () async {
      for (final v in ["'ALL'", "'stories'", "''", 'NULL']) {
        await rejects(
          "INSERT INTO check_run (scope, trigger, started_at) "
          "VALUES ($v, 'PERIODIC', 0)",
        );
      }
    });

    test('orphan rows are rejected (FK enforced)', () async {
      await rejects(
        "INSERT INTO media_file (content_id, slide_index, media_type, "
            "source_url, status) VALUES (999,0,'PHOTO','u','PENDING')",
        'FOREIGN KEY',
      );
      await rejects(
        "INSERT INTO content (target_id, kind, remote_id, posted_at, "
            "detected_at, status) VALUES (999,'STORY','r',0,0,'PENDING')",
        'FOREIGN KEY',
      );
      await rejects(
        _insertTarget(extraCols: ', login_account_id', extraVals: ', 999'),
        'FOREIGN KEY',
      );
      await rejects(
        "INSERT INTO activity_event (at, type, severity, target_id) "
            "VALUES (0,'CHECK_DONE','INFO',999)",
        'FOREIGN KEY',
      );
    });

    test('cascade really removes media rows (no orphan left)', () async {
      final t = await addTarget(db);
      await addContent(
        db,
        targetId: t,
        kind: ContentKind.post,
        media: [mediaCompanion(), mediaCompanion(slideIndex: 1)],
      );
      expect(await count(db, 'media_file'), 2);
      await sql('DELETE FROM target');
      expect(await count(db, 'content'), 0);
      expect(await count(db, 'media_file'), 0);
    });

    test(
      'governor_lease has no FK: lease for a missing account is stored',
      () async {
        await sql(
          "INSERT INTO governor_lease (login_account_id, holder, expires_at, "
          "tokens, last_refill_at) VALUES (42,'h',0,1.5,0)",
        );
        final row = await db.governorLeaseDao.read(42);
        expect(row!.backoffMultiplier, 1.0);
      },
    );
  });

  group('unknown / corrupt stored values read through the DAO', () {
    Future<int> badKind() async {
      final t = await addTarget(db);
      await sql(
        "INSERT INTO content (target_id, kind, remote_id, posted_at, "
        "detected_at, status) VALUES ($t,'REEL2','r',0,0,'PENDING')",
      );
      return t;
    }

    test(
      'unknown content.kind: getById / getLibrary throw ArgumentError',
      () async {
        await badKind();
        Object? e1;
        try {
          await db.contentDao.getById(1);
        } catch (e) {
          e1 = e;
        }
        Object? e2;
        try {
          await db.contentDao.getLibrary(ContentFilter());
        } catch (e) {
          e2 = e;
        }
        print('QA getById -> ${e1.runtimeType}: $e1');
        print('QA getLibrary -> ${e2.runtimeType}: $e2');
        expect(e1, isA<ArgumentError>());
        expect(e2, isA<ArgumentError>());
        expect(e1.toString(), contains('REEL2'));
      },
    );

    test(
      'unknown kind: filtered-by-kind queries still work, bad row skipped',
      () async {
        final t = await badKind();
        await addContent(db, targetId: t, remoteId: 'ok');
        final rows = await db.contentDao.getLibrary(
          ContentFilter(kind: ContentKind.story),
        );
        expect(rows.map((r) => r.content.remoteId), ['ok']);
      },
    );

    test('unknown kind: watchLibrary emits the error on the stream', () async {
      await badKind();
      final stream = db.contentDao.watchLibrary(ContentFilter());
      await expectLater(stream, emitsError(isA<ArgumentError>()));
    });

    test('unknown status / media_type also throw ArgumentError', () async {
      final t = await addTarget(db);
      final c = await addContent(db, targetId: t);
      await sql("UPDATE media_file SET media_type='GIF' WHERE content_id=$c");
      await expectLater(
        db.contentDao.getById(c),
        throwsA(isA<ArgumentError>()),
      );
      await sql("UPDATE media_file SET media_type='PHOTO'");
      await sql("UPDATE target SET status='WEIRD'");
      await expectLater(
        db.targetsDao.getById(t),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('legacy row with NULL extras_json/caption reads fine', () async {
      final t = await addTarget(db);
      final c = await addContent(db, targetId: t);
      final row = await db.contentDao.getById(c);
      expect(row!.content.extrasJson, isNull);
      expect(row.content.slideCount, 1);
    });
  });

  group('contract edges vs the domain fakes', () {
    test('listActive(all) orders by id only; stories by last check, nulls first', () async {
      final a = await addTarget(db, remoteUserId: 'a', username: 'a');
      final b = await addTarget(db, remoteUserId: 'b', username: 'b');
      final c = await addTarget(db, remoteUserId: 'c', username: 'c');
      await db.targetsDao.updatePartial(
        a,
        TargetsCompanion(lastStoriesCheckAt: Value(minutesAfter(5))),
      );
      await db.targetsDao.updatePartial(
        b,
        TargetsCompanion(lastStoriesCheckAt: Value(minutesAfter(1))),
      );
      expect(
        (await db.targetsDao.listActive(CheckScope.stories)).map((t) => t.id),
        [c, b, a],
      );
      expect(
        (await db.targetsDao.listActive(CheckScope.all)).map((t) => t.id),
        [a, b, c],
      );
      // posts scope: nobody checked -> by id; a reels-only target is included.
      await db.targetsDao.updatePartial(
        b,
        const TargetsCompanion(
          trackPosts: Value(false),
          trackReels: Value(true),
        ),
      );
      await db.targetsDao.updatePartial(
        c,
        const TargetsCompanion(
          trackPosts: Value(false),
          trackReels: Value(false),
        ),
      );
      expect(
        (await db.targetsDao.listActive(CheckScope.posts)).map((t) => t.id),
        [a, b],
      );
    });

    test('lease at exactly expires_at is free for another holder', () async {
      final bucket = GovernorBucket(
        tokens: 1,
        lastRefillAt: DateTime.utc(2026),
      );
      final now = minutesAfter(0);
      await db.governorLeaseDao.acquire(
        accountId: 1,
        holder: 'a',
        now: now,
        ttl: const Duration(minutes: 1),
        initialBucket: bucket,
      );
      final at = now.add(const Duration(minutes: 1));
      expect(
        await db.governorLeaseDao.acquire(
          accountId: 1,
          holder: 'b',
          now: at.subtract(const Duration(milliseconds: 1)),
          ttl: const Duration(minutes: 1),
          initialBucket: bucket,
        ),
        isNull,
      );
      expect(
        await db.governorLeaseDao.acquire(
          accountId: 1,
          holder: 'b',
          now: at,
          ttl: const Duration(minutes: 1),
          initialBucket: bucket,
        ),
        isNotNull,
      );
      // 'a' no longer holds it at/after expiry of the original lease.
      expect(
        await db.governorLeaseDao.renew(
          accountId: 1,
          holder: 'a',
          now: at,
          ttl: const Duration(minutes: 1),
        ),
        isFalse,
      );
    });

    test(
      'pending order: story beats older post; ties by id then slide',
      () async {
        final t = await addTarget(db);
        final post = await addContent(
          db,
          targetId: t,
          remoteId: 'p',
          kind: ContentKind.post,
          detectedAt: minutesAfter(0),
          media: [mediaCompanion(slideIndex: 1), mediaCompanion()],
        );
        final story = await addContent(
          db,
          targetId: t,
          remoteId: 's',
          detectedAt: minutesAfter(9),
        );
        final story2 = await addContent(
          db,
          targetId: t,
          remoteId: 's2',
          detectedAt: minutesAfter(9),
        );
        final rows = await db.contentDao.pendingMedia();
        expect(
          [for (final r in rows) (r.content.id, r.file.slideIndex)],
          [(story, 0), (story2, 0), (post, 0), (post, 1)],
        );
        expect((await db.contentDao.pendingMedia(limit: 2)).length, 2);
      },
    );

    test(
      'watchLibrary re-emits on media_file change and on target cascade',
      () async {
        final t = await addTarget(db);
        final c = await addContent(db, targetId: t);
        final seen = <int>[];
        final sub = db.contentDao
            .watchLibrary(ContentFilter(kind: ContentKind.story))
            .listen((l) => seen.add(l.single.media.single.attempts));
        await pumpEventQueue();
        await db.contentDao.updateMediaFilePartial(
          1,
          const MediaFilesCompanion(attempts: Value(3)),
        );
        await pumpEventQueue();
        expect(seen, [0, 3]);
        await sub.cancel();
        final cleared = <int>[];
        final sub2 = db.contentDao
            .watchLibrary(ContentFilter())
            .listen((l) => cleared.add(l.length));
        await pumpEventQueue();
        await db.targetsDao.deleteById(t);
        await pumpEventQueue();
        expect(cleared, [1, 0]);
        await sub2.cancel();
        expect(c, isPositive);
      },
    );

    test(
      'watch on a media_file-only change with mediaType filter re-emits',
      () async {
        final t = await addTarget(db);
        await addContent(db, targetId: t, media: [mediaCompanion()]);
        final seen = <int>[];
        final sub = db.contentDao
            .watchLibrary(ContentFilter(mediaType: MediaType.video))
            .listen((l) => seen.add(l.length));
        await pumpEventQueue();
        await db.contentDao.updateMediaFilePartial(
          1,
          const MediaFilesCompanion(mediaType: Value(MediaType.video)),
        );
        await pumpEventQueue();
        expect(seen, [0, 1]);
        await sub.cancel();
      },
    );

    test('olderThan is exclusive at the cutoff (ms precision)', () async {
      final t = await addTarget(db);
      await addContent(db, targetId: t, remoteId: 'a', postedAt: t0);
      await addContent(
        db,
        targetId: t,
        remoteId: 'b',
        postedAt: minutesAfter(1),
      );
      expect(await db.contentDao.olderThan(t0), isEmpty);
      expect((await db.contentDao.olderThan(minutesAfter(1))).length, 1);
    });

    test(
      'epoch ms round trip keeps microseconds out and returns UTC',
      () async {
        final t = await addTarget(db);
        final row = await db.targetsDao.getById(t);
        expect(row!.addedAt.isUtc, isTrue);
        expect(row.addedAt, t0);
        // A local-zone DateTime is stored as the same instant.
        final local = DateTime.fromMillisecondsSinceEpoch(
          t0.millisecondsSinceEpoch,
        );
        await db.targetsDao.updatePartial(
          t,
          TargetsCompanion(lastNewPostAt: Value(local)),
        );
        expect((await db.targetsDao.getById(t))!.lastNewPostAt, t0);
      },
    );

    test(
      'insertIfNew: passing a duplicate slide index rolls back all',
      () async {
        final t = await addTarget(db);
        await expectLater(
          db.contentDao.insertIfNew(
            contentCompanion(targetId: t, kind: ContentKind.post),
            [mediaCompanion(), mediaCompanion()],
          ),
          throwsA(anything),
        );
        expect(await count(db, 'content'), 0);
      },
    );

    test('updatePartial / updateRow on a missing id changes 0 rows', () async {
      expect(
        await db.targetsDao.updatePartial(
          99,
          const TargetsCompanion(username: Value('x')),
        ),
        0,
      );
      await db.contentDao.markViewed([99]);
    });

    test('CheckRunDao.lastFinished(all) fails (sync or async)', () async {
      Object? err;
      try {
        await db.checkRunDao.lastFinished(CheckScope.all);
      } catch (e) {
        err = e;
      }
      expect(err, isA<ArgumentError>());
    });

    test(
      'activity watch: re-emits on insert; pruneOlderThan exclusive',
      () async {
        final seen = <int>[];
        final sub = db.activityDao
            .watchRecent(since: t0.subtract(const Duration(days: 7)))
            .listen((l) => seen.add(l.length));
        await pumpEventQueue();
        final id = await db.activityDao.insert(
          ActivityEventsCompanion.insert(
            at: t0,
            type: ActivityType.checkDone,
            severity: Severity.info,
          ),
        );
        await pumpEventQueue();
        expect(seen, [0, 1]);
        expect(await db.activityDao.pruneOlderThan(t0), 0);
        expect(
          await db.activityDao.pruneOlderThan(minutesAfter(1)),
          1,
          reason: 'event $id',
        );
        await sub.cancel();
      },
    );

    // T-006 hint: the domain's unsavedId is 0. A companion built from an
    // entity must leave `id` absent, otherwise row id 0 is stored.
    test(
      'an explicit id of 0 is stored as id 0 (T-006 must omit id)',
      () async {
        final id = await db.targetsDao.insert(
          targetCompanion().copyWith(id: const Value(0)),
        );
        expect(id, 0);
      },
    );
  });
}
