// AC4: the Library and pending-media queries use indexes (EXPLAIN QUERY PLAN).
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'db_test_helpers.dart';

void main() {
  late StorizeDatabase db;

  setUp(() => db = newDb());
  tearDown(() => db.close());

  Future<List<String>> plan(Query<HasResultSet, dynamic> query) async {
    final context = query.constructQuery();
    final rows = await db
        .customSelect(
          'EXPLAIN QUERY PLAN ${context.sql}',
          variables: context.introducedVariables,
        )
        .get();
    return [for (final r in rows) r.read<String>('detail')];
  }

  void expectIndexed(List<String> details, {required String table}) {
    final reason = details.join('\n');
    expect(
      details.any(
        (d) => d.contains('USING INDEX') || d.contains('USING COVERING INDEX'),
      ),
      isTrue,
      reason: 'no index used:\n$reason',
    );
    // A full scan prints "SCAN <table>" (also "SCAN <table> USING INDEX").
    expect(
      details.where((d) => RegExp('^SCAN $table\\b').hasMatch(d)),
      isEmpty,
      reason: 'full scan of $table:\n$reason',
    );
  }

  final from = DateTime.utc(2026, 11);
  final to = DateTime.utc(2026, 12);

  final libraryFilters = <String, ContentFilter>{
    'kind': ContentFilter(kind: ContentKind.story),
    'kind + date range': ContentFilter(
      kind: ContentKind.post,
      from: from,
      to: to,
    ),
    'kind + target set': ContentFilter(
      kind: ContentKind.story,
      targetIds: const {1, 2, 3},
    ),
    'kind + target set + date range + media type': ContentFilter(
      kind: ContentKind.post,
      targetIds: const {1, 2},
      from: from,
      to: to,
      mediaType: MediaType.video,
    ),
    'kind + media type': ContentFilter(
      kind: ContentKind.post,
      mediaType: MediaType.photo,
    ),
    'target set only': ContentFilter(targetIds: const {4}),
  };

  group('Library query', () {
    for (final entry in libraryFilters.entries) {
      test('${entry.key} uses an index and never scans content', () async {
        final details = await plan(db.contentDao.libraryQuery(entry.value));
        expectIndexed(details, table: 'content');
      });
    }

    test('kind filter picks the (kind, posted_at DESC) index', () async {
      final details = await plan(
        db.contentDao.libraryQuery(ContentFilter(kind: ContentKind.story)),
      );
      expect(
        details.any((d) => d.contains('idx_content_kind_posted_at')),
        isTrue,
        reason: details.join('\n'),
      );
    });

    test('kind + target set picks the target index', () async {
      final details = await plan(
        db.contentDao.libraryQuery(
          ContentFilter(kind: ContentKind.story, targetIds: const {1}),
        ),
      );
      expect(
        details.any((d) => d.contains('idx_content_target_kind_posted_at')),
        isTrue,
        reason: details.join('\n'),
      );
    });

    test('the media join uses an index on media_file', () async {
      final details = await plan(
        db.contentDao.libraryQuery(ContentFilter(kind: ContentKind.story)),
      );
      expectIndexed(details, table: 'media_file');
    });

    test(
      'control: a query with no usable index is detected as a scan',
      () async {
        final query = db.select(db.contents)
          ..where((c) => c.caption.equals('x'));
        final details = await plan(query);
        expect(details.any((d) => d.startsWith('SCAN content')), isTrue);
      },
    );
  });

  group('Pending media query', () {
    test('uses idx_media_file_status, with and without a limit', () async {
      for (final limit in [null, 10]) {
        final details = await plan(
          db.contentDao.pendingMediaQuery(limit: limit),
        );
        expect(
          details.any((d) => d.contains('idx_media_file_status')),
          isTrue,
          reason: details.join('\n'),
        );
        expectIndexed(details, table: 'media_file');
      }
    });
  });

  group('Other hot queries', () {
    test('activity feed uses idx_activity_event_at', () async {
      final query = db.select(db.activityEvents)
        ..where((e) => e.at.isBiggerOrEqualValue(0))
        ..orderBy([(e) => OrderingTerm.desc(e.at)]);
      expectIndexed(await plan(query), table: 'activity_event');
    });

    test('last finished run uses idx_check_run_scope_started_at', () async {
      final query = db.select(db.checkRuns)
        ..where((r) => r.scope.equalsValue(CheckScope.stories))
        ..orderBy([(r) => OrderingTerm.desc(r.startedAt)]);
      final details = await plan(query);
      expect(
        details.any((d) => d.contains('idx_check_run_scope_started_at')),
        isTrue,
        reason: details.join('\n'),
      );
    });

    test('target status filter uses idx_target_status', () async {
      final query = db.select(db.targets)
        ..where((t) => t.status.equalsValue(TargetStatus.active));
      final details = await plan(query);
      expect(
        details.any((d) => d.contains('idx_target_status')),
        isTrue,
        reason: details.join('\n'),
      );
    });
  });
}
