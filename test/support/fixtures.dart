import 'package:flutter/widgets.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/app/tab_shell.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/default_daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';

import 'fake_repositories.dart';
import 'pump_app.dart';

/// Profil aktif untuk test beranda dan katalog.
TestProfile activeProfile({
  int id = 1,
  String nama = 'QA, CCAT-style',
  ProfileRole role = ProfileRole.qa,
  TestFormat format = TestFormat.ccat,
  DateTime? tanggalTes,
  bool aktif = true,
  ProfileBlueprint? blueprint,
}) =>
    TestProfile(
      id: id,
      nama: nama,
      role: role,
      formatTes: format,
      tanggalTes: tanggalTes,
      aktif: aktif,
      blueprint: blueprint ?? ProfileTemplates.blueprint(role, format),
      dibuat: appNow,
    );

/// Kartu buku kesalahan jatuh tempo [offsetDays] hari dari [appNow].
MistakeCard card(
  int id, {
  int offsetDays = -1,
  CardStatus status = CardStatus.aktif,
}) =>
    MistakeCard(
      id: id,
      tipe: 'FIG-MTX',
      kategori: 'figural',
      seed: id,
      sumber: AnswerSource.engine,
      jatuhTempo: appNow.add(Duration(days: offsetDays)),
      intervalHari: 1,
      streakBenar: 0,
      status: status,
      dibuat: appNow.subtract(const Duration(days: 3)),
    );

CapturedQuestion captured(int id) => CapturedQuestion(
      id: id,
      teks: 'Soal $id',
      opsi: const ['a', 'b'],
      kunci: 0,
      kategori: 'verbal',
      dibuat: appNow,
    );

/// Model kelemahan tetap untuk menguji daftar "Kelemahan saat ini".
class FixedWeaknessModel implements WeaknessModel {
  const FixedWeaknessModel(this.entries);

  final List<WeaknessEntry> entries;

  @override
  Future<List<WeaknessEntry>> weakest(
    TestProfile profile,
    DateTime now, {
    int count = 3,
  }) async =>
      entries.take(count).toList();
}

const threeWeaknesses = FixedWeaknessModel([
  WeaknessEntry(type: QuestionType.figMtx, accuracy: 0.35, answered: 20),
  WeaknessEntry(type: QuestionType.numSeq, accuracy: 0.52, answered: 18),
  WeaknessEntry(type: QuestionType.logSyl, accuracy: 0.6, answered: 14),
]);

/// Perencana nyata di atas riwayat dan buku kesalahan kosong.
DailyPlanner emptyHistoryPlanner(Set<QuestionType> available) =>
    DefaultDailyPlanner(
      answers: FakeSessionRepository(),
      mistakes: FakeMistakeRepository(),
      available: available,
    );

/// Perencana yang gagal membaca data, lalu bisa dibetulkan.
class FlakyPlanner implements DailyPlanner {
  FlakyPlanner(this.inner);

  final DailyPlanner inner;
  bool failing = true;

  @override
  Future<DailyPlan> plan(TestProfile profile, DateTime now) async {
    if (failing) throw StateError('tabel profil rusak: SQLITE_CORRUPT');
    return inner.plan(profile, now);
  }
}

/// Layar tab di dalam kerangka tab untuk golden dan tema gelap, tanpa router.
Widget tabScreen(String location, Widget screen) =>
    TabShell(location: location, child: screen);

/// Jawaban untuk butir rencana [item] di posisi [posisi].
AnswerRecord answerFor(
  PlanItem item,
  int posisi, {
  int sessionId = 1,
  bool benar = true,
  int? opsiDipilih = 0,
  int ms = 30000,
}) =>
    AnswerRecord(
      sessionId: sessionId,
      posisi: posisi,
      tipe: item.type.code,
      kategori: item.type.category.code,
      seed: item.seed,
      kesulitan: item.difficulty,
      genVersi: item.genVersi,
      opsiDipilih: opsiDipilih,
      benar: benar,
      durasiMs: ms,
      label: opsiDipilih == null
          ? SpeedLabel.salahLambat
          : benar
              ? SpeedLabel.benarCepat
              : SpeedLabel.salahCepat,
    );

/// Menaruh sesi di repository palsu: [answered] soal pertama dijawab (benar
/// bila [correct] menyetujui posisinya), dan sesi ditutup bila [finished].
Future<int> seedSession(
  FakeSessionRepository repo, {
  required SessionMode mode,
  required SessionPlan plan,
  int profileId = 1,
  int? answered,
  bool Function(int posisi)? correct,
  int posisi = 0,
  bool finished = false,
  DateTime? mulai,
  DateTime? deadline,
}) async {
  final id = await repo.start(NewSession(
    profileId: profileId,
    mode: mode,
    plan: plan,
    mulai: mulai ?? appNow,
    deadline: deadline,
  ));
  final n = answered ?? (finished ? plan.items.length : 0);
  for (var i = 0; i < n; i++) {
    await repo.recordAnswer(answerFor(
      plan.items[i],
      i,
      sessionId: id,
      benar: correct?.call(i) ?? true,
    ));
  }
  await repo.updateProgress(id, posisi);
  if (finished) {
    await repo.finish(
      id,
      (mulai ?? appNow).add(const Duration(minutes: 10)),
    );
  }
  return id;
}

PlanItem planItem(QuestionType type, int seed, String subtes) => PlanItem(
      type: type,
      seed: seed,
      difficulty: Difficulty.easy,
      genVersi: GeneratorRegistry.generator(type).version,
      subtes: subtes,
    );

/// Latihan tanpa timer: dua soal Hitungan cepat (opsi teks) dan satu Matriks
/// 3x3 (opsi bergambar).
SessionPlan latihanPlan() => SessionPlan(
      items: [
        planItem(QuestionType.numAri, 40, 'numerik'),
        planItem(QuestionType.numAri, 41, 'numerik'),
        planItem(QuestionType.figMtx, 50, 'figural'),
      ],
    );

/// Latihan yang subtesnya bertimer [menit] menit: numerik 2 soal, figural 1.
SessionPlan timedLatihanPlan({int menit = 5}) => SessionPlan(
      items: latihanPlan().items,
      subtes: [
        SubtestPlan(kategori: 'numerik', jumlah: 2, menit: menit),
        SubtestPlan(kategori: 'figural', jumlah: 1, menit: menit),
      ],
    );

/// Simulasi tiga subtes: numerik 3 soal 5 menit, logika 2 soal 4 menit,
/// figural 2 soal 3 menit.
SessionPlan simulasiPlan() => SessionPlan(
      items: [
        for (var i = 0; i < 3; i++)
          planItem(QuestionType.numSeq, 10 + i, 'numerik'),
        for (var i = 0; i < 2; i++)
          planItem(QuestionType.logSyl, 20 + i, 'logika'),
        for (var i = 0; i < 2; i++)
          planItem(QuestionType.figOdd, 30 + i, 'figural'),
      ],
      subtes: const [
        SubtestPlan(kategori: 'numerik', jumlah: 3, menit: 5),
        SubtestPlan(kategori: 'logika', jumlah: 2, menit: 4),
        SubtestPlan(kategori: 'figural', jumlah: 2, menit: 3),
      ],
    );
