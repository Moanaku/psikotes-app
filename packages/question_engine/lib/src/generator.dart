/// Antarmuka generator dan solver (docs/02-arsitektur.md, "Antarmuka inti").
library;

import 'models.dart';
import 'rng.dart';

abstract interface class QuestionGenerator {
  QuestionType get type;

  /// Naik setiap kali perilaku generator berubah, agar soal lama bisa dibuat
  /// ulang identik.
  int get version;

  /// Murni dan deterministik. Melempar [GenerationFailure] hanya jika semua
  /// percobaan gagal.
  Question generate(int seed, Difficulty difficulty);
}

abstract interface class QuestionSolver {
  /// Mengembalikan indeks semua opsi yang valid menurut aturan soal, dihitung
  /// hanya dari isi [question] (bukan dari `correctIndex`).
  List<int> validOptions(Question question);
}

enum RejectionReason {
  /// Kandidat tidak bisa dibentuk dari deret acak ini (misalnya kehabisan
  /// nilai atribut yang memenuhi syarat). Wajar; dicoba lagi.
  buildFailed,

  /// Kandidat melanggar format soal. Ini bug generator, bukan nasib seed.
  invalid,

  /// Ada dua opsi yang tampak sama.
  duplicateOptions,

  /// Solver tidak menemukan tepat satu opsi valid yang sama dengan kunci.
  notExactlyOneValid,
}

final class Rejection {
  const Rejection(this.attempt, this.reason, this.detail);

  final int attempt;
  final RejectionReason reason;
  final String detail;

  @override
  String toString() => 'percobaan $attempt: ${reason.name} ($detail)';
}

final class GenerationFailure implements Exception {
  GenerationFailure({
    required this.type,
    required this.seed,
    required this.difficulty,
    required Iterable<Rejection> rejections,
  }) : rejections = List.unmodifiable(rejections);

  final QuestionType type;
  final int seed;
  final Difficulty difficulty;
  final List<Rejection> rejections;

  @override
  String toString() => 'GenerationFailure(${type.code}, seed $seed, '
      '${difficulty.code}): ${rejections.length} percobaan gagal; '
      '${rejections.join('; ')}';
}

/// Soal beserta jejak pembuatannya, untuk mencatat persentase percobaan ulang.
final class GeneratedQuestion {
  GeneratedQuestion(this.question, Iterable<Rejection> rejections)
      : rejections = List.unmodifiable(rejections);

  final Question question;

  /// Percobaan yang ditolak sebelum [question] diterima.
  final List<Rejection> rejections;

  int get attempts => rejections.length + 1;
}

/// Dasar generator dengan loop percobaan ulang yang sama untuk semua tipe:
///
///     for attempt in 0..19:
///       rng = Rng.derive(seed, attempt); q = build(rng)
///       terima bila format sah, tidak ada opsi kembar, dan
///       solver.validOptions(q) == [q.correctIndex]
///
/// Subkelas cukup mengisi [build] dan [solver].
abstract class RetryingGenerator implements QuestionGenerator {
  const RetryingGenerator();

  static const int maxAttempts = 20;

  QuestionSolver get solver;

  /// Satu percobaan. Semua keacakan diambil dari [rng]; [seed] hanya disalin
  /// ke soal. Kembalikan null bila kandidat tidak bisa dibentuk.
  Question? build(Rng rng, int seed, Difficulty difficulty);

  @override
  Question generate(int seed, Difficulty difficulty) =>
      generateDetailed(seed, difficulty).question;

  GeneratedQuestion generateDetailed(int seed, Difficulty difficulty) {
    RangeError.checkValueInInterval(seed, 0, Question.maxSeed, 'seed');
    final rejections = <Rejection>[];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final q = build(Rng.derive(seed, attempt), seed, difficulty);
      final rejection = q == null
          ? Rejection(attempt, RejectionReason.buildFailed, 'build null')
          : _check(q, attempt, seed, difficulty);
      if (rejection == null) return GeneratedQuestion(q!, rejections);
      rejections.add(rejection);
    }
    throw GenerationFailure(
      type: type,
      seed: seed,
      difficulty: difficulty,
      rejections: rejections,
    );
  }

  Rejection? _check(Question q, int attempt, int seed, Difficulty difficulty) {
    final issues = [
      if (q.type != type) 'type ${q.type.code}, seharusnya ${type.code}',
      if (q.seed != seed) 'seed ${q.seed}, seharusnya $seed',
      if (q.difficulty != difficulty)
        'difficulty ${q.difficulty.code}, seharusnya ${difficulty.code}',
      ...q.validate(),
    ];
    if (issues.isNotEmpty) {
      return Rejection(attempt, RejectionReason.invalid, issues.join('; '));
    }
    final duplicates = duplicateOptionPairs(q);
    if (duplicates.isNotEmpty) {
      return Rejection(
          attempt, RejectionReason.duplicateOptions, duplicates.join(', '));
    }
    final valid = solver.validOptions(q);
    if (valid.length != 1 || valid.single != q.correctIndex) {
      return Rejection(attempt, RejectionReason.notExactlyOneValid,
          'valid $valid, kunci ${q.correctIndex}');
    }
    return null;
  }
}

/// Pasangan indeks opsi yang tampak sama, misalnya `[0, 3]`.
List<List<int>> duplicateOptionPairs(Question q) {
  final firstIndexByKey = <String, int>{};
  final pairs = <List<int>>[];
  for (var i = 0; i < q.options.length; i++) {
    final key = q.options[i].content.visualKey;
    final first = firstIndexByKey[key];
    if (first == null) {
      firstIndexByKey[key] = i;
    } else {
      pairs.add([first, i]);
    }
  }
  return pairs;
}

/// Opsi yang sudah diacak beserta posisi kuncinya.
final class AssembledOptions {
  AssembledOptions(Iterable<Option> options, this.correctIndex)
      : options = List.unmodifiable(options);

  final List<Option> options;
  final int correctIndex;
}

/// Mengacak kunci di antara pengecoh dengan [rng] lalu memberi ID A, B, C, ...
///
/// Setiap posisi punya peluang sama menjadi kunci, sehingga generator yang
/// memakai fungsi ini memenuhi invarian sebaran posisi kunci.
AssembledOptions assembleOptions(
  Rng rng,
  QuestionContent correct,
  List<QuestionContent> distractors,
) {
  final total = distractors.length + 1;
  if (total < Question.minOptions || total > Question.maxOptions) {
    throw ArgumentError.value(distractors.length, 'distractors',
        'total opsi harus ${Question.minOptions}..${Question.maxOptions}');
  }
  final order = rng.shuffle([for (var i = 0; i < total; i++) i]);
  final contents = [correct, ...distractors];
  return AssembledOptions(
    [
      for (var pos = 0; pos < total; pos++)
        Option(id: Option.idFor(pos), content: contents[order[pos]]),
    ],
    order.indexOf(0),
  );
}
