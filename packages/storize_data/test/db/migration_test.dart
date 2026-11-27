import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_data/repo/repo.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 to v2 keeps targets and adds the history defaults', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO target (platform, remote_user_id, username, category, '
      'status, posts_watermark_at, added_at) '
      "VALUES ('INSTAGRAM', 'u-1', 'old_user', 'PUBLIC', 'ACTIVE', 1000, 2000)",
    );
    final db = StorizeDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final repo = DriftTargetRepo(db);
    final t = (await repo.getByRemoteUserId(PlatformId.instagram, 'u-1'))!;
    expect(t.username, 'old_user');
    expect(t.historyRange, HistoryRange.none);
    expect(t.historySince, isNull);
    expect(t.historyProgress, isNull);
    expect(t.highlightsEnabled, isFalse);
  });

  test('history fields and highlight kind round-trip on v2', () async {
    final db = StorizeDatabase.forTesting(await verifier.startAt(2));
    addTearDown(db.close);
    final repo = DriftTargetRepo(db);
    final at = DateTime.utc(2026, 11, 24, 9);
    final stored = await repo.insert(
      Target(
        id: Target.unsavedId,
        platform: PlatformId.instagram,
        remoteUserId: 'u-2',
        username: 'new_user',
        category: TargetCategory.public,
        postsWatermarkAt: at,
        addedAt: at,
        historyRange: HistoryRange.since,
        historySince: DateTime.utc(2026),
        highlightsEnabled: true,
        historyProgress: HistoryProgress(
          state: HistoryState.running,
          cursor: 'c1',
          fetched: 12,
          oldestSeenAt: DateTime.utc(2026, 5),
          updatedAt: at,
        ),
      ),
    );
    final back = (await repo.getById(stored.id))!;
    expect(back, stored);
    expect(back.historyProgress?.cursor, 'c1');
    expect(back.historyProgress?.fetched, 12);

    await repo.update(back.copyWith(historyProgress: null));
    expect((await repo.getById(stored.id))!.historyProgress, isNull);
    expect(ContentKind.fromDb('HIGHLIGHT'), ContentKind.highlight);
  });

  test('v2 to v3 keeps content and adds the detail columns', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase
      ..execute(
        'INSERT INTO target (id, platform, remote_user_id, username, '
        'category, status, posts_watermark_at, added_at) VALUES (1, '
        "'INSTAGRAM', 'u-1', 'old_user', 'PUBLIC', 'ACTIVE', 1000, 2000)",
      )
      ..execute(
        'INSERT INTO content (target_id, kind, remote_id, posted_at, '
        "caption, detected_at, status) VALUES (1, 'POST', 'ZZFAKE_old', 3000, "
        "'ZZFAKE_cap', 4000, 'PENDING')",
      );
    final db = StorizeDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final repo = DriftContentRepo(db);
    final old = (await repo.listByTarget(1)).single.content;
    expect(old.caption, 'ZZFAKE_cap');
    expect(old.locationName, isNull);
    expect(old.taggedUsernames, isEmpty);
  });

  test('v3 to v4 keeps targets and adds the check-result columns', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO target (id, platform, remote_user_id, username, '
      'category, status, posts_watermark_at, added_at) VALUES (1, '
      "'INSTAGRAM', 'u-1', 'old_user', 'PUBLIC', 'ACTIVE', 1000, 2000)",
    );
    final db = StorizeDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final repo = DriftTargetRepo(db);
    final old = (await repo.getById(1))!;
    expect(old.username, 'old_user');
    expect(old.lastSuccessAt, isNull);
    expect(old.lastCheckOutcome, isNull);
    expect(old.lastCheckCode, isNull);

    final at = DateTime.utc(2026, 11, 27, 8);
    await repo.update(
      old.copyWith(
        lastSuccessAt: at,
        lastCheckOutcome: TargetCheckOutcome.failed,
        lastCheckCode: 'network',
      ),
    );
    final back = (await repo.getById(1))!;
    expect(back.lastSuccessAt, at);
    expect(back.lastCheckOutcome, TargetCheckOutcome.failed);
    expect(back.lastCheckCode, 'network');
  });

  test('a database from a newer build is refused (v99)', () async {
    final db = StorizeDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 99'),
      ),
    );
    addTearDown(db.close);
    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(
        isA<DatabaseTooNew>()
            .having((e) => e.found, 'found', 99)
            .having((e) => e.supported, 'supported', db.schemaVersion),
      ),
    );
  });
}
