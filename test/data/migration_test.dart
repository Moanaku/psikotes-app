import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('skema v1 yang dibuat database sama dengan drift_schemas/ v1', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);
  });

  test('database v1 yang sudah berisi data tetap terbaca setelah dibuka',
      () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute('''
      INSERT INTO test_profile
        (id, nama, role, format_tes, aktif, blueprint_json, dibuat)
      VALUES (7, 'Profil lama', 'qa', 'ccat', 1, '{"subtes":[],"bobot":{}}', 1760000000000)
    ''');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);

    final p = await DriftProfileRepository(db).active();
    expect(p!.id, 7);
    expect(p.nama, 'Profil lama');
    expect(p.dibuat, DateTime.utc(2025, 10, 9, 8, 53, 20));
  });

  test('versi skema di kode sama dengan berkas terakhir di drift_schemas/', () {
    expect(AppDatabase.currentSchemaVersion, GeneratedHelper.versions.last,
        reason:
            'jalankan drift_dev schema dump dan generate setelah mengubah skema');
  });
}
