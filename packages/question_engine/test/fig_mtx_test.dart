import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = FigMtxGenerator();
const _solver = FigMtxSolver();

/// Batas khusus FIG-MTX, diperiksa harness pada setiap seed:
/// struktur matriks, isi sel, jumlah opsi, tag aturan sesuai kesulitan,
/// pengecoh (5 sampai 6 melanggar tepat satu aturan, satu salinan sel lain),
/// dan pembahasan.
List<String> figMtxBounds(Question q) {
  final issues = <String>[];
  final figure = q.stem.figure;
  if (figure is! MatrixFigure) return ['stem bukan matrix3x3'];
  if (figure.cells[2][2] != null) issues.add('sel kosong bukan kanan bawah');
  final cellKeys = <String>{};
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 3; c++) {
      final cell = figure.cells[r][c];
      if (r == 2 && c == 2) continue;
      if (cell == null || cell.objects.isEmpty) {
        issues.add('sel [$r][$c] kosong');
      } else {
        cellKeys.add(QuestionContent(figure: cell).visualKey);
      }
    }
  }
  if (q.options.length < 7 || q.options.length > 8) {
    issues.add('jumlah opsi ${q.options.length} di luar 7..8');
  }
  var single = 0;
  var copies = 0;
  for (var i = 0; i < q.options.length; i++) {
    final f = q.options[i].content.figure;
    if (f is! SingleFigure || f.objects.isEmpty) {
      issues.add('opsi $i bukan gambar single berisi');
      continue;
    }
    if (i == q.correctIndex) continue;
    if (_solver.violations(q, i) == 1) single++;
    if (cellKeys.contains(q.options[i].content.visualKey)) copies++;
  }
  if (single < FigMtxGenerator.minSingleViolations) {
    issues.add('hanya $single pengecoh melanggar tepat satu aturan');
  }
  if (copies < 1) issues.add('tidak ada pengecoh salinan sel');

  final rules = q.tags.where((t) => t.startsWith('rule:')).toList();
  final distribution = rules.any((t) => t.startsWith('rule:distribute-row'));
  final ruleIssue = switch (q.difficulty) {
    Difficulty.easy => rules.length != 1 || distribution,
    Difficulty.medium => rules.length != 2 || distribution,
    Difficulty.hard =>
      !(rules.length == 3 || (rules.length == 2 && distribution)),
  };
  if (ruleIssue) issues.add('aturan ${q.difficulty.code} tidak sesuai: $rules');

  final rowRule = rules.any((t) =>
      t.startsWith('rule:constant-row') || t.startsWith('rule:distribute-row'));
  final colRule = rules.length >
      rules
          .where((t) =>
              t.startsWith('rule:constant-row') ||
              t.startsWith('rule:distribute-row'))
          .length;
  if (rowRule && !q.explanation.contains('Baris:')) {
    issues.add('pembahasan tidak menyebut aturan baris');
  }
  if (colRule && !q.explanation.contains('Kolom:')) {
    issues.add('pembahasan tidak menyebut aturan kolom');
  }
  if (!q.explanation.contains('Jadi sel kosong berisi')) {
    issues.add('pembahasan tanpa jawaban');
  }
  return issues;
}

FigureObject _o(Shape s,
        {int count = 1,
        Fill fill = Fill.empty,
        Rotation rotation = Rotation.r0,
        FigureSize size = FigureSize.medium}) =>
    FigureObject(
        shape: s, count: count, fill: fill, rotation: rotation, size: size);

SingleFigure _one(FigureObject o) => SingleFigure([o]);

Question _question(List<List<SingleFigure?>> cells, List<SingleFigure> options,
        {int correctIndex = 0}) =>
    Question(
      type: QuestionType.figMtx,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(
          text: FigMtxGenerator.stemText, figure: MatrixFigure(cells)),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i),
              content: QuestionContent(figure: options[i])),
      ],
      correctIndex: correctIndex,
      explanation: 'uji',
      estimatedSeconds: 30,
    );

void main() {
  PropertyHarness(_generator, _solver, bounds: figMtxBounds).register();

  group('solver', () {
    test('bentuk konstan per baris, jumlah naik per kolom', () {
      SingleFigure cell(Shape s, int n) => _one(_o(s, count: n));
      final q = _question([
        [cell(Shape.circle, 1), cell(Shape.circle, 2), cell(Shape.circle, 3)],
        [cell(Shape.square, 2), cell(Shape.square, 3), cell(Shape.square, 4)],
        [cell(Shape.triangle, 1), cell(Shape.triangle, 2), null],
      ], [
        cell(Shape.triangle, 3),
        cell(Shape.triangle, 4),
        cell(Shape.square, 3),
        cell(Shape.triangle, 2),
      ]);
      expect(_solver.validOptions(q), [0]);
      expect(_solver.violations(q, 1), 1);
      expect(_solver.violations(q, 2), 1);
    });

    test('rotasi bertahap memakai simetri bentuk', () {
      SingleFigure cell(Rotation r) => _one(_o(Shape.triangle, rotation: r));
      final q = _question([
        [cell(Rotation.r0), cell(Rotation.r90), cell(Rotation.r180)],
        [cell(Rotation.r90), cell(Rotation.r180), cell(Rotation.r270)],
        [cell(Rotation.r180), cell(Rotation.r270), null],
      ], [
        cell(Rotation.r0),
        cell(Rotation.r90),
        _one(_o(Shape.pentagon)),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('distribusi tiga nilai per baris', () {
      SingleFigure cell(Fill f) => _one(_o(Shape.diamond, fill: f));
      const e = Fill.empty, s = Fill.solid, h = Fill.hatch;
      final q = _question([
        [cell(e), cell(s), cell(h)],
        [cell(s), cell(h), cell(e)],
        [cell(h), cell(e), null],
      ], [
        cell(e),
        cell(s),
        cell(h),
      ], correctIndex: 1);
      expect(_solver.validOptions(q), [1]);
    });

    test('pengurangan bentuk antar kolom', () {
      SingleFigure set(List<Shape> shapes) =>
          SingleFigure([for (final s in shapes) _o(s)]);
      final q = _question([
        [
          set([Shape.circle, Shape.square]),
          set([Shape.square]),
          set([Shape.circle]),
        ],
        [
          set([Shape.triangle, Shape.cross, Shape.diamond]),
          set([Shape.cross]),
          set([Shape.triangle, Shape.diamond]),
        ],
        [
          set([Shape.circle, Shape.pentagon]),
          set([Shape.circle]),
          null,
        ],
      ], [
        set([Shape.pentagon]),
        set([Shape.circle, Shape.pentagon]),
        set([Shape.circle]),
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('matriks dengan dua tafsiran: lebih dari satu opsi valid', () {
      // Jumlah per baris 1,2,3 dan 1,2,3 dengan baris 3: 2,3. Tafsiran:
      // "naik satu" -> 4, "tiap baris memuat 1, 2, 3" -> 1, dan
      // "kolom 3 = kolom 1 + kolom 2" -> 5 (tidak bisa digambar).
      SingleFigure cell(int n) => _one(_o(Shape.circle, count: n));
      final q = _question([
        [cell(1), cell(2), cell(3)],
        [cell(1), cell(2), cell(3)],
        [cell(2), cell(3), null],
      ], [
        cell(4),
        cell(3),
        cell(1),
      ]);
      expect(_solver.validOptions(q), [0, 2]);
      final p = MtxPrediction.of(q.stem.figure)!;
      expect(p[MtxFeature.count], unorderedEquals([1, 4, 5]));
    });

    test('sel tidak terbaca membuat solver menolak semua opsi', () {
      final cell = _one(_o(Shape.circle));
      final mixed =
          SingleFigure([_o(Shape.circle), _o(Shape.square, fill: Fill.solid)]);
      final q = _question([
        [cell, cell, cell],
        [cell, mixed, cell],
        [cell, cell, null],
      ], [
        cell,
        _one(_o(Shape.square)),
      ]);
      expect(_solver.validOptions(q), isEmpty);
    });

    test('opsi yang hanya beda rotasi tak terlihat tetap valid', () {
      SingleFigure cell(Rotation r) => _one(_o(Shape.circle, rotation: r));
      final q = _question([
        [cell(Rotation.r0), cell(Rotation.r0), cell(Rotation.r0)],
        [cell(Rotation.r0), cell(Rotation.r0), cell(Rotation.r0)],
        [cell(Rotation.r0), cell(Rotation.r0), null],
      ], [
        cell(Rotation.r90),
        _one(_o(Shape.square)),
      ]);
      expect(_solver.validOptions(q), [0]);
    });
  });

  group('aturan', () {
    test('tabrakan ciri dan rotasi dengan bentuk', () {
      const shapeRow = MtxRule(MtxRuleKind.constantRow, MtxFeature.shapes);
      const shapeDist = MtxRule(MtxRuleKind.distributeRow, MtxFeature.shapes);
      const rotate = MtxRule(MtxRuleKind.rotateCol, MtxFeature.rotation);
      const add = MtxRule(MtxRuleKind.addCol, MtxFeature.shapes);
      const countUp = MtxRule(MtxRuleKind.progressCol, MtxFeature.count);
      const fillRow = MtxRule(MtxRuleKind.constantRow, MtxFeature.fill);
      expect(shapeRow.collidesWith(shapeDist), isTrue);
      expect(rotate.collidesWith(shapeRow), isTrue);
      expect(add.collidesWith(rotate), isTrue);
      expect(add.collidesWith(countUp), isTrue);
      expect(fillRow.collidesWith(countUp), isFalse);
      expect(shapeRow.collidesWith(countUp), isFalse);
    });

    test('jumlah aturan per kesulitan, tanpa tabrakan', () {
      for (var seed = 0; seed < 2000; seed++) {
        for (final d in Difficulty.values) {
          final rules = FigMtxGenerator.pickRules(Rng(seed), d)!;
          for (var i = 0; i < rules.length; i++) {
            for (var j = i + 1; j < rules.length; j++) {
              expect(rules[i].collidesWith(rules[j]), isFalse);
            }
          }
          final dist = rules.any((r) => r.kind == MtxRuleKind.distributeRow);
          switch (d) {
            case Difficulty.easy:
              expect(rules, hasLength(1));
              expect(dist, isFalse);
            case Difficulty.medium:
              expect(rules, hasLength(2));
              expect(dist, isFalse);
            case Difficulty.hard:
              expect(rules.length == 3 || (rules.length == 2 && dist), isTrue);
          }
        }
      }
    });

    test('semua jenis aturan muncul', () {
      final tags = <String>{};
      for (var seed = 0; seed < 600; seed++) {
        for (final d in Difficulty.values) {
          tags.addAll(_generator.generate(seed, d).tags);
        }
      }
      for (final kind in MtxRuleKind.values) {
        expect(tags.any((t) => t.startsWith('rule:${kind.code}')), isTrue,
            reason: kind.code);
      }
    });
  });

  group('nilai emas lintas platform', () {
    // Dihasilkan dari generator v1. Bila berubah, naikkan version generator.
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, _golden20481Tags);
      expect(q.correctIndex, _golden20481Index);
      expect(q.explanation, _golden20481Explanation);
    });
  });
}

const List<String> _golden20481Tags = [
  'rule:constant-row:rotation',
  'rule:constant-row:fill',
];
const int _golden20481Index = 2;
const String _golden20481Explanation =
    'Baris: rotasi sama dalam satu baris (baris 1 90°, baris 2 180°, '
    'baris 3 0°). Baris: isian sama dalam satu baris (baris 1 penuh, '
    'baris 2 arsir, baris 3 kosong). Di semua sel, bentuk tetap segi lima, '
    'jumlah tetap 1, dan ukuran tetap besar. Jadi sel kosong berisi '
    '1 segi lima, isian kosong, ukuran besar, rotasi 0°.';
