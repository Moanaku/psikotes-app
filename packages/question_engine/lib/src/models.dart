/// Model soal keluaran engine (docs/06-bank-konten.md, "Format soal").
///
/// Semua model tidak dapat diubah dan tidak menimpa `==` atau `hashCode`.
/// Dua soal identik bila [Question.toJson] menghasilkan JSON yang sama;
/// dua opsi kembar bila [QuestionContent.visualKey] sama.
library;

import 'dart:convert';

import 'figure_spec.dart';
import 'json_utils.dart';

enum QuestionCategory {
  verbal('verbal'),
  numerik('numerik'),
  logika('logika'),
  figural('figural'),
  kraepelin('kraepelin'),
  kepribadian('kepribadian'),
  it('it'),
  pengetahuan('pengetahuan');

  const QuestionCategory(this.code);

  final String code;

  static QuestionCategory fromCode(String code) =>
      enumByCode(values, code, (v) => v.code);
}

enum Difficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const Difficulty(this.code);

  final String code;

  static Difficulty fromCode(String code) =>
      enumByCode(values, code, (v) => v.code);
}

/// Katalog tipe soal (docs/06-bank-konten.md, "Katalog tipe soal").
///
/// KB-* tidak ada di sini: butir pengetahuan role punya ID sendiri di bank dan
/// bukan soal pilihan ganda. KRP dan PER-* tercatat sebagai tipe, tetapi bentuk
/// soalnya (isian, tanpa kunci) ditentukan oleh tugasnya masing-masing.
enum QuestionType {
  numSeq('NUM-SEQ', QuestionCategory.numerik),
  numAri('NUM-ARI', QuestionCategory.numerik),
  numWord('NUM-WORD', QuestionCategory.numerik),
  logSyl('LOG-SYL', QuestionCategory.logika),
  figMir('FIG-MIR', QuestionCategory.figural),
  figSeq('FIG-SEQ', QuestionCategory.figural),
  figMtx('FIG-MTX', QuestionCategory.figural),
  figOdd('FIG-ODD', QuestionCategory.figural),
  vrbSyn('VRB-SYN', QuestionCategory.verbal),
  vrbAna('VRB-ANA', QuestionCategory.verbal),
  vrbRc('VRB-RC', QuestionCategory.verbal),
  krp('KRP', QuestionCategory.kraepelin),
  itPse('IT-PSE', QuestionCategory.it),
  itFlw('IT-FLW', QuestionCategory.it),
  itXls('IT-XLS', QuestionCategory.it),
  perPapi('PER-PAPI', QuestionCategory.kepribadian),
  perDisc('PER-DISC', QuestionCategory.kepribadian);

  const QuestionType(this.code, this.category);

  final String code;
  final QuestionCategory category;

  static QuestionType fromCode(String code) =>
      enumByCode(values, code, (v) => v.code);
}

/// Isi stem atau opsi: teks, gambar, atau keduanya.
final class QuestionContent {
  const QuestionContent({this.text, this.figure});

  final String? text;
  final FigureSpec? figure;

  bool get isEmpty => text == null && figure == null;

  /// Kunci pembanding opsi kembar: teks dirapikan (spasi dan huruf besar
  /// diabaikan) dan gambar dikanonikkan sesuai simetri bentuk.
  String get visualKey => jsonEncode({
        if (text != null)
          'text': text!.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
        if (figure != null) 'figure': figure!.canonical().toJson(),
      });

  List<String> validate(String path) => [
        if (isEmpty) '$path harus punya text atau figure',
        if (text != null && text!.trim().isEmpty) '$path.text kosong',
        ...?figure?.validate('$path.figure'),
      ];

  Map<String, Object?> toJson() => {
        if (text != null) 'text': text,
        if (figure != null) 'figure': figure!.toJson(),
      };

  factory QuestionContent.fromJson(Object? json) {
    final m = asJsonMap(json, 'isi');
    final figure = m['figure'];
    return QuestionContent(
      text: readOptionalString(m, 'text'),
      figure: figure == null ? null : FigureSpec.fromJson(figure),
    );
  }
}

final class Option {
  const Option({required this.id, required this.content});

  /// Huruf posisi: "A" untuk opsi pertama, "B" untuk kedua, dan seterusnya.
  final String id;
  final QuestionContent content;

  static String idFor(int index) => String.fromCharCode(0x41 + index);

  Map<String, Object?> toJson() => {'id': id, 'content': content.toJson()};

  factory Option.fromJson(Object? json) {
    final m = asJsonMap(json, 'opsi');
    return Option(
      id: readString(m, 'id'),
      content: QuestionContent.fromJson(m['content']),
    );
  }
}

final class Question {
  static const int minOptions = 2;
  static const int maxOptions = 8;
  static const int maxSeed = 0xFFFFFFFF;
  static const int maxEstimatedSeconds = 600;

  Question({
    required this.type,
    required this.seed,
    required this.difficulty,
    required this.stem,
    required Iterable<Option> options,
    required this.correctIndex,
    required this.explanation,
    required this.estimatedSeconds,
    Iterable<String> tags = const [],
  })  : options = List.unmodifiable(options),
        tags = List.unmodifiable(tags);

  final QuestionType type;

  /// Seed asal (bukan seed turunan percobaan ulang), 0 sampai 2^32 - 1.
  final int seed;
  final Difficulty difficulty;
  final QuestionContent stem;
  final List<Option> options;
  final int correctIndex;
  final String explanation;
  final int estimatedSeconds;
  final List<String> tags;

  QuestionCategory get category => type.category;

  /// Pelanggaran aturan format. Kosong berarti soal sah secara bentuk; benar
  /// tidaknya kunci dibuktikan solver, bukan di sini.
  List<String> validate() {
    final issues = <String>[];
    if (seed < 0 || seed > maxSeed) issues.add('seed di luar 0..$maxSeed');
    issues.addAll(stem.validate('stem'));
    if (options.length < minOptions || options.length > maxOptions) {
      issues.add('jumlah opsi ${options.length} di luar '
          '$minOptions..$maxOptions');
    }
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      if (o.id != Option.idFor(i)) {
        issues.add('options[$i].id "${o.id}", seharusnya "${Option.idFor(i)}"');
      }
      issues.addAll(o.content.validate('options[$i].content'));
    }
    if (correctIndex < 0 || correctIndex >= options.length) {
      issues.add('correctIndex $correctIndex di luar rentang opsi');
    }
    if (explanation.trim().isEmpty) issues.add('explanation kosong');
    if (estimatedSeconds < 1 || estimatedSeconds > maxEstimatedSeconds) {
      issues.add('estimatedSeconds $estimatedSeconds di luar '
          '1..$maxEstimatedSeconds');
    }
    for (final t in tags) {
      if (t.trim().isEmpty) issues.add('tag kosong');
    }
    if (tags.toSet().length != tags.length) issues.add('tag kembar');
    return issues;
  }

  Map<String, Object?> toJson() => {
        'type': type.code,
        'category': category.code,
        'seed': seed,
        'difficulty': difficulty.code,
        'stem': stem.toJson(),
        'options': [for (final o in options) o.toJson()],
        'correctIndex': correctIndex,
        'explanation': explanation,
        'estimatedSeconds': estimatedSeconds,
        'tags': tags,
      };

  factory Question.fromJson(Object? json) {
    final m = asJsonMap(json, 'soal');
    final type = QuestionType.fromCode(readString(m, 'type'));
    final category = QuestionCategory.fromCode(readString(m, 'category'));
    if (category != type.category) {
      throw FormatException(
          'category ${category.code} tidak cocok dengan tipe ${type.code}');
    }
    return Question(
      type: type,
      seed: readInt(m, 'seed'),
      difficulty: Difficulty.fromCode(readString(m, 'difficulty')),
      stem: QuestionContent.fromJson(m['stem']),
      options: readList(m, 'options').map(Option.fromJson),
      correctIndex: readInt(m, 'correctIndex'),
      explanation: readString(m, 'explanation'),
      estimatedSeconds: readInt(m, 'estimatedSeconds'),
      tags: [
        for (final t in readList(m, 'tags'))
          t is String ? t : throw const FormatException('tag bukan string'),
      ],
    );
  }
}
