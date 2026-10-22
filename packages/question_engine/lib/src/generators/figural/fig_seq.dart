/// Generator FIG-SEQ (deret gambar), docs/06-bank-konten.md, "Spesifikasi
/// ringkas tipe lain".
///
/// Deret 4 sampai 5 gambar; yang terakhir adalah jawaban. 1 sampai 3 ciri
/// berubah dengan aturan tetap (rotasi tiap langkah, jumlah naik atau turun,
/// isian, ukuran, atau bentuk berulang); ciri lain tetap. easy 1 ciri, medium
/// 2, hard 3.
///
/// Pengecoh: gambar jawaban dengan tepat satu ciri diganti nilai yang tidak
/// diramalkan solver, sehingga melanggar tepat satu aturan (aktif atau tetap).
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'fig_mtx_solver.dart';
import 'fig_seq_solver.dart';
import 'figure_text.dart';

/// Aturan satu ciri: nilai mentah di tiap langkah plus kalimat pembahasan.
final class _SeqRule {
  const _SeqRule(this.feature, this.values, this.sentence);

  final MtxFeature feature;
  final List<int> values;
  final String sentence;
}

class FigSeqGenerator extends RetryingGenerator {
  const FigSeqGenerator();

  /// Bentuk dengan empat rotasi tampak berbeda.
  static const List<Shape> rotatable = [Shape.triangle, Shape.pentagon];

  @override
  QuestionType get type => QuestionType.figSeq;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const FigSeqSolver();

  static int changingCount(Difficulty d) => switch (d) {
        Difficulty.easy => 1,
        Difficulty.medium => 2,
        Difficulty.hard => 3,
      };

  /// Jumlah pengecoh.
  static int distractorCount(Difficulty d) => switch (d) {
        Difficulty.easy => 3,
        Difficulty.medium => 4,
        Difficulty.hard => 5,
      };

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final changing =
        rng.shuffle(MtxFeature.values).take(changingCount(difficulty)).toSet();
    final rotates = changing.contains(MtxFeature.rotation);
    // Jumlah yang naik atau turun satu per langkah hanya muat di 4 gambar.
    final total =
        changing.contains(MtxFeature.count) ? 4 : (rng.nextBool() ? 4 : 5);

    final rules = <_SeqRule>[
      for (final f in MtxFeature.values)
        if (changing.contains(f)) _makeRule(rng, f, total, rotates),
    ];
    final fixed = <MtxFeature, int>{
      for (final f in MtxFeature.values)
        if (!changing.contains(f)) f: _fixedValue(rng, f, rotates),
    };
    final ruleValues = {for (final r in rules) r.feature: r.values};
    final steps = <List<int>>[
      for (var i = 0; i < total; i++)
        [
          for (final f in MtxFeature.values)
            ruleValues[f] != null ? ruleValues[f]![i] : fixed[f]!,
        ],
    ];

    final figures = [for (final s in steps) figureFromValues(s)];
    final answerValues = steps.last;
    final answer = figures.last;
    final stem = SequenceFigure([...figures.take(total - 1), null]);
    final prediction = SeqPrediction.of(stem);
    final answerCell = MtxCell.parse(answer);
    if (prediction == null ||
        answerCell == null ||
        !prediction.isExactly(answerCell)) {
      return null;
    }

    final distractors = _distractors(rng, answerValues, rules, fixed,
        prediction, distractorCount(difficulty));
    if (distractors == null) return null;

    final assembled = assembleOptions(
      rng,
      QuestionContent(figure: answer),
      [for (final d in distractors) QuestionContent(figure: d)],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(
          text: 'Pilih gambar yang melanjutkan deret.', figure: stem),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(rules, fixed, answerValues, total),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 30,
        Difficulty.medium => 40,
        Difficulty.hard => 50,
      },
      tags: [for (final r in rules) 'rule:seq-${r.feature.code}'],
    );
  }

  static int _fixedValue(Rng rng, MtxFeature f, bool rotates) => switch (f) {
        MtxFeature.shapes =>
          1 << (rotates ? rng.pick(rotatable) : rng.pick(Shape.values)).index,
        _ => rng.pick(featureDomain(f)),
      };

  static _SeqRule _makeRule(Rng rng, MtxFeature f, int total, bool rotates) {
    switch (f) {
      case MtxFeature.shapes:
        final pool = rotates ? rotatable : Shape.values;
        final period = (total == 5 && !rotates && rng.nextBool()) ? 3 : 2;
        final cycle = rng.shuffle(pool).take(period).toList();
        final names = [for (final s in cycle) shapeName(s)];
        return _SeqRule(
          f,
          [for (var i = 0; i < total; i++) 1 << cycle[i % period].index],
          period == 2
              ? 'Bentuk: bergantian ${names[0]} dan ${names[1]}.'
              : 'Bentuk: berulang ${names[0]}, ${names[1]}, lalu ${names[2]}.',
        );
      case MtxFeature.count:
        final up = rng.nextBool();
        return _SeqRule(
          f,
          [for (var i = 0; i < total; i++) up ? 1 + i : total - i],
          up
              ? 'Jumlah: bertambah 1 tiap langkah, dari 1 sampai $total.'
              : 'Jumlah: berkurang 1 tiap langkah, dari $total sampai 1.',
        );
      case MtxFeature.fill:
        final period = 2 + rng.nextInt(2);
        final cycle = rng.shuffle([0, 1, 2]).take(period).toList();
        final names = [
          for (final r in cycle) featureValueText(MtxFeature.fill, r),
        ];
        return _SeqRule(
          f,
          [for (var i = 0; i < total; i++) cycle[i % period]],
          period == 2
              ? 'Isian: bergantian ${names[0]} dan ${names[1]}.'
              : 'Isian: berulang ${names[0]}, ${names[1]}, lalu ${names[2]}.',
        );
      case MtxFeature.size:
        final mode = rng.nextInt(3);
        if (mode == 2) {
          final pair = rng.shuffle([0, 1, 2]).take(2).toList();
          final names = [
            for (final s in pair) featureValueText(MtxFeature.size, s),
          ];
          return _SeqRule(
            f,
            [for (var i = 0; i < total; i++) pair[i % 2]],
            'Ukuran: bergantian ${names[0]} dan ${names[1]}.',
          );
        }
        final step = mode == 0 ? 1 : 2;
        final start = rng.nextInt(3);
        return _SeqRule(
          f,
          [for (var i = 0; i < total; i++) (start + step * i) % 3],
          step == 1
              ? 'Ukuran: naik satu tingkat tiap langkah '
                  '(kecil, sedang, besar, lalu mengulang).'
              : 'Ukuran: turun satu tingkat tiap langkah '
                  '(besar, sedang, kecil, lalu mengulang).',
        );
      case MtxFeature.rotation:
        final step = 1 + rng.nextInt(3);
        final start = rng.nextInt(4);
        return _SeqRule(
          f,
          [for (var i = 0; i < total; i++) (start + step * i) % 4],
          switch (step) {
            1 => 'Rotasi: gambar berputar 90° searah jarum jam tiap langkah.',
            2 => 'Rotasi: gambar berputar 180° tiap langkah.',
            _ => 'Rotasi: gambar berputar 90° berlawanan arah jarum jam '
                'tiap langkah.',
          },
        );
    }
  }

  static List<SingleFigure>? _distractors(
    Rng rng,
    List<int> answer,
    List<_SeqRule> rules,
    Map<MtxFeature, int> fixed,
    SeqPrediction prediction,
    int count,
  ) {
    final used = {figureKey(figureFromValues(answer))};
    final order = [
      for (final r in rng.shuffle(rules)) r.feature,
      ...rng.shuffle(fixed.keys.toList()),
    ];
    final groups = <List<SingleFigure>>[];
    for (final f in order) {
      final group = <SingleFigure>[];
      for (final value in featureDomain(f)) {
        if (prediction[f].contains(value)) continue;
        final figure = figureFromValues(List.of(answer)..[f.index] = value);
        final cell = MtxCell.parse(figure);
        if (cell != null && prediction.violations(cell) == 1) group.add(figure);
      }
      groups.add(rng.shuffle(group));
    }

    // Bergiliran dari tiap kelompok agar pelanggaran tersebar.
    final picked = <SingleFigure>[];
    var progress = true;
    while (picked.length < count && progress) {
      progress = false;
      for (final group in groups) {
        if (picked.length == count) break;
        while (group.isNotEmpty) {
          final figure = group.removeLast();
          if (used.add(figureKey(figure))) {
            picked.add(figure);
            progress = true;
            break;
          }
        }
      }
    }
    return picked.length == count ? picked : null;
  }

  static String _explain(List<_SeqRule> rules, Map<MtxFeature, int> fixed,
      List<int> answer, int total) {
    final answerShape = Shape.values[bitIndex(answer[0])];
    final fixedText = [
      for (final e in fixed.entries)
        if (e.key != MtxFeature.rotation || answerShape.rotationPeriod > 1)
          '${featureName(e.key)} tetap ${featureValueText(e.key, e.key == MtxFeature.rotation ? e.value % answerShape.rotationPeriod : e.value)}',
    ];
    final parts = [
      for (final r in rules) r.sentence,
      if (fixedText.isNotEmpty) 'Di semua gambar, ${joinList(fixedText)}.',
      'Jadi gambar ke-$total: ${_describe(answer, answerShape)}.',
    ];
    return parts.join(' ');
  }

  static String _describe(List<int> v, Shape shape) => [
        '${v[MtxFeature.count.index]} ${shapeName(shape)}',
        'isian ${featureValueText(MtxFeature.fill, v[MtxFeature.fill.index])}',
        'ukuran ${featureValueText(MtxFeature.size, v[MtxFeature.size.index])}',
        if (shape.rotationPeriod > 1)
          'rotasi ${Rotation.values[v[MtxFeature.rotation.index] % shape.rotationPeriod].degrees}°',
      ].join(', ');
}
