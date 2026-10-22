import 'dart:convert';

import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = FigMirGenerator();
const _solver = FigMirSolver();

List<String> figMirBounds(Question q) {
  final issues = <String>[];
  final stem = q.stem.figure;
  final axis = MirrorAxis.fromStem(q.stem.text);
  if (axis == null) issues.add('teks soal tidak dikenal: ${q.stem.text}');
  if (stem is! GridFigure) return [...issues, 'stem bukan grid'];
  final (lo, hi) = FigMirGenerator.cellRange(q.difficulty);
  if (stem.filledCount < lo || stem.filledCount > hi) {
    issues.add('sel berisi ${stem.filledCount} di luar $lo..$hi');
  }
  if (q.options.length != FigMirGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  for (var i = 0; i < q.options.length; i++) {
    final f = q.options[i].content.figure;
    if (f is! GridFigure) {
      issues.add('opsi $i bukan grid');
    } else if (f.filledCount != stem.filledCount) {
      issues
          .add('opsi $i berisi ${f.filledCount} sel, asli ${stem.filledCount}');
    }
  }
  if (axis != null) {
    // Bentuk asimetris pada sumbu yang ditanyakan.
    if (gridKey(axis.apply(stem)) == gridKey(stem)) {
      issues.add('bentuk simetris pada sumbu ${axis.code}');
    }
    // Pengecoh yang diharapkan ada: bentuk asli tidak dicerminkan atau
    // cermin sumbu lain atau putaran tidak boleh sama dengan kunci.
    final correct = q.options[q.correctIndex].content.figure as GridFigure;
    if (gridKey(correct) != gridKey(axis.apply(stem))) {
      issues.add('kunci bukan hasil cermin');
    }
  }
  if (!q.explanation.contains('sumbu')) issues.add('pembahasan tanpa sumbu');
  return issues;
}

void main() {
  PropertyHarness(_generator, _solver, bounds: figMirBounds).register();

  GridFigure g(List<String> rows) => GridFigure([
        for (final r in rows) [for (final ch in r.split('')) ch == '#'],
      ]);

  group('GridFigure', () {
    final shape = g(['##..', '.#..', '.##.', '....']);

    test('cermin kiri-kanan dan atas-bawah', () {
      expect(shape.mirrorLeftRight().rowText(0), '..##');
      expect(shape.mirrorLeftRight().rowText(2), '.##.');
      expect(shape.mirrorTopBottom().rowText(0), '....');
      expect(shape.mirrorTopBottom().rowText(1), '.##.');
      expect(shape.mirrorTopBottom().rowText(3), '##..');
    });

    test('putar 4 kali kembali ke asal; putar 2 sama dengan dua cermin', () {
      expect(shape.rotate(4).toJson(), shape.toJson());
      expect(shape.rotate(2).toJson(),
          shape.mirrorLeftRight().mirrorTopBottom().toJson());
    });

    test('kanonik menggeser ke pojok kiri atas', () {
      final shifted = g(['....', '..##', '...#', '....']);
      expect(shifted.canonical().rowText(0), '##..');
      expect(gridKey(shifted), gridKey(g(['##..', '.#..', '....', '....'])));
    });

    test('JSON bolak-balik dan validasi', () {
      final back = FigureSpec.fromJson(jsonDecode(jsonEncode(shape.toJson())));
      expect(back, isA<GridFigure>());
      expect(jsonEncode(back.toJson()), jsonEncode(shape.toJson()));
      expect(
          GridFigure([
            [true]
          ]).validate('g'),
          isNotEmpty);
      expect(g(['....', '....', '....', '....']).validate('g'), isNotEmpty);
    });
  });

  group('solver', () {
    Question make(MirrorAxis axis, GridFigure stem, List<GridFigure> options) =>
        Question(
          type: QuestionType.figMir,
          seed: 1,
          difficulty: Difficulty.easy,
          stem: QuestionContent(text: axis.stemText, figure: stem),
          options: [
            for (var i = 0; i < options.length; i++)
              Option(
                  id: Option.idFor(i),
                  content: QuestionContent(figure: options[i])),
          ],
          correctIndex: 0,
          explanation: 'uji sumbu',
          estimatedSeconds: 30,
        );

    final shape = g(['###.', '#...', '....', '....']);

    test('cermin vertikal memilih kiri-kanan, horizontal atas-bawah', () {
      final options = [
        shape.mirrorLeftRight(),
        shape.mirrorTopBottom(),
        shape,
        shape.rotate(1),
      ];
      expect(
          _solver.validOptions(make(MirrorAxis.vertical, shape, options)), [0]);
      expect(_solver.validOptions(make(MirrorAxis.horizontal, shape, options)),
          [1]);
    });

    test('hasil cermin yang bergeser letak tetap dianggap sama', () {
      final moved = g(['....', '..##', '...#', '...#']);
      final answer = shape.mirrorLeftRight().canonical();
      expect(answer.filledCount, shape.filledCount);
      expect(
          _solver.validOptions(
              make(MirrorAxis.vertical, shape, [answer, shape, moved])),
          [0]);
    });

    test('teks soal tidak dikenal tidak punya opsi valid', () {
      final q = Question(
        type: QuestionType.figMir,
        seed: 1,
        difficulty: Difficulty.easy,
        stem: QuestionContent(text: 'Pilih.', figure: shape),
        options: [
          Option(id: 'A', content: QuestionContent(figure: shape)),
          Option(id: 'B', content: QuestionContent(figure: shape.rotate(1))),
        ],
        correctIndex: 0,
        explanation: 'x',
        estimatedSeconds: 10,
      );
      expect(_solver.validOptions(q), isEmpty);
    });
  });

  test('kedua sumbu muncul di semua kesulitan', () {
    for (final d in Difficulty.values) {
      final tags = {
        for (var s = 0; s < 200; s++) ..._generator.generate(s, d).tags,
      };
      expect(tags, {'rule:mirror-vertical', 'rule:mirror-horizontal'});
    }
  });

  test('pengecoh sel bergeser makin banyak pada kesulitan tinggi', () {
    int shifted(Difficulty d) {
      var n = 0;
      for (var s = 0; s < 300; s++) {
        final q = _generator.generate(s, d);
        final stem = q.stem.figure as GridFigure;
        final axis = MirrorAxis.fromStem(q.stem.text)!;
        final transforms = {
          for (final t in [
            stem,
            axis.apply(stem),
            axis.other.apply(stem),
            stem.rotate(1),
            stem.rotate(2),
            stem.rotate(3),
            axis.apply(stem.rotate(1)),
            axis.apply(stem.rotate(3)),
          ])
            gridKey(t),
        };
        n += q.options
            .where((o) => !transforms.contains(o.content.visualKey))
            .length;
      }
      return n;
    }

    // Minimum per soal: 0 (easy), 1 (medium), 2 (hard). Bentuk kecil yang
    // kurang simetri menambah pengecoh sel bergeser di semua kesulitan.
    expect(shifted(Difficulty.medium), greaterThanOrEqualTo(300));
    expect(shifted(Difficulty.hard), greaterThanOrEqualTo(600));
    expect(shifted(Difficulty.easy), lessThan(shifted(Difficulty.medium)));
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:mirror-vertical']);
      expect(q.correctIndex, 1);
      expect(q.explanation,
          'Bayangan cermin terhadap sumbu vertikal membalik kiri dan kanan: kolom k menjadi kolom 5 dikurangi k, sedangkan barisnya tetap. Dalam kisi 4x4 ("#" berisi, "." kosong): baris 1: .#.. menjadi ..#.; baris 2: #### menjadi ####; baris 3: #... menjadi ...#. Pilihan lain berupa bentuk asli, diputar, dicerminkan pada sumbu lain, dicerminkan lalu diputar, atau dengan satu sel yang bergeser.');
    });
  });
}
