import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/services/kraepelin_run.dart';

const config = KrpConfig(columns: 3, secondsPerColumn: 20, rows: 21);

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  late KrpSheet sheet;
  setUp(() => sheet = KrpSheet.generate(11, config));

  test('kolom berganti otomatis saat waktunya habis, lalu selesai', () {
    final run = KraepelinRun(sheet, start: s(100));
    expect((run.column, run.remaining(s(100))), (0, s(20)));
    expect(run.tick(s(119)), isFalse);
    expect(run.remaining(s(119)), s(1));
    expect(run.tick(s(120)), isTrue);
    expect((run.column, run.remaining(s(120))), (1, s(20)));
    // Kolom terakhir habis di detik 160.
    run.tick(s(159));
    expect((run.column, run.finished), (2, false));
    expect(run.tick(s(160)), isTrue);
    expect(run.finished, isTrue);
    expect(run.remaining(s(200)), Duration.zero);
  });

  test('app tertutup lama: beberapa kolom terlewat sekaligus', () {
    final run = KraepelinRun(sheet, start: Duration.zero);
    run.input(sheet.answer(0, 0), s(1));
    // Kembali di detik 45: kolom 1 habis (20), kolom 2 berjalan (20 sampai 40)
    // juga habis, kolom 3 berjalan 5 detik.
    run.tick(s(45));
    expect(run.column, 2);
    expect(run.remaining(s(45)), s(15));
    expect([for (final a in run.answers) a.length], [1, 0, 0]);
  });

  test('isian dicatat per kolom; isian setelah waktu habis masuk kolom baru',
      () {
    final run = KraepelinRun(sheet, start: Duration.zero);
    run.input(sheet.answer(0, 0), s(1));
    run.input((sheet.answer(0, 1) + 1) % 10, s(2));
    run.input(sheet.answer(1, 0), s(21)); // kolom 1 sudah habis
    expect(run.answers, [
      [sheet.answer(0, 0), (sheet.answer(0, 1) + 1) % 10],
      [sheet.answer(1, 0)],
    ]);
    final score = run.score;
    expect([for (final c in score.columns) (c.filled, c.correct)],
        [(2, 1), (1, 1), (0, 0)]);
  });

  test('kolom penuh menunggu waktu; tes selesai mengabaikan isian', () {
    final run = KraepelinRun(sheet, start: Duration.zero);
    for (var i = 0; i < sheet.pairsPerColumn + 3; i++) {
      run.input(sheet.answer(0, i % sheet.pairsPerColumn), s(1));
    }
    expect(run.columnFull, isTrue);
    expect(run.answers.first.length, sheet.pairsPerColumn);
    run.finish();
    run.input(3, s(2));
    expect(run.finished, isTrue);
    expect(run.answers.length, 1);
    expect(() => run.input(10, s(2)), throwsRangeError);
  });
}
