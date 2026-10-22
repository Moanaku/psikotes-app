import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

/// Hasil satu soal untuk [seedFinished]: benar, label, dan waktu.
class Outcome {
  const Outcome(this.benar, this.label,
      {this.ms = 30000, this.skipped = false});

  final bool benar;
  final SpeedLabel label;
  final int ms;
  final bool skipped;

  static const benarCepat = Outcome(true, SpeedLabel.benarCepat);
  static const benarLambat = Outcome(true, SpeedLabel.benarLambat, ms: 90000);
  static const salahCepat = Outcome(false, SpeedLabel.salahCepat, ms: 5000);
  static const salahLambat = Outcome(false, SpeedLabel.salahLambat, ms: 90000);
  static const dilewati =
      Outcome(false, SpeedLabel.salahLambat, ms: 20000, skipped: true);
}

/// Sesi latihan tiga atau empat soal yang sudah ditutup dengan hasil [outcomes]
/// (Hitungan cepat, Hitungan cepat, Matriks 3x3, Deret angka).
Future<int> seedFinished(
  FakeSessionRepository repo,
  List<Outcome> outcomes, {
  DateTime? mulai,
  SessionMode mode = SessionMode.latihan,
  bool finished = true,
}) async {
  final all = [
    ...latihanPlan().items,
    planItem(QuestionType.numSeq, 12, 'numerik'),
  ];
  final plan = SessionPlan(items: all.take(outcomes.length).toList());
  final start = mulai ?? appNow;
  final id = await repo.start(NewSession(
    profileId: 1,
    mode: mode,
    plan: plan,
    mulai: start,
  ));
  for (var i = 0; i < outcomes.length; i++) {
    final o = outcomes[i];
    final a = answerFor(
      plan.items[i],
      i,
      sessionId: id,
      benar: o.benar,
      opsiDipilih: o.skipped ? null : 0,
      ms: o.ms,
    );
    await repo.recordAnswer(AnswerRecord(
      sessionId: a.sessionId,
      posisi: a.posisi,
      tipe: a.tipe,
      kategori: a.kategori,
      seed: a.seed,
      kesulitan: a.kesulitan,
      genVersi: a.genVersi,
      opsiDipilih: a.opsiDipilih,
      benar: a.benar,
      durasiMs: a.durasiMs,
      label: o.label,
    ));
  }
  if (finished) {
    await repo.finish(id, start.add(const Duration(minutes: 5)));
  }
  return id;
}
