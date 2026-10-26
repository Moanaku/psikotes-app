import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/scoring.dart';

import 'session_harness.dart';

AnswerRecord a(
  int posisi, {
  String tipe = 'NUM-SEQ',
  String kategori = 'numerik',
  bool benar = true,
  int? pilih = 0,
  int ms = 5000,
  SpeedLabel label = SpeedLabel.benarCepat,
}) =>
    AnswerRecord(
      sessionId: 1,
      posisi: posisi,
      tipe: tipe,
      kategori: kategori,
      seed: posisi,
      kesulitan: Difficulty.easy,
      genVersi: 1,
      opsiDipilih: pilih,
      benar: benar,
      durasiMs: ms,
      label: label,
    );

void main() {
  group('label kecepatan', () {
    test('sama dengan ambang berarti cepat', () {
      SpeedLabel l(bool benar, int ms) => Scoring.label(
          benar: benar, dijawab: true, durasiMs: ms, ambangMs: 5000);
      expect(l(true, 5000), SpeedLabel.benarCepat);
      expect(l(true, 5001), SpeedLabel.benarLambat);
      expect(l(false, 0), SpeedLabel.salahCepat);
      expect(l(false, 5001), SpeedLabel.salahLambat);
    });

    test('soal tidak dijawab selalu salah dan lambat', () {
      expect(
        Scoring.label(benar: false, dijawab: false, durasiMs: 0, ambangMs: 0),
        SpeedLabel.salahLambat,
      );
    });
  });

  group('ambang', () {
    test('median ganjil dan genap', () {
      expect(Scoring.median([3, 1, 2]), 2);
      expect(Scoring.median([4, 1, 2, 3]), 2);
      expect(Scoring.median([4000, 7001]), 5500);
      expect(Scoring.median(const []), isNull);
    });

    test('hanya jawaban benar yang dijawab dihitung, per tipe', () {
      final m = Scoring.correctMedians([
        a(0, ms: 4000),
        a(1, ms: 8000),
        a(2, ms: 100, benar: false),
        a(3, ms: 100, pilih: null, benar: false),
        a(4, tipe: 'FIG-MTX', ms: 20000),
      ]);
      expect(m, {'NUM-SEQ': 6000, 'FIG-MTX': 20000});
    });

    test('tanpa data memakai estimatedSeconds engine', () {
      expect(Scoring.thresholdMs(const {}, 'LOG-SYL', 45), 45000);
      expect(
          Scoring.thresholdMs(const {'LOG-SYL': 30000}, 'LOG-SYL', 45), 30000);
    });

    test('median riwayat dijepit ke 0,5 sampai 2 kali estimatedSeconds', () {
      // Kasus uji perangkat: median 394 dtk untuk soal berperkiraan 35 dtk.
      expect(
          Scoring.thresholdMs(const {'NUM-ARI': 394453}, 'NUM-ARI', 35), 70000);
      expect(Scoring.thresholdMs(const {'NUM-ARI': 800}, 'NUM-ARI', 35), 17500);
      expect(
          Scoring.thresholdMs(const {'NUM-ARI': 17500}, 'NUM-ARI', 35), 17500);
      expect(
          Scoring.thresholdMs(const {'NUM-ARI': 70000}, 'NUM-ARI', 35), 70000);
    });
  });

  group('skor', () {
    test('benar dibagi jumlah soal di rencana', () {
      expect(Scoring.score(0, 0), 0);
      expect(Scoring.score(3, 4), 75);
      expect(Scoring.score(5, 4), 100);
    });

    test('benar hanya bila opsi sama dengan kunci', () {
      final q =
          GeneratorRegistry.generate(QuestionType.numSeq, 1, Difficulty.easy);
      expect(Scoring.isCorrect(q, q.correctIndex), isTrue);
      expect(Scoring.isCorrect(q, null), isFalse);
      expect(Scoring.isCorrect(q, (q.correctIndex + 1) % q.options.length),
          isFalse);
    });

    test(
        'ringkasan: soal tidak dijawab di luar kuadran; kuadran dan tidak '
        'dijawab menjumlah ke total', () {
      final plan = simPlan();
      final s = Scoring.summarize(plan, [
        a(0, ms: 4000),
        a(1, benar: false, ms: 3000, label: SpeedLabel.salahCepat),
        a(2, benar: false, pilih: null, ms: 0, label: SpeedLabel.salahLambat),
        a(3,
            tipe: 'LOG-SYL',
            kategori: 'logika',
            ms: 9000,
            label: SpeedLabel.benarLambat),
      ]);
      expect(s.total, 7);
      expect(s.benar, 2);
      expect(s.skor, closeTo(200 / 7, 1e-9));
      expect(s.tidakDijawab, 4);
      expect(s.kuadran, {
        SpeedLabel.benarCepat: 1,
        SpeedLabel.benarLambat: 1,
        SpeedLabel.salahCepat: 1,
        SpeedLabel.salahLambat: 0,
      });
      expect(
          s.kuadran.values.reduce((x, y) => x + y) + s.tidakDijawab, s.total);
      final num = s.perKategori['numerik']!;
      expect(num.benar, 1);
      expect(num.jumlah, 3);
      expect(num.medianMs, 3500);
      expect(num.akurasi, closeTo(100 / 3, 1e-9));
      expect(s.perKategori['logika']!.jumlah, 2);
      expect(s.perKategori['figural']!.medianMs, isNull);
      expect(s.perKategori['figural']!.akurasi, 0);
    });
  });
}
