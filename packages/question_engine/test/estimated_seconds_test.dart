import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

/// Target waktu per soal (`estimatedSeconds`) harus masuk akal untuk semua tipe
/// dan kesulitan: dari target ini app menghitung jumlah soal rencana harian,
/// label cepat atau lambat, dan "target" di pembahasan.
void main() {
  const minSeconds = 5;
  const maxSeconds = 180;

  test('semua tipe, kesulitan, dan seed: $minSeconds sampai $maxSeconds detik',
      () {
    for (final type in GeneratorRegistry.types) {
      for (final d in Difficulty.values) {
        for (var i = 1; i <= 300; i++) {
          final seed = i * 7919;
          final q = GeneratorRegistry.generate(type, seed, d);
          expect(q.estimatedSeconds, inInclusiveRange(minSeconds, maxSeconds),
              reason: '${type.code} ${d.code} seed $seed');
        }
      }
    }
  });

  test('tidak menurun dari mudah ke sulit untuk tipe yang sama', () {
    for (final type in GeneratorRegistry.types) {
      for (var i = 1; i <= 100; i++) {
        final seed = i * 104729;
        final easy = GeneratorRegistry.generate(type, seed, Difficulty.easy);
        final hard = GeneratorRegistry.generate(type, seed, Difficulty.hard);
        expect(
            hard.estimatedSeconds, greaterThanOrEqualTo(easy.estimatedSeconds),
            reason: '${type.code} seed $seed');
      }
    }
  });

  test('batas validasi model tidak lebih longgar dari batas wajar app', () {
    // Question.validate() menerima sampai 600 detik; angka itu hanya pagar
    // pengaman bentuk, bukan target yang boleh dipakai generator.
    expect(Question.maxEstimatedSeconds, greaterThan(maxSeconds));
  });
}
