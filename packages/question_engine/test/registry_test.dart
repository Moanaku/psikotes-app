import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

void main() {
  test('tiap entri cocok dengan tipenya dan menghasilkan soal sah', () {
    expect(GeneratorRegistry.types, isNotEmpty);
    for (final type in GeneratorRegistry.types) {
      expect(GeneratorRegistry.generator(type).type, type);
      for (final d in Difficulty.values) {
        final q = GeneratorRegistry.generate(type, 42, d);
        expect(q.type, type);
        expect(q.validate(), isEmpty);
        expect(
            GeneratorRegistry.solver(type).validOptions(q), [q.correctIndex]);
      }
    }
  });

  test('tipe figural, numerik, dan logika v1 terdaftar', () {
    expect(
        GeneratorRegistry.types,
        containsAll([
          QuestionType.figMtx,
          QuestionType.figMir,
          QuestionType.figSeq,
          QuestionType.figOdd,
          QuestionType.numSeq,
          QuestionType.numAri,
          QuestionType.numWord,
          QuestionType.logSyl,
        ]));
  });

  test('tipe yang belum terdaftar ditolak dengan pesan jelas', () {
    expect(GeneratorRegistry.has(QuestionType.krp), isFalse);
    expect(() => GeneratorRegistry.generator(QuestionType.krp),
        throwsA(isA<ArgumentError>()));
  });
}
