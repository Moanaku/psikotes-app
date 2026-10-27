import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/knowledge_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';

import 'package:simulator_psikotes_it/domain/models/knowledge.dart';

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

  test('v1 ke v2: kolom answer.dijawab ditambah, jawaban lama tetap terbaca',
      () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute('''
      INSERT INTO test_profile
        (id, nama, role, format_tes, aktif, blueprint_json, dibuat)
      VALUES (1, 'P', 'qa', 'ccat', 1, '{"subtes":[],"bobot":{}}', 1760000000000)
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO session (id, profile_id, mode, rencana_json, mulai, posisi)
      VALUES (1, 1, 'latihan', '{"items":[],"subtes":[]}', 1760000000000, 0)
    ''');
    schema.rawDatabase.execute('''
      INSERT INTO answer
        (id, session_id, posisi, tipe, kategori, seed, kesulitan, gen_versi,
         sumber, opsi_dipilih, benar, durasi_ms, label)
      VALUES (1, 1, 0, 'NUM-SEQ', 'numerik', 5, 'easy', 1, 'engine', 2, 1, 900,
              'benar_cepat')
    ''');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);

    final rows = await db.customSelect('SELECT dijawab FROM answer').get();
    expect(rows.single.readNullable<int>('dijawab'), isNull);
    final n = await DriftAnswerRepository(db).countAnswered(
      DateTime.utc(2025, 10, 9),
      DateTime.utc(2025, 10, 10),
    );
    expect(n, 1, reason: 'jawaban lama dihitung menurut waktu mulai sesi');
  });

  test('v2 ke v3: tabel knowledge_progress dibuat, data lama tetap ada',
      () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute('''
      INSERT INTO test_profile
        (id, nama, role, format_tes, aktif, blueprint_json, dibuat)
      VALUES (3, 'P', 'qa', 'ccat', 1, '{"subtes":[],"bobot":{}}', 1760000000000)
    ''');
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    expect((await DriftProfileRepository(db).active())!.id, 3);
    final repo = DriftKnowledgeRepository(db);
    expect(await repo.all(), isEmpty);
    await repo.save(KnowledgeProgress(
      butirId: 'KB-QA-D-001',
      level: KnowledgeLevel.dasar,
      terakhir: DateTime.utc(2026, 10, 22),
      dikuasai: true,
    ));
    expect((await repo.all()).keys, ['KB-QA-D-001']);
  });

  test('versi skema di kode sama dengan berkas terakhir di drift_schemas/', () {
    expect(AppDatabase.currentSchemaVersion, GeneratedHelper.versions.last,
        reason:
            'jalankan drift_dev schema dump dan generate setelah mengubah skema');
  });
}
