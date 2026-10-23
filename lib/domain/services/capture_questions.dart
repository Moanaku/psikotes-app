import 'package:question_engine/question_engine.dart';

import '../models/notebook.dart';

/// Mengubah soal Capture (F09) menjadi `Question` agar bisa dikerjakan oleh
/// `SessionController` dan ditampilkan layar sesi seperti soal engine.
///
/// `Question` milik engine menuntut `QuestionType` dari katalog, sedangkan
/// kategori Capture buatan pengguna. Tipe di bawah hanya pengisi: tidak ada
/// kode yang membaca `Question.type` untuk soal Capture; identitas soal
/// (sumber, ref_id, kategori) ada di `PlanItem` (A85).
abstract final class CaptureQuestions {
  static const QuestionType _placeholder = QuestionType.vrbRc;

  /// Perkiraan waktu per soal Capture bila belum ada riwayat.
  static const int estimatedSeconds = 60;

  /// Teks stem bagi soal yang hanya berisi foto.
  static const String photoOnlyStem = 'Lihat foto soal.';

  static Question toQuestion(CapturedQuestion c) {
    final letter = Option.idFor(c.kunci);
    final note = c.pembahasan?.trim() ?? '';
    return Question(
      type: _placeholder,
      seed: c.id ?? 0,
      difficulty: Difficulty.medium,
      stem: QuestionContent(
        text: c.teks.trim().isEmpty ? photoOnlyStem : c.teks.trim(),
      ),
      options: [
        for (var i = 0; i < c.opsi.length; i++)
          Option(
            id: Option.idFor(i),
            content: QuestionContent(text: c.opsi[i]),
          ),
      ],
      correctIndex: c.kunci,
      explanation: note.isEmpty
          ? 'Kunci jawaban: $letter. Soal ini belum punya pembahasan. Ubah '
              'soalnya di Capture untuk menambahkannya.'
          : note,
      estimatedSeconds: estimatedSeconds,
    );
  }
}
