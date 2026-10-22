import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = FigOddGenerator();
const _solver = FigOddSolver();

List<String> figOddBounds(Question q) {
  final issues = <String>[];
  if (q.stem.figure != null) issues.add('stem seharusnya hanya teks');
  if (q.options.length != FigOddGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  final cells = [
    for (final o in q.options) MtxCell.parse(o.content.figure),
  ];
  if (cells.any((c) => c == null)) return [...issues, 'opsi tidak terbaca'];
  final parsed = [for (final c in cells) c!];
  final features = FigOddSolver.oddFeatures(parsed, q.correctIndex);
  final shared = q.tags.where((t) => t.startsWith('rule:odd-shared:')).length;
  if (shared != FigOddGenerator.sharedCount(q.difficulty)) {
    issues.add('${q.tags} tidak cocok dengan ${q.difficulty.code}');
  }
  // Pelanggar berbeda dari yang lain pada tepat satu ciri aturan.
  final oddTag = q.tags.firstWhere((t) => t.startsWith('odd:'));
  if (!features.map((f) => 'odd:${f.code}').contains(oddTag)) {
    issues.add('ciri pelanggar $oddTag tidak terdeteksi: $features');
  }
  if (q.difficulty == Difficulty.hard &&
      !FigOddGenerator.subtle.map((f) => 'odd:${f.code}').contains(oddTag)) {
    issues.add('pelanggar hard bukan ciri halus: $oddTag');
  }
  final letter = Option.idFor(q.correctIndex);
  if (!q.explanation.contains('Gambar $letter berbeda')) {
    issues.add('pembahasan tidak menyebut gambar $letter');
  }
  return issues;
}

SingleFigure _one(Shape s,
        {int count = 1,
        Fill fill = Fill.empty,
        Rotation rotation = Rotation.r0,
        FigureSize size = FigureSize.medium}) =>
    SingleFigure([
      FigureObject(
          shape: s, count: count, fill: fill, rotation: rotation, size: size),
    ]);

Question _question(List<SingleFigure> options) => Question(
      type: QuestionType.figOdd,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: const QuestionContent(text: FigOddGenerator.stemText),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i),
              content: QuestionContent(figure: options[i])),
      ],
      correctIndex: 0,
      explanation: 'uji',
      estimatedSeconds: 30,
    );

void main() {
  PropertyHarness(_generator, _solver, bounds: figOddBounds).register();

  group('solver', () {
    test('satu gambar berbeda pada bentuk', () {
      final q = _question([
        _one(Shape.square, fill: Fill.solid),
        _one(Shape.circle, count: 2, fill: Fill.solid),
        _one(Shape.circle, count: 1, fill: Fill.solid),
        _one(Shape.circle, count: 3, fill: Fill.solid),
        _one(Shape.circle, count: 4, fill: Fill.solid),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('rotasi lingkaran tidak terlihat sehingga tidak membedakan', () {
      final q = _question([
        _one(Shape.circle, rotation: Rotation.r90, count: 1),
        _one(Shape.circle, count: 2),
        _one(Shape.circle, count: 3),
        _one(Shape.circle, count: 4),
        _one(Shape.circle, count: 2, size: FigureSize.small),
      ]);
      // Ukuran: gambar 4 berbeda dari empat lain yang sama. Rotasi tidak.
      expect(_solver.validOptions(q), [4]);
    });

    test('dua gambar sama-sama berbeda pada ciri berlainan: ambigu', () {
      final ambiguous = _question([
        _one(Shape.square, fill: Fill.empty),
        _one(Shape.circle, count: 2, fill: Fill.solid),
        _one(Shape.circle, count: 3, fill: Fill.empty),
        _one(Shape.circle, count: 4, fill: Fill.empty),
        _one(Shape.circle, count: 1, fill: Fill.empty),
      ]);
      expect(_solver.validOptions(ambiguous), [0, 1]);
    });

    test('opsi yang bukan satu objek tidak terbaca', () {
      final two = SingleFigure([
        const FigureObject(shape: Shape.circle),
        const FigureObject(shape: Shape.circle),
      ]);
      expect(_solver.validOptions(_question([two, two])), isEmpty);
    });
  });

  test('pelanggar tersebar di semua posisi opsi', () {
    final positions = <int>{
      for (var s = 0; s < 200; s++)
        _generator.generate(s, Difficulty.medium).correctIndex,
    };
    expect(positions, {0, 1, 2, 3, 4});
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags,
          ['rule:odd-shared:size', 'rule:odd-shared:count', 'odd:size']);
      expect(q.correctIndex, 2);
      expect(q.explanation,
          'Empat gambar punya ukuran sedang dan jumlah 4 yang sama. Gambar C berbeda: ukuran besar, sedangkan yang lain sedang. Ciri lain berbeda-beda antar gambar sehingga tidak menjadi aturan.');
    });
  });
}
