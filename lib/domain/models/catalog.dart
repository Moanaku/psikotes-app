import 'package:question_engine/question_engine.dart';

/// Nama tipe soal untuk layar (katalog S05, kelemahan S04). `switch` tanpa
/// cabang bawaan: tipe baru di engine membuat kode ini gagal dikompilasi sampai
/// diberi nama.
String questionTypeName(QuestionType type) => switch (type) {
      QuestionType.numSeq => 'Deret angka',
      QuestionType.numAri => 'Hitungan cepat',
      QuestionType.numWord => 'Soal cerita',
      QuestionType.logSyl => 'Silogisme',
      QuestionType.figMir => 'Cermin',
      QuestionType.figSeq => 'Deret gambar',
      QuestionType.figMtx => 'Matriks 3x3',
      QuestionType.figOdd => 'Beda sendiri',
      QuestionType.vrbSyn => 'Sinonim / antonim',
      QuestionType.vrbAna => 'Analogi',
      QuestionType.vrbRc => 'Bacaan',
      QuestionType.krp => 'Kraepelin / Pauli',
      QuestionType.itPse => 'Pseudocode',
      QuestionType.itFlw => 'Flowchart',
      QuestionType.itXls => 'Excel',
      QuestionType.perPapi => 'Papi-style',
      QuestionType.perDisc => 'DISC-style',
    };

/// Rilis tempat tipe soal masuk (docs/07-rencana-tugas.md). Dipakai untuk
/// alasan "Tersedia di v1.1" saat tipe belum punya generator terdaftar.
enum Release {
  v1('v1.0'),
  v11('v1.1');

  const Release(this.label);
  final String label;
}

Release questionTypeRelease(QuestionType type) => switch (type) {
      QuestionType.numSeq ||
      QuestionType.numAri ||
      QuestionType.numWord ||
      QuestionType.logSyl ||
      QuestionType.figMir ||
      QuestionType.figSeq ||
      QuestionType.figMtx ||
      QuestionType.figOdd ||
      QuestionType.vrbSyn ||
      QuestionType.vrbAna =>
        Release.v1,
      QuestionType.vrbRc ||
      QuestionType.krp ||
      QuestionType.itPse ||
      QuestionType.itFlw ||
      QuestionType.itXls ||
      QuestionType.perPapi ||
      QuestionType.perDisc =>
        Release.v11,
    };
