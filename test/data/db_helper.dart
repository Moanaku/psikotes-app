import 'package:drift/native.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/data/repositories/profile_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/session_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';

/// Database SQLite di memori. Di Windows, `sqlite3.dll` harus ada di PATH
/// (Linux dan macOS memakai pustaka sistem).
AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

final DateTime t0 = DateTime.utc(2026, 10, 1, 8);

TestProfile profile({
  String nama = 'QA, CCAT',
  bool aktif = false,
  int? id,
  DateTime? dibuat,
}) =>
    TestProfile(
      id: id,
      nama: nama,
      role: ProfileRole.qa,
      formatTes: TestFormat.ccat,
      tanggalTes: DateTime.utc(2026, 11, 3),
      aktif: aktif,
      blueprint: const ProfileBlueprint(
        subtes: [
          SubtestSpec(kategori: 'verbal', aktif: true, jumlah: 20, menit: 8),
          SubtestSpec(kategori: 'figural', aktif: false, jumlah: 10, menit: 5),
        ],
        bobot: {'verbal': 0.6, 'figural': 0.4},
      ),
      cvTeks: 'ringkasan CV',
      dibuat: dibuat ?? t0,
    );

SessionPlan plan({int n = 4}) => SessionPlan(
      items: [
        for (var i = 0; i < n; i++)
          PlanItem(
            type: QuestionType.figMtx,
            seed: 100 + i,
            difficulty: Difficulty.medium,
            genVersi: 1,
            subtes: 'figural',
          ),
      ],
      subtes: [SubtestPlan(kategori: 'figural', jumlah: n, menit: 5)],
    );

AnswerRecord answer(
  int sessionId, {
  int seed = 100,
  bool benar = true,
  int? pilih = 1,
  String tipe = 'FIG-MTX',
  AnswerSource sumber = AnswerSource.engine,
  int? refId,
  int? posisi,
}) =>
    AnswerRecord(
      sessionId: sessionId,
      posisi: posisi ?? seed,
      tipe: tipe,
      kategori: 'figural',
      seed: seed,
      kesulitan: Difficulty.medium,
      genVersi: 1,
      sumber: sumber,
      refId: refId,
      opsiDipilih: pilih,
      benar: benar,
      durasiMs: 12000,
      label: benar ? SpeedLabel.benarCepat : SpeedLabel.salahLambat,
    );

/// Profil dan sesi siap pakai.
Future<({int profileId, int sessionId})> seedSession(AppDatabase db,
    {int items = 4}) async {
  final profileId = await DriftProfileRepository(db).save(profile());
  final sessionId = await DriftSessionRepository(db).start(NewSession(
    profileId: profileId,
    mode: SessionMode.latihan,
    plan: plan(n: items),
    mulai: t0,
  ));
  return (profileId: profileId, sessionId: sessionId);
}
