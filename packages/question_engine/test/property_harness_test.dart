import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';
import 'support/toy_generators.dart';

/// Harness diuji dua arah: generator benar lolos penuh (10.000 seed per
/// kesulitan, seperti generator sungguhan), dan tiap generator rusak tertangkap
/// oleh invarian yang tepat.
void main() {
  PropertyHarness(const MaxNumberGenerator(), const MaxNumberSolver())
      .register();

  const solver = MaxNumberSolver();

  group('harness menangkap pelanggaran', () {
    test('invarian 1: kunci bukan opsi yang benar', () {
      final h = PropertyHarness(
        RawGenerator((s, d, _) => rawQuestion(s, d, ['3', '9', '1'], 0)),
        solver,
      );
      expect(h.checkSeed(1, Difficulty.easy),
          contains(startsWith('solver: valid [1], kunci 0')));
    });

    test('invarian 1: dua opsi sama-sama benar', () {
      final h = PropertyHarness(
        RawGenerator((s, d, _) => rawQuestion(s, d, ['9', '09', '1'], 0)),
        solver,
      );
      expect(h.checkSeed(1, Difficulty.easy), contains(startsWith('solver:')));
    });

    test('invarian 2: opsi kembar setelah dirapikan', () {
      final h = PropertyHarness(
        RawGenerator((s, d, _) => rawQuestion(s, d, ['9', '4', ' 4 '], 0)),
        solver,
      );
      expect(
          h.checkSeed(1, Difficulty.easy), contains('opsi kembar: [[1, 2]]'));
    });

    test('invarian 3: seed sama memberi soal berbeda', () {
      final h = PropertyHarness(
        RawGenerator((s, d, call) =>
            rawQuestion(s, d, ['9', '4', '1'], 0, stem: 'Soal ke-$call.')),
        solver,
      );
      expect(
          h.checkSeed(1, Difficulty.easy), contains('seed sama, soal berbeda'));
    });

    test('invarian 4: kunci selalu di posisi A', () {
      final report = PropertyHarness(
        const KeyAlwaysFirstGenerator(),
        solver,
        seedCount: 300,
      ).sweep(Difficulty.medium);
      expect(
          report.violations,
          contains(
              startsWith('4 opsi: posisi kunci tidak merata [300, 0, 0, 0]')));
    });

    test('invarian 5: format tidak sah', () {
      final h = PropertyHarness(
        RawGenerator(
            (s, d, _) => rawQuestion(s, d, ['9', '4'], 0, explanation: '')),
        solver,
      );
      expect(h.checkSeed(1, Difficulty.easy),
          contains('format: explanation kosong'));
    });

    test('invarian 5: batas khusus tipe', () {
      final h = PropertyHarness(
        const MaxNumberGenerator(),
        solver,
        bounds: (q) => [
          for (final o in q.options)
            if (int.parse(o.content.text!) > 50) 'angka ${o.content.text} > 50',
        ],
      );
      final flagged = [
        for (var s = 0; s < 20; s++) ...h.checkSeed(s, Difficulty.easy),
      ];
      expect(flagged, contains(startsWith('batas: angka')));
    });

    test('invarian 5: kandidat tidak sah yang disembunyikan percobaan ulang',
        () {
      final h = PropertyHarness(const SometimesInvalidGenerator(), solver);
      final flagged = [
        for (var s = 0; s < 20; s++) ...h.checkSeed(s, Difficulty.easy),
      ];
      expect(flagged, contains(startsWith('kandidat tidak sah')));
    });

    test('invarian 6: pembuatan lebih dari batas waktu', () {
      final report = PropertyHarness(
        RawGenerator((s, d, _) {
          final w = Stopwatch()..start();
          while (w.elapsedMilliseconds < 8) {}
          return rawQuestion(s, d, ['9', '4'], 0);
        }),
        solver,
        seedCount: 3,
        warmUp: 0,
        maxDuration: const Duration(milliseconds: 2),
      ).sweep(Difficulty.easy);
      expect(report.violations, contains(contains('ms, batas 2 ms')));
    }, testOn: 'vm');

    test('invarian 7: GenerationFailure tercatat', () {
      final report = PropertyHarness(
        const AlwaysNullGenerator(),
        solver,
        seedCount: 5,
      ).sweep(Difficulty.easy);
      expect(report.failures, 5);
      expect(report.violations.first, contains('GenerationFailure'));
    });

    test('persentase percobaan ulang dihitung', () {
      final report = PropertyHarness(
        const MaxNumberGenerator(),
        solver,
        seedCount: 1000,
      ).sweep(Difficulty.hard);
      expect(report.violations, isEmpty);
      // Sekitar 10% percobaan pertama sengaja gagal pada hard.
      expect(report.retryPercent, inInclusiveRange(5, 15));
      expect(report.summary, contains('% butuh percobaan ulang'));
    });
  });

  group('chiSquareIssue', () {
    test('sebaran rata lolos', () {
      expect(chiSquareIssue([250, 250, 250, 250]), isNull);
    });
    test('sampel terlalu kecil dilewati', () {
      expect(chiSquareIssue([3, 0, 0, 0]), isNull);
    });
    test('sebaran timpang gagal', () {
      expect(chiSquareIssue([400, 200, 200, 200]), isNotNull);
    });
  });
}
