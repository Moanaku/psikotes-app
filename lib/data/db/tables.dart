import 'package:drift/drift.dart';

/// Tabel v1 (docs/03-data-model.md). Semua waktu berupa epoch milidetik UTC
/// (INTEGER), diubah di lapisan repository. Kode teks (role, mode, ...)
/// divalidasi lewat enum di domain.

@DataClassName('ProfileRow')
class TestProfileTable extends Table {
  @override
  String get tableName => 'test_profile';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get nama => text()();
  TextColumn get role => text()();
  TextColumn get formatTes => text()();
  IntColumn get tanggalTes => integer().nullable()();
  BoolColumn get aktif => boolean().withDefault(const Constant(false))();
  TextColumn get blueprintJson => text()();
  TextColumn get cvTeks => text().nullable()();
  IntColumn get dibuat => integer()();
}

@DataClassName('SessionRow')
@TableIndex(name: 'idx_session_profile_mulai', columns: {#profileId, #mulai})
@TableIndex(name: 'idx_session_selesai', columns: {#selesai})
class SessionTable extends Table {
  @override
  String get tableName => 'session';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(TestProfileTable, #id)();
  TextColumn get mode => text()();
  TextColumn get rencanaJson => text()();
  IntColumn get mulai => integer()();
  IntColumn get selesai => integer().nullable()();
  IntColumn get deadline => integer().nullable()();
  IntColumn get posisi => integer().withDefault(const Constant(0))();
  RealColumn get skor => real().nullable()();
}

@DataClassName('AnswerRow')
@TableIndex(
  name: 'idx_answer_session_posisi',
  columns: {#sessionId, #posisi},
  unique: true,
)
@TableIndex(name: 'idx_answer_tipe_id', columns: {#tipe, #id})
@TableIndex(name: 'idx_answer_kategori_id', columns: {#kategori, #id})
class AnswerTable extends Table {
  @override
  String get tableName => 'answer';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(SessionTable, #id)();
  IntColumn get posisi => integer()();
  TextColumn get tipe => text()();
  TextColumn get kategori => text()();
  IntColumn get seed => integer()();
  TextColumn get kesulitan => text()();
  IntColumn get genVersi => integer()();
  TextColumn get sumber => text()();
  IntColumn get refId => integer().nullable()();
  IntColumn get opsiDipilih => integer().nullable()();
  BoolColumn get benar => boolean()();
  IntColumn get durasiMs => integer()();
  TextColumn get label => text()();

  /// Waktu jawaban terakhir dicatat (ms UTC). Null pada jawaban sebelum skema
  /// v2 dan pada soal yang dilewati.
  IntColumn get dijawab => integer().nullable()();
}

@DataClassName('MistakeCardRow')
@TableIndex(name: 'idx_mistake_status_due', columns: {#status, #jatuhTempo})
class MistakeCardTable extends Table {
  @override
  String get tableName => 'mistake_card';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get tipe => text()();
  TextColumn get kategori => text()();
  IntColumn get seed => integer().nullable()();
  TextColumn get sumber => text()();
  IntColumn get refId => integer().nullable()();
  IntColumn get jatuhTempo => integer()();
  IntColumn get intervalHari => integer()();
  IntColumn get streakBenar => integer()();
  TextColumn get status => text()();
  IntColumn get dibuat => integer()();
}

@DataClassName('CompanyLogRow')
class CompanyTestLogTable extends Table {
  @override
  String get tableName => 'company_test_log';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get perusahaan => text()();
  IntColumn get tanggal => integer()();
  TextColumn get subtesJson => text()();
  TextColumn get tipeBaruJson => text()();
  TextColumn get catatan => text()();
}

@DataClassName('CapturedQuestionRow')
class CapturedQuestionTable extends Table {
  @override
  String get tableName => 'captured_question';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get teks => text()();
  TextColumn get opsiJson => text()();
  IntColumn get kunci => integer()();
  TextColumn get pembahasan => text().nullable()();
  TextColumn get kategori => text()();
  TextColumn get fotoPath => text().nullable()();
  IntColumn get companyLogId =>
      integer().nullable().references(CompanyTestLogTable, #id)();
  IntColumn get dibuat => integer()();
}

@DataClassName('AppSettingRow')
class AppSettingTable extends Table {
  @override
  String get tableName => 'app_setting';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('KnowledgeProgressRow')
class KnowledgeProgressTable extends Table {
  @override
  String get tableName => 'knowledge_progress';

  /// Id butir di `knowledge_bank.json`, mis. `KB-QA-D-001`.
  TextColumn get butirId => text()();
  TextColumn get level => text()();

  /// Kapan terakhir dinilai (ms UTC).
  IntColumn get terakhir => integer()();
  BoolColumn get dikuasai => boolean()();

  @override
  Set<Column> get primaryKey => {butirId};
}
