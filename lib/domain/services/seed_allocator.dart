import 'package:question_engine/question_engine.dart';

/// Membagikan seed soal dari satu dasar waktu tanpa pernah mengulang pasangan
/// (tipe, seed) yang sudah dipakai: pasangan yang muncul dalam 30 hari terakhir
/// ([avoid]) dan pasangan yang sudah dibagikan di rencana yang sama
/// (docs/03-data-model.md, "Rencana latihan harian", langkah 5).
///
/// Tanpa tabrakan, seed ke-n adalah `base + n * 7919 + type.index * 104729`
/// (mod 2^31 - 1), jadi hasilnya sama dengan rumus lama `SessionPlanBuilder`.
class SeedAllocator {
  SeedAllocator(this.base, {Iterable<String> avoid = const []})
      : _taken = {...avoid};

  final int base;
  final Set<String> _taken;
  int _counter = 0;

  /// Modulus seed: seed selalu 0 sampai 2^31 - 2, di rentang yang dipahami
  /// `Rng` di engine.
  static const int modulus = 0x7FFFFFFF;

  /// Kunci pasangan (tipe, seed) di himpunan `avoid`.
  static String key(QuestionType type, int seed) => '${type.code}:$seed';

  static int seedFor(int base, int index, QuestionType type) =>
      (base + index * 7919 + type.index * 104729) % modulus;

  /// Seed berikutnya untuk [type] yang belum pernah dipakai.
  int next(QuestionType type) {
    while (true) {
      final seed = seedFor(base, _counter++, type);
      if (_taken.add(key(type, seed))) return seed;
    }
  }
}
