/// Generator mainan untuk menguji harness dan loop percobaan ulang.
///
/// Soal: "Pilih angka terbesar." Bukan tipe soal sungguhan; memakai tipe
/// NUM-ARI hanya karena harness butuh tipe yang terdaftar.
library;

import 'package:question_engine/question_engine.dart';

final class MaxNumberSolver implements QuestionSolver {
  const MaxNumberSolver();

  @override
  List<int> validOptions(Question question) {
    final values = [
      for (final o in question.options) int.parse(o.content.text!.trim()),
    ];
    final best = values.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < values.length; i++)
        if (values[i] == best) i,
    ];
  }
}

/// Generator yang benar: easy 3 opsi, medium 4, hard 5. Pada hard, sekitar 10%
/// percobaan sengaja gagal dibentuk agar jalur percobaan ulang teruji.
class MaxNumberGenerator extends RetryingGenerator {
  const MaxNumberGenerator();

  @override
  QuestionType get type => QuestionType.numAri;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const MaxNumberSolver();

  int optionCount(Difficulty d) => switch (d) {
        Difficulty.easy => 3,
        Difficulty.medium => 4,
        Difficulty.hard => 5,
      };

  /// Angka berbeda, terurut menurun: indeks 0 adalah yang terbesar.
  List<int> numbers(Rng rng, int count) {
    final pool = rng.shuffle([for (var i = 1; i < 100; i++) i]);
    return pool.take(count).toList()..sort((a, b) => b - a);
  }

  Question assemble(
    Rng rng,
    int seed,
    Difficulty difficulty,
    List<int> values, {
    String explanation =
        'Angka terbesar dipilih dengan membandingkan semua opsi.',
  }) {
    final set = assembleOptions(
      rng,
      QuestionContent(text: '${values.first}'),
      [for (final v in values.skip(1)) QuestionContent(text: '$v')],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: const QuestionContent(text: 'Pilih angka terbesar.'),
      options: set.options,
      correctIndex: set.correctIndex,
      explanation: explanation,
      estimatedSeconds: 10,
      tags: const ['toy:max'],
    );
  }

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    if (difficulty == Difficulty.hard && rng.nextInt(10) == 0) return null;
    return assemble(
        rng, seed, difficulty, numbers(rng, optionCount(difficulty)));
  }
}

/// Kunci selalu di posisi A: melanggar sebaran posisi kunci.
class KeyAlwaysFirstGenerator extends MaxNumberGenerator {
  const KeyAlwaysFirstGenerator();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final values = numbers(rng, optionCount(difficulty));
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: const QuestionContent(text: 'Pilih angka terbesar.'),
      options: [
        for (var i = 0; i < values.length; i++)
          Option(
              id: Option.idFor(i),
              content: QuestionContent(text: '${values[i]}')),
      ],
      correctIndex: 0,
      explanation: 'Angka terbesar ada di A.',
      estimatedSeconds: 10,
    );
  }
}

/// Generator tanpa loop percobaan ulang yang mengembalikan soal apa adanya.
class RawGenerator implements QuestionGenerator {
  RawGenerator(this.make);

  final Question Function(int seed, Difficulty difficulty, int call) make;
  int _calls = 0;

  @override
  QuestionType get type => QuestionType.numAri;

  @override
  int get version => 1;

  @override
  Question generate(int seed, Difficulty difficulty) =>
      make(seed, difficulty, _calls++);
}

Question rawQuestion(
  int seed,
  Difficulty difficulty,
  List<String> texts,
  int correctIndex, {
  String stem = 'Pilih angka terbesar.',
  String explanation = 'Bandingkan semua angka.',
}) =>
    Question(
      type: QuestionType.numAri,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(text: stem),
      options: [
        for (var i = 0; i < texts.length; i++)
          Option(id: Option.idFor(i), content: QuestionContent(text: texts[i])),
      ],
      correctIndex: correctIndex,
      explanation: explanation,
      estimatedSeconds: 10,
    );

/// Separuh kandidat tidak sah (pembahasan kosong) lalu ditolak loop: bug yang
/// tersembunyi oleh percobaan ulang dan harus ditangkap harness.
class SometimesInvalidGenerator extends MaxNumberGenerator {
  const SometimesInvalidGenerator();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final broken = rng.nextBool();
    return assemble(rng, seed, difficulty, numbers(rng, 3),
        explanation: broken ? ' ' : 'Angka terbesar.');
  }
}

/// Semua percobaan gagal dibentuk.
class AlwaysNullGenerator extends MaxNumberGenerator {
  const AlwaysNullGenerator();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) => null;
}
