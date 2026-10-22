/// Harness property test bersama untuk semua generator.
///
/// Memeriksa invarian di docs/08-rencana-tes.md, "Invarian engine":
///   1. tepat satu opsi benar menurut solver, sama dengan correctIndex;
///   2. tidak ada dua opsi yang tampak sama;
///   3. seed sama memberi soal identik, juga setelah JSON bolak-balik;
///   4. posisi kunci tersebar merata (chi-kuadrat, alfa 0,001);
///   5. semua nilai dalam batas (format soal plus [PropertyHarness.bounds]);
///   6. pembuatan satu soal di bawah 50 ms (hanya di VM);
///   7. tidak ada GenerationFailure; persentase percobaan ulang dicatat.
///
/// Pemakaian di test generator:
///
///     void main() {
///       PropertyHarness(FigMtxGenerator(), FigMtxSolver()).register();
///     }
///
/// Rentang seed tetap (0 sampai seedCount - 1) agar CI dapat diulang; glados
/// menambah eksplorasi seed acak di seluruh rentang 32 bit.
library;

import 'dart:convert';

import 'package:glados/glados.dart';
import 'package:question_engine/question_engine.dart';

/// Batas khusus tipe (angka wajar, panjang teks); kembalikan pelanggaran.
typedef BoundsCheck = List<String> Function(Question question);

/// true di web: di sana int dan double adalah tipe JS yang sama.
const bool isWeb = identical(0, 0.0);

/// Nilai kritis chi-kuadrat untuk alfa 0,001, indeks = derajat bebas.
const List<double> _chiSquareCritical001 = [
  double.nan, 10.828, 13.816, 16.266, 18.467, 20.515, 22.458, 24.322, //
];

String canonicalJson(Question q) => jsonEncode(q.toJson());

final class SweepReport {
  SweepReport(this.difficulty);

  final Difficulty difficulty;
  int questions = 0;
  int retried = 0;
  int failures = 0;
  final List<String> violations = [];

  /// Jumlah kunci per posisi, dikelompokkan per banyak opsi.
  final Map<int, List<int>> keyPositions = {};

  /// Waktu pembuatan terlama dalam mikrodetik (setelah pemanasan).
  int slowestMicros = 0;
  int slowestSeed = -1;

  /// Jumlah waktu dan banyak soal yang diukur (setelah pemanasan).
  int totalMicros = 0;
  int timedCount = 0;

  double get averageMicros => timedCount == 0 ? 0 : totalMicros / timedCount;

  double get retryPercent => questions == 0 ? 0 : 100 * retried / questions;

  String get summary => '${difficulty.code}: $questions soal, '
      '${retryPercent.toStringAsFixed(2)}% butuh percobaan ulang, '
      'rata-rata ${(averageMicros / 1000).toStringAsFixed(3)} ms, '
      'terlama ${(slowestMicros / 1000).toStringAsFixed(2)} ms '
      '(seed $slowestSeed)';
}

final class PropertyHarness {
  PropertyHarness(
    this.generator,
    this.solver, {
    this.seedCount = 10000,
    this.firstSeed = 0,
    this.gladosRuns = 200,
    this.maxDuration = const Duration(milliseconds: 50),
    this.warmUp = 50,
    this.maxReportedViolations = 20,
    this.bounds,
  });

  final QuestionGenerator generator;
  final QuestionSolver solver;
  final int seedCount;
  final int firstSeed;
  final int gladosRuns;
  final Duration maxDuration;
  final int warmUp;
  final int maxReportedViolations;
  final BoundsCheck? bounds;

  /// Invarian 1, 2, 3, 5, dan 7 untuk satu seed. Kosong berarti lolos.
  List<String> checkSeed(int seed, Difficulty difficulty) {
    final Question q;
    final List<Rejection> rejections;
    try {
      final g = generator;
      if (g is RetryingGenerator) {
        final detailed = g.generateDetailed(seed, difficulty);
        q = detailed.question;
        rejections = detailed.rejections;
      } else {
        q = g.generate(seed, difficulty);
        rejections = const [];
      }
    } on GenerationFailure catch (e) {
      return ['GenerationFailure: $e'];
    }
    return checkQuestion(q, seed, difficulty, rejections: rejections);
  }

  /// Memeriksa soal [q] yang dibuat dari ([seed], [difficulty]).
  List<String> checkQuestion(
    Question q,
    int seed,
    Difficulty difficulty, {
    List<Rejection> rejections = const [],
  }) {
    final v = <String>[];

    // 5. Format dan batas.
    if (q.type != generator.type) v.add('type ${q.type.code}');
    if (q.seed != seed) v.add('seed ${q.seed}, seharusnya $seed');
    if (q.difficulty != difficulty) v.add('difficulty ${q.difficulty.code}');
    v.addAll(q.validate().map((i) => 'format: $i'));
    v.addAll(bounds?.call(q).map((i) => 'batas: $i') ?? const <String>[]);
    for (final r in rejections) {
      if (r.reason == RejectionReason.invalid) {
        v.add('kandidat tidak sah ditolak diam-diam (bug generator): $r');
      }
    }
    if (v.isNotEmpty) return v;

    // 2. Tidak ada opsi kembar.
    final dup = duplicateOptionPairs(q);
    if (dup.isNotEmpty) v.add('opsi kembar: $dup');

    // 1. Tepat satu opsi benar.
    final valid = solver.validOptions(q);
    if (valid.length != 1 || valid.single != q.correctIndex) {
      v.add('solver: valid $valid, kunci ${q.correctIndex}');
    }

    // 3. Determinisme dan JSON bolak-balik.
    final json = canonicalJson(q);
    final again = generator.generate(seed, difficulty);
    if (canonicalJson(again) != json) v.add('seed sama, soal berbeda');
    final decoded = Question.fromJson(jsonDecode(json));
    if (canonicalJson(decoded) != json) v.add('JSON bolak-balik berubah');
    final decodedValid = solver.validOptions(decoded);
    if (decodedValid.length != valid.length ||
        !decodedValid.every(valid.contains)) {
      v.add('solver berbeda setelah JSON: $decodedValid lawan $valid');
    }
    return v;
  }

  /// Menjalankan semua invarian pada rentang seed tetap untuk satu kesulitan.
  SweepReport sweep(Difficulty difficulty) {
    final report = SweepReport(difficulty);
    final timer = Stopwatch();
    for (var i = 0; i < seedCount; i++) {
      final seed = firstSeed + i;
      final List<String> violations;
      final Question q;
      var attempts = 1;
      timer
        ..reset()
        ..start();
      try {
        final g = generator;
        if (g is RetryingGenerator) {
          final detailed = g.generateDetailed(seed, difficulty);
          timer.stop();
          q = detailed.question;
          attempts = detailed.attempts;
          violations = checkQuestion(q, seed, difficulty,
              rejections: detailed.rejections);
        } else {
          q = g.generate(seed, difficulty);
          timer.stop();
          violations = checkQuestion(q, seed, difficulty);
        }
      } on GenerationFailure catch (e) {
        report.failures++;
        _addViolation(report, seed, ['GenerationFailure: $e']);
        continue;
      }
      report.questions++;
      if (attempts > 1) report.retried++;
      _addViolation(report, seed, violations);

      final counts = report.keyPositions.putIfAbsent(
          q.options.length,
          () => List.filled(
                q.options.length,
                0,
              ));
      if (q.correctIndex >= 0 && q.correctIndex < counts.length) {
        counts[q.correctIndex]++;
      }

      if (i >= warmUp) {
        var micros = timer.elapsedMicroseconds;
        if (micros > maxDuration.inMicroseconds) {
          // Ukur ulang sekali agar jeda GC tidak dihitung sebagai lambat.
          micros = _timeOnce(seed, difficulty);
        }
        report.totalMicros += micros;
        report.timedCount++;
        if (micros > report.slowestMicros) {
          report.slowestMicros = micros;
          report.slowestSeed = seed;
        }
      }
    }

    // 4. Sebaran posisi kunci.
    for (final entry in report.keyPositions.entries) {
      final issue = chiSquareIssue(entry.value);
      if (issue != null) {
        report.violations.add('${entry.key} opsi: $issue');
      }
    }

    // 6. Waktu, hanya di VM.
    if (!isWeb && report.slowestMicros > maxDuration.inMicroseconds) {
      report.violations.add('seed ${report.slowestSeed} butuh '
          '${report.slowestMicros / 1000} ms, batas '
          '${maxDuration.inMilliseconds} ms');
    }
    return report;
  }

  int _timeOnce(int seed, Difficulty difficulty) {
    final timer = Stopwatch()..start();
    generator.generate(seed, difficulty);
    return timer.elapsedMicroseconds;
  }

  void _addViolation(SweepReport report, int seed, List<String> violations) {
    if (violations.isEmpty) return;
    if (report.violations.length < maxReportedViolations) {
      report.violations.add('seed $seed: ${violations.join('; ')}');
    }
  }

  /// Glados generator: seed 32 bit seragam. Tidak menyusut, karena seed yang
  /// "lebih kecil" bukan soal yang lebih sederhana.
  static Generator<int> get anySeed => any.simple(
        generate: (random, size) => random.nextInt(0x100000000),
        shrink: (_) => const <int>[],
      );

  /// Mendaftarkan test sweep dan glados untuk tiap kesulitan.
  void register({Iterable<Difficulty> difficulties = Difficulty.values}) {
    group('invarian ${generator.type.code} v${generator.version}', () {
      for (final d in difficulties) {
        test('${d.code}: $seedCount seed tetap', () {
          final report = sweep(d);
          // Invarian 7: persentase percobaan ulang dicatat di keluaran test.
          // ignore: avoid_print
          print('${generator.type.code} ${report.summary}');
          expect(report.violations, isEmpty, reason: report.summary);
          expect(report.failures, 0);
        }, timeout: const Timeout(Duration(minutes: 10)));

        Glados(anySeed, ExploreConfig(numRuns: gladosRuns)).test(
          '${d.code}: seed acak',
          (seed) => expect(checkSeed(seed, d), isEmpty),
        );
      }
    });
  }
}

/// Uji chi-kuadrat keseragaman; null bila lolos atau sampel terlalu kecil
/// (harapan per posisi di bawah 5).
String? chiSquareIssue(List<int> counts) {
  final k = counts.length;
  if (k < 2) return null;
  final n = counts.fold<int>(0, (a, b) => a + b);
  final expected = n / k;
  if (expected < 5) return null;
  var stat = 0.0;
  for (final c in counts) {
    stat += (c - expected) * (c - expected) / expected;
  }
  final critical = _chiSquareCritical001[k - 1];
  if (stat <= critical) return null;
  return 'posisi kunci tidak merata $counts '
      '(chi2 ${stat.toStringAsFixed(2)} > $critical)';
}
