// QA scratch rules: raw SQL strings and printed measurements are intended.
// ignore_for_file: avoid_print, lines_longer_than_80_chars, use_is_even_rather_than_modulo
// QA (T-005): NFR-12 timing and query plans with ~5,000 content rows and
// ~2 media files each. Thresholds are generous; the numbers are printed.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late Directory dir;
  late StorizeDatabase db;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('storize_qa_perf');
    db = StorizeDatabase.forTesting(
      NativeDatabase(
        File('${dir.path}/perf.sqlite'),
        setup: (r) => r.execute('PRAGMA journal_mode = WAL;'),
      ),
    );
    for (var t = 1; t <= 50; t++) {
      await addTarget(db, remoteUserId: 'u$t', username: 'user$t');
    }
    final base = t0.millisecondsSinceEpoch;
    await db.batch((b) {
      for (var i = 0; i < 5000; i++) {
        final kind = i % 2 == 0 ? 'STORY' : 'POST';
        b.customStatement(
          'INSERT INTO content (target_id, kind, remote_id, posted_at, '
          "detected_at, status, slide_count) VALUES (${1 + i % 50}, '$kind', "
          "'r$i', ${base - i * 60000}, ${base - i * 60000}, 'DONE', 2)",
        );
      }
    });
    await db.batch((b) {
      for (var i = 1; i <= 5000; i++) {
        for (var s = 0; s < 2; s++) {
          // 1 in 20 media files is pending.
          final st = (i * 2 + s) % 20 == 0 ? 'PENDING' : 'DONE';
          final type = s == 0 ? 'PHOTO' : 'VIDEO';
          b.customStatement(
            'INSERT INTO media_file (content_id, slide_index, media_type, '
            "source_url, status, size_bytes) VALUES ($i, $s, '$type', 'u', "
            "'$st', 1000)",
          );
        }
      }
    });
    await db.customStatement('ANALYZE');
  });

  tearDownAll(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<List<String>> plan(Query<HasResultSet, dynamic> q) async {
    final c = q.constructQuery();
    final rows = await db
        .customSelect(
          'EXPLAIN QUERY PLAN ${c.sql}',
          variables: c.introducedVariables,
        )
        .get();
    return [for (final r in rows) r.read<String>('detail')];
  }

  final filters = <String, ContentFilter>{
    'kind=POST': ContentFilter(kind: ContentKind.post),
    'kind=STORY + target set(5)': ContentFilter(
      kind: ContentKind.story,
      targetIds: const {1, 2, 3, 4, 5},
    ),
    'kind=POST + single target': ContentFilter(
      kind: ContentKind.post,
      targetIds: const {3},
    ),
    'kind + 7-day range': ContentFilter(
      kind: ContentKind.post,
      from: t0.subtract(const Duration(days: 2)),
      to: t0,
    ),
    'kind + mediaType=VIDEO': ContentFilter(
      kind: ContentKind.post,
      mediaType: MediaType.video,
    ),
    'all fields': ContentFilter(
      kind: ContentKind.story,
      targetIds: const {1, 2, 3},
      from: t0.subtract(const Duration(days: 3)),
      to: t0,
      mediaType: MediaType.photo,
      statuses: const {ContentStatus.done},
    ),
    'EMPTY filter (no kind, no targets)': ContentFilter(),
    'targets only (no kind)': ContentFilter(targetIds: const {1, 2}),
  };

  for (final e in filters.entries) {
    test('library ${e.key}', () async {
      final plans = await plan(db.contentDao.libraryQuery(e.value));
      final sw = Stopwatch()..start();
      final rows = await db.contentDao.getLibrary(e.value);
      sw.stop();
      print(
        'QA PERF library [${e.key}] rows=${rows.length} '
        '${sw.elapsedMilliseconds} ms\n  plan: ${plans.join(' | ')}',
      );
      // 2000 ms: generous for loaded CI/dev machines (CHECKPOINT-3 F-1);
      // the index still makes a real regression fail.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  }

  test('pending media', () async {
    final plans = await plan(db.contentDao.pendingMediaQuery());
    final sw = Stopwatch()..start();
    final rows = await db.contentDao.pendingMedia();
    sw.stop();
    final sw2 = Stopwatch()..start();
    final lim = await db.contentDao.pendingMedia(limit: 20);
    sw2.stop();
    print(
      'QA PERF pending rows=${rows.length} ${sw.elapsedMilliseconds} ms; '
      'limit20=${lim.length} ${sw2.elapsedMilliseconds} ms\n'
      '  plan: ${plans.join(' | ')}',
    );
    // 2000 ms: generous for loaded CI/dev machines (CHECKPOINT-3 F-1);
    // the index still makes a real regression fail.
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('other reads', () async {
    for (final (name, run) in <(String, Future<Object?> Function())>[
      ('storageBytesByTarget', () => db.contentDao.storageBytesByTarget()),
      (
        'olderThan(1 day)',
        () => db.contentDao.olderThan(t0.subtract(const Duration(days: 1))),
      ),
      ('listByTarget(3)', () => db.contentDao.listByTarget(3)),
      (
        'existingRemoteIds',
        () => db.contentDao.existingRemoteIds(3, ContentKind.post, [
          'r1',
          'r3',
          'r53',
          'zz',
        ]),
      ),
      (
        'getByIds(200)',
        () => db.contentDao.getByIds([for (var i = 1; i <= 200; i++) i]),
      ),
    ]) {
      final sw = Stopwatch()..start();
      await run();
      print('QA PERF $name ${sw.elapsedMilliseconds} ms');
    }
  });

  test('watchLibrary first emission and re-emission after one update', () async {
    final f = ContentFilter(kind: ContentKind.post);
    final sw = Stopwatch()..start();
    final it = StreamIterator(db.contentDao.watchLibrary(f));
    await it.moveNext();
    final first = sw.elapsedMilliseconds;
    sw.reset();
    await db.contentDao.markViewed([2]);
    await it.moveNext();
    print(
      'QA PERF watchLibrary first=$first ms re-emit=${sw.elapsedMilliseconds} ms',
    );
    await it.cancel();
  });
}
