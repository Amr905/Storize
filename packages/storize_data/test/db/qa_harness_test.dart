// QA (T-005): the migration harness must notice drift between the dump and
// the database, otherwise "matches v1" proves nothing.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';

import 'generated/schema.dart';

void main() {
  test(
    'harness fails when an index is missing from the opened database',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(2);
      final db = StorizeDatabase(connection);
      addTearDown(db.close);
      await db.customStatement('SELECT 1'); // open (creates nothing, v2 exists)
      await db.customStatement('DROP INDEX idx_content_kind_posted_at');
      await expectLater(verifier.migrateAndValidate(db, 2), throwsA(anything));
    },
  );

  test('harness fails when a column is dropped', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(2);
    final db = StorizeDatabase(connection);
    addTearDown(db.close);
    await db.customStatement('SELECT 1');
    await db.customStatement('ALTER TABLE media_file DROP COLUMN thumb_path');
    await expectLater(verifier.migrateAndValidate(db, 2), throwsA(anything));
  });
}
