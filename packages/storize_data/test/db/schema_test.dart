import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';

import 'db_test_helpers.dart';
import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the committed v2 dump', () async {
    final connection = await verifier.startAt(2);
    final db = StorizeDatabase(connection);
    addTearDown(db.close);
    // Opens the database and compares every table, column and index with the
    // dump in drift_schemas/drift_schema_v2.json.
    await verifier.migrateAndValidate(db, 2);
  });

  test('foreign keys are on after open (beforeOpen pragma)', () async {
    final db = newDb();
    addTearDown(db.close);
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });
}
