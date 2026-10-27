import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    TestProfileTable,
    SessionTable,
    AnswerTable,
    MistakeCardTable,
    CapturedQuestionTable,
    CompanyTestLogTable,
    AppSettingTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Naik setiap kali skema berubah; tiap kenaikan menambah langkah di
  /// [migration] dan satu test migrasi (docs/03-data-model.md, "Migrasi").
  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: waktu jawaban untuk penghitung "soal dikerjakan hari ini".
          if (from < 2) await m.addColumn(answerTable, answerTable.dijawab);
          // Tabel v1.1 dan v1.3 (knowledge_progress, cv_profile,
          // interview_session) ditambahkan di sini oleh tugas fiturnya.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
