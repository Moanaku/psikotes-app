/// Generator FIG-MIR (mirror dan water image), docs/06-bank-konten.md,
/// "Spesifikasi ringkas tipe lain".
///
/// Bentuk tersusun dari 4 sampai 9 sel berisi pada kisi 4x4 ([GridFigure]),
/// tidak simetris terhadap sumbu yang ditanyakan. Soal meminta bayangan cermin
/// (sumbu vertikal, kiri-kanan terbalik) atau water image (sumbu horizontal,
/// atas-bawah terbalik).
///
/// Pengecoh: tujuh simetri persegi lain dari bentuk asli (asli, cermin sumbu
/// lain, putaran, cermin lalu putar) dan bentuk jawaban dengan satu sel
/// bergeser. Dua kisi dianggap sama
/// bila bentuknya sama setelah digeser ke pojok kiri atas.
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';

enum MirrorAxis {
  /// Bayangan cermin: sumbu vertikal, kiri dan kanan tertukar.
  vertical(
      'vertical',
      'Pilih bayangan cermin gambar ini terhadap sumbu '
          'vertikal (cermin di sisi kanan).'),

  /// Water image: sumbu horizontal, atas dan bawah tertukar.
  horizontal(
      'horizontal',
      'Pilih water image gambar ini terhadap sumbu '
          'horizontal (cermin di sisi bawah).');

  const MirrorAxis(this.code, this.stemText);

  final String code;
  final String stemText;

  /// Sumbu yang dikenali dari teks soal; null bila teks tidak dikenal.
  static MirrorAxis? fromStem(String? text) {
    for (final a in values) {
      if (text == a.stemText) return a;
    }
    return null;
  }

  GridFigure apply(GridFigure g) =>
      this == vertical ? g.mirrorLeftRight() : g.mirrorTopBottom();

  MirrorAxis get other => this == vertical ? horizontal : vertical;
}

String gridKey(GridFigure g) => QuestionContent(figure: g).visualKey;

final class FigMirSolver implements QuestionSolver {
  const FigMirSolver();

  @override
  List<int> validOptions(Question question) {
    final axis = MirrorAxis.fromStem(question.stem.text);
    final stem = question.stem.figure;
    if (axis == null || stem is! GridFigure || stem.filledCount == 0) {
      return const [];
    }
    final expected = gridKey(axis.apply(stem));
    return [
      for (var i = 0; i < question.options.length; i++)
        if (question.options[i].content.figure case final GridFigure g
            when gridKey(g) == expected)
          i,
    ];
  }
}

class FigMirGenerator extends RetryingGenerator {
  const FigMirGenerator();

  /// Jumlah opsi: kunci dan empat pengecoh.
  static const int optionCount = 5;

  /// Pengambilan bentuk acak per percobaan sampai ketemu yang asimetris.
  static const int shapeTries = 10;

  @override
  QuestionType get type => QuestionType.figMir;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const FigMirSolver();

  /// Banyak sel berisi menurut kesulitan: easy 4-5, medium 6-7, hard 8-9.
  static (int, int) cellRange(Difficulty d) => switch (d) {
        Difficulty.easy => (4, 5),
        Difficulty.medium => (6, 7),
        Difficulty.hard => (8, 9),
      };

  /// Banyak pengecoh berupa satu sel bergeser (minimum): makin sulit makin
  /// banyak. Kekurangan pengecoh simetri diisi pengecoh ini juga.
  static int shiftedCount(Difficulty d) => switch (d) {
        Difficulty.easy => 0,
        Difficulty.medium => 1,
        Difficulty.hard => 2,
      };

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final axis = rng.nextBool() ? MirrorAxis.vertical : MirrorAxis.horizontal;
    final (lo, hi) = cellRange(difficulty);
    // Resampling di dalam satu percobaan: bentuk kecil sering simetris pada
    // sumbu yang ditanyakan, dan itu bukan soal yang sah.
    GridFigure? shape;
    for (var i = 0; i < shapeTries && shape == null; i++) {
      final candidate = _randomShape(rng, lo + rng.nextInt(hi - lo + 1));
      if (gridKey(axis.apply(candidate)) != gridKey(candidate)) {
        shape = candidate;
      }
    }
    if (shape == null) return null;
    final answer = axis.apply(shape);

    final used = {gridKey(answer)};
    // Tujuh unsur lain dari delapan simetri persegi (putar dan cermin).
    final transforms = <GridFigure>[
      shape,
      axis.other.apply(shape),
      shape.rotate(1),
      shape.rotate(2),
      shape.rotate(3),
      axis.apply(shape.rotate(1)),
      axis.apply(shape.rotate(3)),
    ];
    final fromTransforms = <GridFigure>[];
    for (final g in rng.shuffle(transforms)) {
      if (!used.contains(gridKey(g))) {
        used.add(gridKey(g));
        fromTransforms.add(g);
      }
    }

    // Bentuk kecil punya sedikit simetri yang berbeda; kekurangannya diisi
    // pengecoh sel bergeser.
    final needed = optionCount - 1;
    final wantShifted =
        shiftedCount(difficulty) > needed - fromTransforms.length
            ? shiftedCount(difficulty)
            : needed - fromTransforms.length;
    final shifted = <GridFigure>[];
    for (final g in rng.shuffle(_shiftedVariants(answer))) {
      if (shifted.length == wantShifted) break;
      if (used.add(gridKey(g))) shifted.add(g);
    }
    if (shifted.length < wantShifted) return null;

    final distractors = [
      ...shifted,
      ...fromTransforms.take(needed - shifted.length),
    ];
    if (distractors.length != needed) return null;

    final assembled = assembleOptions(
      rng,
      QuestionContent(figure: answer),
      [for (final d in distractors) QuestionContent(figure: d)],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(text: axis.stemText, figure: shape),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(shape, answer, axis),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 30,
        Difficulty.medium => 40,
        Difficulty.hard => 50,
      },
      tags: ['rule:mirror-${axis.code}'],
    );
  }

  /// Bentuk terhubung (sisi bertemu sisi) dengan [count] sel di kisi 4x4,
  /// tumbuh dari satu sel acak.
  static GridFigure _randomShape(Rng rng, int count) {
    const n = GridFigure.size;
    final cells = <(int, int)>[(rng.nextInt(n), rng.nextInt(n))];
    while (cells.length < count) {
      final (r, c) = rng.pick(cells);
      final (dr, dc) = rng.pick(const [(-1, 0), (1, 0), (0, -1), (0, 1)]);
      final next = (r + dr, c + dc);
      if (next.$1 < 0 || next.$1 >= n || next.$2 < 0 || next.$2 >= n) continue;
      if (!cells.contains(next)) cells.add(next);
    }
    return GridFigure.fromPoints(cells);
  }

  /// Satu sel berisi pindah ke sel kosong di sebelahnya (sisi ke sisi).
  static List<GridFigure> _shiftedVariants(GridFigure g) {
    const n = GridFigure.size;
    final pts = g.points;
    final out = <GridFigure>[];
    for (final p in pts) {
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final q = (p.$1 + dr, p.$2 + dc);
        if (q.$1 < 0 || q.$1 >= n || q.$2 < 0 || q.$2 >= n) continue;
        if (pts.contains(q)) continue;
        out.add(GridFigure.fromPoints([
          for (final x in pts)
            if (x != p) x,
          q,
        ]));
      }
    }
    return out;
  }

  static String _explain(GridFigure shape, GridFigure answer, MirrorAxis axis) {
    final rows = [
      for (var r = 0; r < GridFigure.size; r++)
        if (shape.rowText(r) != '.' * GridFigure.size ||
            answer.rowText(r) != '.' * GridFigure.size)
          r,
    ];
    final lines = axis == MirrorAxis.vertical
        ? [
            for (final r in rows)
              'baris ${r + 1}: ${shape.rowText(r)} menjadi ${answer.rowText(r)}',
          ]
        : [
            for (final r in rows)
              'baris ${r + 1} asli (${shape.rowText(r)}) pindah ke baris '
                  '${GridFigure.size - r}',
          ];
    final rule = axis == MirrorAxis.vertical
        ? 'Bayangan cermin terhadap sumbu vertikal membalik kiri dan kanan: '
            'kolom k menjadi kolom ${GridFigure.size + 1} dikurangi k, '
            'sedangkan barisnya tetap.'
        : 'Water image terhadap sumbu horizontal membalik atas dan bawah: '
            'baris k menjadi baris ${GridFigure.size + 1} dikurangi k, '
            'sedangkan kolomnya tetap.';
    return '$rule Dalam kisi ${GridFigure.size}x${GridFigure.size} '
        '("#" berisi, "." kosong): ${lines.join('; ')}. '
        'Pilihan lain berupa bentuk asli, diputar, dicerminkan pada sumbu '
        'lain, dicerminkan lalu diputar, atau dengan satu sel yang bergeser.';
  }
}
