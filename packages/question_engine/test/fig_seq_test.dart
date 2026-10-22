import 'dart:convert';

import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = FigSeqGenerator();
const _solver = FigSeqSolver();

List<String> figSeqBounds(Question q) {
  final issues = <String>[];
  final stem = q.stem.figure;
  if (stem is! SequenceFigure) return ['stem bukan sequence'];
  if (stem.items.length < 4 || stem.items.length > 5) {
    issues.add('deret berisi ${stem.items.length} gambar');
  }
  if (stem.items.last != null) issues.add('sel terakhir tidak kosong');
  for (final item in stem.items.take(stem.items.length - 1)) {
    if (item == null || item.objects.length != 1) {
      issues.add('gambar terlihat bukan satu objek');
    }
  }
  final wantOptions = FigSeqGenerator.distractorCount(q.difficulty) + 1;
  if (q.options.length != wantOptions) {
    issues.add('jumlah opsi ${q.options.length}, seharusnya $wantOptions');
  }
  final rules = q.tags.where((t) => t.startsWith('rule:seq-')).length;
  if (rules != FigSeqGenerator.changingCount(q.difficulty)) {
    issues.add('${q.tags} tidak cocok dengan ${q.difficulty.code}');
  }
  // Semua pengecoh melanggar tepat satu aturan.
  for (var i = 0; i < q.options.length; i++) {
    if (i == q.correctIndex) continue;
    if (_solver.violations(q, i) != 1) {
      issues.add('pengecoh $i melanggar ${_solver.violations(q, i)} aturan');
    }
  }
  if (!q.explanation.contains('Jadi gambar ke-${stem.items.length}')) {
    issues.add('pembahasan tanpa jawaban');
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

Question _question(List<SingleFigure?> items, List<SingleFigure> options) =>
    Question(
      type: QuestionType.figSeq,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(text: 'uji', figure: SequenceFigure(items)),
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
  PropertyHarness(_generator, _solver, bounds: figSeqBounds).register();

  group('SequenceFigure', () {
    test('JSON bolak-balik dan validasi', () {
      final f = SequenceFigure([
        _one(Shape.circle),
        _one(Shape.circle, count: 2),
        _one(Shape.circle, count: 3),
        null,
      ]);
      final back = FigureSpec.fromJson(jsonDecode(jsonEncode(f.toJson())));
      expect(back, isA<SequenceFigure>());
      expect(jsonEncode(back.toJson()), jsonEncode(f.toJson()));
      expect(f.validate('s'), isEmpty);
      expect(
          SequenceFigure([_one(Shape.circle), null]).validate('s'), isNotEmpty);
      expect(
          SequenceFigure([
            _one(Shape.circle),
            null,
            _one(Shape.circle),
            _one(Shape.circle),
          ]).validate('s'),
          isNotEmpty);
    });
  });

  group('solver', () {
    test('jumlah naik satu tiap langkah', () {
      final q = _question([
        _one(Shape.square, count: 1),
        _one(Shape.square, count: 2),
        _one(Shape.square, count: 3),
        null,
      ], [
        _one(Shape.square, count: 4),
        _one(Shape.square, count: 3),
        _one(Shape.circle, count: 4),
      ]);
      expect(_solver.validOptions(q), [0]);
      expect(_solver.violations(q, 1), 1);
      expect(_solver.violations(q, 2), 1);
    });

    test('rotasi bertahap pada bentuk tak simetris', () {
      final q = _question([
        _one(Shape.triangle, rotation: Rotation.r0),
        _one(Shape.triangle, rotation: Rotation.r90),
        _one(Shape.triangle, rotation: Rotation.r180),
        null,
      ], [
        _one(Shape.triangle, rotation: Rotation.r270),
        _one(Shape.triangle, rotation: Rotation.r0),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('isian bergantian dua nilai', () {
      final q = _question([
        _one(Shape.cross, fill: Fill.solid),
        _one(Shape.cross, fill: Fill.empty),
        _one(Shape.cross, fill: Fill.solid),
        _one(Shape.cross, fill: Fill.empty),
        null,
      ], [
        _one(Shape.cross, fill: Fill.solid),
        _one(Shape.cross, fill: Fill.empty),
        _one(Shape.cross, fill: Fill.hatch),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('ukuran berulang tiga langkah melingkar', () {
      final q = _question([
        _one(Shape.diamond, size: FigureSize.medium),
        _one(Shape.diamond, size: FigureSize.large),
        _one(Shape.diamond, size: FigureSize.small),
        null,
      ], [
        _one(Shape.diamond, size: FigureSize.medium),
        _one(Shape.diamond, size: FigureSize.large),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('ramalan tiap ciri untuk deret pendek', () {
      final p = SeqPrediction.of(SequenceFigure([
        _one(Shape.circle, count: 1),
        _one(Shape.circle, count: 2),
        _one(Shape.circle, count: 1),
        null,
      ]))!;
      expect(p[MtxFeature.count], {2});
      final q = SeqPrediction.of(SequenceFigure([
        _one(Shape.circle, count: 1),
        _one(Shape.circle, count: 2),
        _one(Shape.circle, count: 3),
        _one(Shape.circle, count: 1),
        null,
      ]))!;
      expect(q[MtxFeature.count], {2});
    });

    test('deret ambigu: dua tafsiran menghasilkan dua ramalan', () {
      // Jumlah 2, 3, 4: naik satu (-> 5, di luar domain) atau tetap bila
      // dilihat melingkar tidak dikenal; ramalan hanya yang di domain.
      final p = SeqPrediction.of(SequenceFigure([
        _one(Shape.circle, count: 2),
        _one(Shape.circle, count: 3),
        _one(Shape.circle, count: 4),
        null,
      ]))!;
      expect(p[MtxFeature.count], isEmpty);
    });

    test('deret yang bukan sequence tidak punya opsi valid', () {
      final q = Question(
        type: QuestionType.figSeq,
        seed: 1,
        difficulty: Difficulty.easy,
        stem: QuestionContent(text: 'uji', figure: _one(Shape.circle)),
        options: [
          Option(id: 'A', content: QuestionContent(figure: _one(Shape.circle))),
          Option(id: 'B', content: QuestionContent(figure: _one(Shape.square))),
        ],
        correctIndex: 0,
        explanation: 'x',
        estimatedSeconds: 10,
      );
      expect(_solver.validOptions(q), isEmpty);
    });
  });

  test('semua ciri muncul sebagai aturan', () {
    final tags = <String>{};
    for (var s = 0; s < 500; s++) {
      tags.addAll(_generator.generate(s, Difficulty.hard).tags);
    }
    expect(tags, {
      for (final f in MtxFeature.values) 'rule:seq-${f.code}',
    });
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:seq-count', 'rule:seq-rotation']);
      expect(q.correctIndex, 4);
      expect(q.explanation,
          'Jumlah: bertambah 1 tiap langkah, dari 1 sampai 4. Rotasi: gambar berputar 90° berlawanan arah jarum jam tiap langkah. Di semua gambar, bentuk tetap segi lima, isian tetap penuh, dan ukuran tetap besar. Jadi gambar ke-4: 4 segi lima, isian penuh, ukuran besar, rotasi 180°.');
    });
  });
}
