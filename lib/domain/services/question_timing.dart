import 'package:question_engine/question_engine.dart';

/// Perkiraan waktu per soal dari engine, dipakai selama riwayat belum ada
/// (docs/03-data-model.md, langkah 1 rencana harian dan label cepat-lambat).
abstract final class QuestionTiming {
  /// Dipakai bila generator tidak bisa menghasilkan soal contoh.
  static const int fallbackSeconds = 60;

  static const int _probeSeed = 1;
  static final Map<QuestionType, int> _cache = {};

  /// `estimatedSeconds` soal contoh medium dari generator [type]. Nilainya
  /// ditentukan kesulitan, bukan seed, jadi satu soal contoh cukup.
  static int estimatedSeconds(QuestionType type) =>
      _cache[type] ??= _probe(type);

  static int _probe(QuestionType type) {
    if (!GeneratorRegistry.has(type)) return fallbackSeconds;
    try {
      return GeneratorRegistry.generate(type, _probeSeed, Difficulty.medium)
          .estimatedSeconds;
    } on GenerationFailure {
      return fallbackSeconds;
    }
  }

  /// Median perkiraan untuk beberapa tipe; [fallbackSeconds] bila kosong.
  static int medianOf(Iterable<QuestionType> types) {
    final seconds = [for (final t in types) estimatedSeconds(t)]..sort();
    if (seconds.isEmpty) return fallbackSeconds;
    final mid = seconds.length ~/ 2;
    return seconds.length.isOdd
        ? seconds[mid]
        : ((seconds[mid - 1] + seconds[mid]) / 2).round();
  }
}
