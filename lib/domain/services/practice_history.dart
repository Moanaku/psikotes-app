import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/session.dart';
import '../repositories/repositories.dart';
import 'scoring.dart';
import 'seed_allocator.dart';
import 'verbal_bank.dart';

/// Riwayat jawaban 30 hari terakhir sebagai masukan perencana
/// (docs/03-data-model.md, "Rencana latihan harian").
class PracticeHistory {
  /// [answers] urut dari yang terbaru, seperti `AnswerRepository.since`.
  PracticeHistory(Iterable<AnswerRecord> answers)
      : answers = List.unmodifiable(answers);

  static Future<PracticeHistory> load(
    AnswerRepository repository,
    DateTime now,
  ) async =>
      PracticeHistory(await repository.since(now.subtract(Scoring.window)));

  final List<AnswerRecord> answers;

  bool get isEmpty => answers.isEmpty;

  /// Pasangan (tipe, seed) soal engine dan (tipe, nomor butir) soal bank yang
  /// sudah muncul; dipakai `ItemAllocator` agar soal tidak berulang dalam 30
  /// hari.
  Set<String> get seenKeys => {
        for (final a in answers)
          if (a.sumber == AnswerSource.engine)
            '${a.tipe}:${a.seed}'
          else if (a.sumber == AnswerSource.bank && a.refId != null)
            VerbalBank.keyOf(a.tipe, a.refId!),
      };

  /// Median detik per soal dari jawaban yang benar-benar dikerjakan (bukan
  /// yang dilewati, durasinya terpotong); null bila belum ada.
  int? get medianSeconds {
    final ms = Scoring.median([
      for (final a in answers)
        if (a.opsiDipilih != null && a.durasiMs > 0) a.durasiMs,
    ]);
    return ms == null ? null : (ms / 1000).round().clamp(1, 600);
  }

  /// Jawaban soal engine atau bank dengan tipe yang dikenal engine, urut dari
  /// yang terbaru.
  Iterable<(QuestionType, AnswerRecord)> typedAnswers() sync* {
    for (final a in answers) {
      if (a.sumber != AnswerSource.engine && a.sumber != AnswerSource.bank) {
        continue;
      }
      final type = _typeOf(a.tipe);
      if (type != null) yield (type, a);
    }
  }

  static QuestionType? _typeOf(String code) {
    for (final t in QuestionType.values) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// Kunci pasangan (tipe, seed) untuk [SeedAllocator.avoid].
  static String keyOf(QuestionType type, int seed) =>
      SeedAllocator.key(type, seed);
}
