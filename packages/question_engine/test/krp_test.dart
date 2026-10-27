import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart' show isWeb;

/// Lembar kecil untuk kasus tulisan tangan: dua kolom, 21 angka.
KrpSheet sheet(int seed) => KrpSheet.generate(
      seed,
      const KrpConfig(columns: 2, secondsPerColumn: 15, rows: 21),
    );

void main() {
  group('kunci, kasus tulisan tangan', () {
    test('angka terakhir dari jumlah dua angka berurutan', () {
      final s = sheet(1);
      for (var c = 0; c < 2; c++) {
        for (var i = 0; i < s.pairsPerColumn; i++) {
          final a = s.digits[c][i];
          final b = s.digits[c][i + 1];
          // Contoh: 7 + 5 = 12 -> 2; 3 + 4 = 7 -> 7; 0 + 0 = 0 -> 0.
          final expected = a + b >= 10 ? a + b - 10 : a + b;
          expect(s.answer(c, i), expected);
        }
      }
    });

    test('skor: isian, benar, salah, kecepatan, ketelitian, konsistensi', () {
      final s = sheet(5);
      List<int> keys(int c, int n) =>
          [for (var i = 0; i < n; i++) s.answer(c, i)];
      List<int> wrongAt(List<int> xs, Set<int> idx) => [
            for (var i = 0; i < xs.length; i++)
              idx.contains(i) ? (xs[i] + 1) % 10 : xs[i],
          ];
      // Kolom 1: 12 isian, 2 salah; kolom 2: 8 isian, semua benar.
      final score = KrpScore.of(s, [
        wrongAt(keys(0, 12), {3, 7}),
        keys(1, 8),
      ]);
      expect([for (final c in score.columns) (c.filled, c.correct, c.wrong)],
          [(12, 10, 2), (8, 8, 0)]);
      expect(score.filled, 20);
      expect(score.correct, 18);
      // Kecepatan 20 / 2 = 10; ketelitian 18 / 20 = 90%.
      expect(score.speed.toString(), '10');
      expect(score.accuracyPercent, 90);
      // Rentang 12 - 8 = 4; simpangan rata-rata (|12-10| + |8-10|) / 2 = 2.
      expect(score.range, 4);
      expect(score.meanDeviation.toString(), '2');
    });

    test('pecahan dan pembulatan ketelitian', () {
      final s = KrpSheet.generate(
          9, const KrpConfig(columns: 3, secondsPerColumn: 15, rows: 21));
      List<int> keys(int c, int n) =>
          [for (var i = 0; i < n; i++) s.answer(c, i)];
      // Isian 5, 4, 0 -> kecepatan 9/3 = 3; satu salah: 8/9 = 88,9% -> 89%.
      final typed = [keys(0, 5), keys(1, 4), <int>[]];
      typed[1][0] = (typed[1][0] + 5) % 10;
      final score = KrpScore.of(s, typed);
      expect(score.speed.toString(), '3');
      expect(score.accuracyPercent, 89);
      expect(score.range, 5);
      // |5-3| + |4-3| + |0-3| = 6, dibagi 3 = 2.
      expect(score.meanDeviation.toString(), '2');
    });

    test('kosong: kecepatan 0, ketelitian 0, isian lebih diabaikan', () {
      final s = sheet(2);
      final empty = KrpScore.of(s, const []);
      expect((empty.filled, empty.accuracyPercent, empty.range), (0, 0, 0));
      final over = KrpScore.of(s, [
        [for (var i = 0; i < 40; i++) s.answer(0, i % s.pairsPerColumn)],
      ]);
      expect(over.columns.first.filled, s.pairsPerColumn);
    });
  });

  group('pengaturan', () {
    test('dari subtes profil: waktu per kolom dan baris yang cukup', () {
      // Bank-style: 15 kolom, 15 menit -> 60 detik per kolom, 121 baris.
      final bank = KrpConfig.fromSubtest(columns: 15, minutes: 15);
      expect((bank.columns, bank.secondsPerColumn, bank.rows), (15, 60, 121));
      // Template awal: 10 kolom, 10 menit -> 60 detik.
      expect(
          KrpConfig.fromSubtest(columns: 10, minutes: 10).secondsPerColumn, 60);
      // 50 kolom dalam 10 menit -> 12 detik, dijepit ke 15.
      expect(
          KrpConfig.fromSubtest(columns: 50, minutes: 10).secondsPerColumn, 15);
    });

    test('semua kombinasi isian profil menghasilkan pengaturan sah', () {
      for (var cols = 1; cols <= 200; cols += 7) {
        for (var min = 1; min <= 180; min += 11) {
          expect(KrpConfig.fromSubtest(columns: cols, minutes: min).isValid,
              isTrue,
              reason: '$cols kolom $min menit');
        }
      }
      expect(KrpConfig.practice.isValid, isTrue);
    });

    test('pengaturan tidak sah ditolak', () {
      expect(
        () => KrpSheet.generate(
            1, const KrpConfig(columns: 1, secondsPerColumn: 30, rows: 21)),
        throwsArgumentError,
      );
    });
  });

  group('invarian 10.000 seed', () {
    test('deterministik, angka 0-9, kunci sama dengan hitungan kedua, cepat',
        () {
      const config = KrpConfig(columns: 15, secondsPerColumn: 60, rows: 121);
      final counts = List.filled(10, 0);
      var slowest = 0;
      final timer = Stopwatch();
      for (var seed = 0; seed < 10000; seed++) {
        timer
          ..reset()
          ..start();
        final s = KrpSheet.generate(seed, config);
        timer.stop();
        if (seed > 50 && timer.elapsedMicroseconds > slowest) {
          slowest = timer.elapsedMicroseconds;
        }
        if (seed % 500 == 0) {
          final again = KrpSheet.generate(seed, config);
          expect(again.digits, s.digits, reason: 'seed $seed');
        }
        for (var c = 0; c < config.columns; c++) {
          final col = s.digits[c];
          expect(col.length, config.rows);
          for (var i = 0; i < col.length; i++) {
            final d = col[i];
            expect(d >= 0 && d <= 9, isTrue);
            counts[d]++;
            if (i > 0) {
              // Hitungan kedua: sisa bagi lewat pengurangan berulang.
              var sum = col[i - 1] + d;
              while (sum >= 10) {
                sum -= 10;
              }
              if (s.answer(c, i - 1) != sum) {
                fail('seed $seed kolom $c pasangan ${i - 1}');
              }
            }
          }
        }
      }
      // Sebaran angka merata: tiap angka 10% +- 0,5%.
      final total = counts.fold<int>(0, (a, b) => a + b);
      for (final n in counts) {
        expect(n / total, closeTo(0.1, 0.005));
      }
      if (!isWeb) expect(slowest, lessThan(50000), reason: 'mikrodetik');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
