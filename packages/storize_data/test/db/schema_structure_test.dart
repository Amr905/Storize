// Checks the created schema against TECH_SPEC §3, independently of the
// generated dump: columns, NOT NULL, defaults, FK actions, UNIQUE and indexes.
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';

import 'db_test_helpers.dart';

typedef _Col = ({String type, bool notNull});

void main() {
  late StorizeDatabase db;

  setUp(() => db = newDb());
  tearDown(() => db.close());

  Future<Map<String, _Col>> columns(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final r in rows)
        r.read<String>('name'): (
          type: r.read<String>('type').toUpperCase(),
          notNull: r.read<int>('notnull') == 1,
        ),
    };
  }

  Future<String> tableSql(String table) async {
    final row = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable<String>(table)],
        )
        .getSingle();
    return row.read<String>('sql');
  }

  Future<Map<String, String>> foreignKeys(String table) async {
    final rows = await db.customSelect('PRAGMA foreign_key_list($table)').get();
    return {
      for (final r in rows)
        '${r.read<String>('from')}->${r.read<String>('table')}': r.read<String>(
          'on_delete',
        ),
    };
  }

  group('tables and columns (TECH_SPEC §3)', () {
    test('exactly the seven tables exist', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(rows.map((r) => r.read<String>('name')).toSet(), {
        'login_account',
        'target',
        'content',
        'media_file',
        'check_run',
        'activity_event',
        'governor_lease',
      });
    });

    final expected = <String, Map<String, String>>{
      'login_account': {
        'id': 'INTEGER',
        'platform': 'TEXT',
        'remote_user_id': 'TEXT',
        'username': 'TEXT',
        'status': 'TEXT',
        'status_reason': 'TEXT',
        'connected_at': 'INTEGER',
        'last_success_at': 'INTEGER',
        'user_agent': 'TEXT',
      },
      'target': {
        'id': 'INTEGER',
        'platform': 'TEXT',
        'remote_user_id': 'TEXT',
        'username': 'TEXT',
        'display_name': 'TEXT',
        'avatar_path': 'TEXT',
        'category': 'TEXT',
        'note': 'TEXT',
        'status': 'TEXT',
        'status_reason': 'TEXT',
        'is_private': 'INTEGER',
        'track_stories': 'INTEGER',
        'track_posts': 'INTEGER',
        'track_reels': 'INTEGER',
        'posts_watermark_at': 'INTEGER',
        'login_account_id': 'INTEGER',
        'added_at': 'INTEGER',
        'last_stories_check_at': 'INTEGER',
        'last_posts_check_at': 'INTEGER',
        'last_new_story_at': 'INTEGER',
        'last_new_post_at': 'INTEGER',
        // Schema v2 (TECH_SPEC §17).
        'history_range': 'TEXT',
        'history_since': 'INTEGER',
        'history_state': 'TEXT',
        'history_cursor': 'TEXT',
        'history_fetched': 'INTEGER',
        'history_oldest_seen_at': 'INTEGER',
        'history_updated_at': 'INTEGER',
        'highlights_enabled': 'INTEGER',
      },
      'content': {
        'id': 'INTEGER',
        'target_id': 'INTEGER',
        'kind': 'TEXT',
        'remote_id': 'TEXT',
        'shortcode': 'TEXT',
        'post_type': 'TEXT',
        'posted_at': 'INTEGER',
        'expires_at': 'INTEGER',
        'caption': 'TEXT',
        'location_name': 'TEXT',
        'tagged_usernames': 'TEXT',
        'slide_count': 'INTEGER',
        'is_close_friends': 'INTEGER',
        'extras_json': 'TEXT',
        'detected_at': 'INTEGER',
        'status': 'TEXT',
        'viewed': 'INTEGER',
      },
      'media_file': {
        'id': 'INTEGER',
        'content_id': 'INTEGER',
        'slide_index': 'INTEGER',
        'media_type': 'TEXT',
        'source_url': 'TEXT',
        'status': 'TEXT',
        'attempts': 'INTEGER',
        'content_uri': 'TEXT',
        'relative_path': 'TEXT',
        'display_name': 'TEXT',
        'thumb_path': 'TEXT',
        'width': 'INTEGER',
        'height': 'INTEGER',
        'duration_ms': 'INTEGER',
        'size_bytes': 'INTEGER',
        'downloaded_at': 'INTEGER',
      },
      'check_run': {
        'id': 'INTEGER',
        'scope': 'TEXT',
        'trigger': 'TEXT',
        'started_at': 'INTEGER',
        'finished_at': 'INTEGER',
        'result': 'TEXT',
        'mode': 'TEXT',
        'targets_checked': 'INTEGER',
        'new_items': 'INTEGER',
        'error_code': 'TEXT',
      },
      'activity_event': {
        'id': 'INTEGER',
        'at': 'INTEGER',
        'type': 'TEXT',
        'severity': 'TEXT',
        'target_id': 'INTEGER',
        'check_run_id': 'INTEGER',
        'count': 'INTEGER',
        'payload_json': 'TEXT',
      },
      'governor_lease': {
        'login_account_id': 'INTEGER',
        'holder': 'TEXT',
        'expires_at': 'INTEGER',
        'tokens': 'REAL',
        'last_refill_at': 'INTEGER',
        'backoff_until': 'INTEGER',
        'backoff_multiplier': 'REAL',
      },
    };

    for (final entry in expected.entries) {
      test('${entry.key} has exactly the §3 columns and types', () async {
        final cols = await columns(entry.key);
        expect({
          for (final c in cols.entries) c.key: c.value.type,
        }, entry.value);
      });
    }

    test('NOT NULL columns named by §3 and by the domain entities', () async {
      final target = await columns('target');
      for (final name in [
        'remote_user_id',
        'category',
        'posts_watermark_at',
        'platform',
        'username',
        'status',
        'added_at',
      ]) {
        expect(target[name]!.notNull, isTrue, reason: 'target.$name');
      }
      expect((await columns('login_account'))['remote_user_id']!.notNull, true);
      expect((await columns('content'))['remote_id']!.notNull, true);
      expect((await columns('content'))['posted_at']!.notNull, true);
      expect((await columns('target'))['login_account_id']!.notNull, false);
      expect((await columns('activity_event'))['target_id']!.notNull, false);
      expect((await columns('activity_event'))['check_run_id']!.notNull, false);
    });

    test('track flags default to 1 and track_reels exists', () async {
      final sql = await tableSql('target');
      for (final flag in ['track_stories', 'track_posts', 'track_reels']) {
        expect(sql, contains('"$flag" INTEGER NOT NULL DEFAULT 1'));
      }
    });
  });

  group('constraints', () {
    test('UNIQUE keys', () async {
      expect(
        await tableSql('target'),
        contains('UNIQUE ("platform", "remote_user_id")'),
      );
      expect(
        await tableSql('content'),
        contains('UNIQUE ("target_id", "kind", "remote_id")'),
      );
      expect(
        await tableSql('media_file'),
        contains('UNIQUE ("content_id", "slide_index")'),
      );
      expect(await tableSql('login_account'), contains('UNIQUE'));
    });

    test('CHECK constraints are in the table SQL', () async {
      expect(
        await tableSql('target'),
        contains('CHECK (track_stories + track_posts + track_reels >= 1)'),
      );
      expect(
        await tableSql('check_run'),
        contains("CHECK (scope IN ('STORIES', 'POSTS'))"),
      );
    });

    test('FK actions', () async {
      expect(await foreignKeys('target'), {
        'login_account_id->login_account': 'SET NULL',
      });
      expect(await foreignKeys('content'), {'target_id->target': 'CASCADE'});
      expect(await foreignKeys('media_file'), {
        'content_id->content': 'CASCADE',
      });
      expect(await foreignKeys('activity_event'), {
        'target_id->target': 'SET NULL',
        'check_run_id->check_run': 'SET NULL',
      });
    });
  });

  group('indexes', () {
    Future<Map<String, String>> indexes() async {
      final rows = await db
          .customSelect(
            "SELECT name, tbl_name FROM sqlite_master WHERE type='index' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      return {
        for (final r in rows)
          r.read<String>('name'): r.read<String>('tbl_name'),
      };
    }

    Future<List<({String name, bool desc})>> indexColumns(String index) async {
      final rows = await db.customSelect('PRAGMA index_xinfo($index)').get();
      return [
        for (final r in rows)
          if (r.read<int>('key') == 1)
            (name: r.read<String>('name'), desc: r.read<int>('desc') == 1),
      ];
    }

    test('the six §3 indexes exist on the right tables', () async {
      expect(await indexes(), {
        'idx_target_status': 'target',
        'idx_content_kind_posted_at': 'content',
        'idx_content_target_kind_posted_at': 'content',
        'idx_media_file_status': 'media_file',
        'idx_check_run_scope_started_at': 'check_run',
        'idx_activity_event_at': 'activity_event',
      });
    });

    test('column order and DESC flags', () async {
      expect(await indexColumns('idx_target_status'), [
        (name: 'status', desc: false),
      ]);
      expect(await indexColumns('idx_content_kind_posted_at'), [
        (name: 'kind', desc: false),
        (name: 'posted_at', desc: true),
      ]);
      expect(await indexColumns('idx_content_target_kind_posted_at'), [
        (name: 'target_id', desc: false),
        (name: 'kind', desc: false),
        (name: 'posted_at', desc: true),
      ]);
      expect(await indexColumns('idx_media_file_status'), [
        (name: 'status', desc: false),
      ]);
      expect(await indexColumns('idx_check_run_scope_started_at'), [
        (name: 'scope', desc: false),
        (name: 'started_at', desc: false),
      ]);
      expect(await indexColumns('idx_activity_event_at'), [
        (name: 'at', desc: true),
      ]);
    });
  });
}
