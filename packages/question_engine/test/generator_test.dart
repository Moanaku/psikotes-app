import 'dart:convert';

import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/toy_generators.dart';

/// Kandidat yang selalu punya dua opsi kembar.
class _DuplicateGenerator extends MaxNumberGenerator {
  const _DuplicateGenerator();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) =>
      assemble(rng, seed, difficulty, [9, 4, 4]);
}

/// Kandidat dengan seed salah: bug generator.
class _WrongSeedGenerator extends MaxNumberGenerator {
  const _WrongSeedGenerator();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) =>
      assemble(rng, seed + 1, difficulty, numbers(rng, 3));
}

void main() {
  const gen = MaxNumberGenerator();

  group('RetryingGenerator', () {
    test('generate dan generateDetailed memberi soal sama', () {
      final a = gen.generate(77, Difficulty.medium);
      final b = gen.generateDetailed(77, Difficulty.medium).question;
      expect(b.toJson(), a.toJson());
      expect(a.seed, 77);
    });

    test('percobaan ulang memakai Rng.derive(seed, attempt)', () {
      // Cari seed hard yang gagal di percobaan pertama.
      final seed = [
        for (var s = 0; s < 200; s++)
          if (gen.generateDetailed(s, Difficulty.hard).attempts > 1) s,
      ].first;
      final detailed = gen.generateDetailed(seed, Difficulty.hard);
      expect(detailed.rejections.first.reason, RejectionReason.buildFailed);
      expect(detailed.rejections.first.attempt, 0);
      // Soal diterima sama dengan build langsung pada percobaan berikutnya.
      final direct = gen.build(
          Rng.derive(seed, detailed.attempts - 1), seed, Difficulty.hard)!;
      expect(detailed.question.toJson(), direct.toJson());
    });

    test('opsi kembar ditolak lalu GenerationFailure setelah 20 percobaan', () {
      final failure = _expectFailure(
          () => const _DuplicateGenerator().generate(3, Difficulty.easy));
      expect(failure.rejections, hasLength(RetryingGenerator.maxAttempts));
      expect(failure.rejections.map((r) => r.reason).toSet(),
          {RejectionReason.duplicateOptions});
      expect(failure.rejections.map((r) => r.attempt),
          [for (var i = 0; i < 20; i++) i]);
      expect(failure.seed, 3);
      expect(failure.type, QuestionType.numAri);
      expect(failure.toString(), contains('20 percobaan gagal'));
    });

    test('kandidat dengan seed salah ditolak sebagai invalid', () {
      final failure = _expectFailure(
          () => const _WrongSeedGenerator().generate(3, Difficulty.easy));
      expect(failure.rejections.first.reason, RejectionReason.invalid);
      expect(failure.rejections.first.detail, contains('seed 4'));
    });

    test('build null berulang menjadi buildFailed', () {
      final failure = _expectFailure(
          () => const AlwaysNullGenerator().generate(1, Difficulty.easy));
      expect(failure.rejections.map((r) => r.reason).toSet(),
          {RejectionReason.buildFailed});
    });

    test('generator tanpa kegagalan selesai di percobaan pertama', () {
      final d = gen.generateDetailed(5, Difficulty.easy);
      expect(d.attempts, 1);
      expect(d.rejections, isEmpty);
    });

    test('seed di luar 32 bit ditolak', () {
      expect(() => gen.generate(-1, Difficulty.easy), throwsRangeError);
      expect(
          () => gen.generate(0x100000000, Difficulty.easy), throwsRangeError);
      expect(gen.generate(0xFFFFFFFF, Difficulty.easy).seed, 0xFFFFFFFF);
    });
  });

  group('soal emas lintas platform (VM dan Chrome)', () {
    test('seed 2024 hard, diterima di percobaan pertama', () {
      expect(
        jsonEncode(gen.generate(2024, Difficulty.hard).toJson()),
        '{"type":"NUM-ARI","category":"numerik","seed":2024,'
        '"difficulty":"hard","stem":{"text":"Pilih angka terbesar."},'
        '"options":[{"id":"A","content":{"text":"61"}},'
        '{"id":"B","content":{"text":"34"}},'
        '{"id":"C","content":{"text":"98"}},'
        '{"id":"D","content":{"text":"79"}},'
        '{"id":"E","content":{"text":"6"}}],"correctIndex":2,'
        '"explanation":"Angka terbesar dipilih dengan membandingkan semua '
        'opsi.","estimatedSeconds":10,"tags":["toy:max"]}',
      );
    });

    test('seed 6 hard, diterima di percobaan kedua', () {
      final d = gen.generateDetailed(6, Difficulty.hard);
      expect(d.attempts, 2);
      expect(d.question.options.map((o) => o.content.text),
          ['80', '85', '46', '45', '35']);
      expect(d.question.correctIndex, 1);
    });
  });

  group('assembleOptions', () {
    QuestionContent t(String s) => QuestionContent(text: s);

    test('ID berurutan dan kunci menunjuk isi benar', () {
      final set = assembleOptions(Rng(5), t('benar'), [t('x'), t('y'), t('z')]);
      expect(set.options.map((o) => o.id), ['A', 'B', 'C', 'D']);
      expect(set.options[set.correctIndex].content.text, 'benar');
      expect(set.options.map((o) => o.content.text).toSet(),
          {'benar', 'x', 'y', 'z'});
    });

    test('posisi kunci tersebar ke semua posisi', () {
      final counts = List.filled(5, 0);
      for (var s = 0; s < 5000; s++) {
        counts[assembleOptions(Rng(s), t('k'), [t('a'), t('b'), t('c'), t('d')])
            .correctIndex]++;
      }
      for (final c in counts) {
        expect(c, inInclusiveRange(900, 1100));
      }
    });

    test('jumlah opsi di luar 2 sampai 8 ditolak', () {
      expect(() => assembleOptions(Rng(1), t('k'), []), throwsArgumentError);
      expect(
          () => assembleOptions(
              Rng(1), t('k'), [for (var i = 0; i < 8; i++) t('$i')]),
          throwsArgumentError);
    });
  });

  test('duplicateOptionPairs memakai kesamaan visual', () {
    final q = const MaxNumberGenerator()
        .assemble(Rng(1), 1, Difficulty.easy, [9, 4, 1]);
    expect(duplicateOptionPairs(q), isEmpty);
    final dup = const _DuplicateGenerator().build(Rng(1), 1, Difficulty.easy)!;
    expect(duplicateOptionPairs(dup), hasLength(1));
  });
}

GenerationFailure _expectFailure(void Function() body) {
  try {
    body();
  } on GenerationFailure catch (e) {
    return e;
  }
  fail('GenerationFailure tidak dilempar');
}
