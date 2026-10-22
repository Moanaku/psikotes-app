import 'package:flutter/widgets.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/app/tab_shell.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/services/daily_planner.dart';
import 'package:simulator_psikotes_it/domain/services/profile_templates.dart';

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
