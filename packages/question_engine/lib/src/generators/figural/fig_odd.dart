/// Generator FIG-ODD (odd one out), docs/06-bank-konten.md, "Spesifikasi
/// ringkas tipe lain".
///
/// Lima gambar. Empat berbagi nilai pada himpunan ciri R (easy 1 ciri, medium
/// 2, hard 3); satu pelanggar berbeda pada tepat satu ciri di R. Ciri di luar R
/// bebas bervariasi, tetapi dijaga agar tidak ada nilai yang dimiliki empat
/// gambar sekaligus, dan keempat gambar normal tidak kembar. Semua lima gambar sama pada suatu
/// ciri bebas (misalnya rotasi lingkaran yang tak terlihat) tidak masalah.
///
/// Solver: gambar ke-i valid bila keempat gambar lain sama persis pada suatu
/// ciri sedangkan gambar ke-i berbeda pada ciri itu.
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'fig_mtx_solver.dart';
import 'figure_text.dart';

final class FigOddSolver implements QuestionSolver {
  const FigOddSolver();

  @override
  List<int> validOptions(Question question) {
    final cells = <MtxCell>[];
    for (final o in question.options) {
      final cell = MtxCell.parse(o.content.figure);
      if (cell == null) return const [];
      cells.add(cell);
    }
    final valid = <int>[];
    for (var i = 0; i < cells.length; i++) {
      if (oddFeatures(cells, i).isNotEmpty) valid.add(i);
    }
    return valid;
  }

  /// Ciri tempat gambar ke-[i] berbeda dari empat lainnya yang sama persis.
  static List<MtxFeature> oddFeatures(List<MtxCell> cells, int i) {
    final others = [
      for (var j = 0; j < cells.length; j++)
        if (j != i) cells[j],
    ];
    if (others.length < 2) return const [];
    return [
      for (final f in MtxFeature.values)
        if (others.every((c) => c[f] == others.first[f]) &&
            cells[i][f] != others.first[f])
          f,
    ];
  }
}

class FigOddGenerator extends RetryingGenerator {
  const FigOddGenerator();

  static const int optionCount = 5;
  static const String stemText = 'Pilih gambar yang berbeda dari yang lain.';

  /// Bentuk dengan empat rotasi tampak berbeda.
  static const List<Shape> rotatable = [Shape.triangle, Shape.pentagon];

  /// Percobaan mengisi ciri bebas sebelum kandidat dilepas.
  static const int freeTries = 60;

  /// Pengambilan aturan bersama per percobaan.
  static const int ruleTries = 8;

  @override
  QuestionType get type => QuestionType.figOdd;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const FigOddSolver();

  static int sharedCount(Difficulty d) => switch (d) {
        Difficulty.easy => 1,
        Difficulty.medium => 2,
        Difficulty.hard => 3,
      };

  /// Ciri yang boleh menjadi aturan bersama.
  static List<MtxFeature> sharedPool(Difficulty d) => switch (d) {
        Difficulty.easy => const [
            MtxFeature.shapes,
            MtxFeature.fill,
            MtxFeature.count,
          ],
        Difficulty.medium => const [
            MtxFeature.shapes,
            MtxFeature.fill,
            MtxFeature.count,
            MtxFeature.size,
          ],
        Difficulty.hard => MtxFeature.values,
      };

  /// Ciri yang perbedaannya halus; pelanggar hard memilih dari sini.
  static const List<MtxFeature> subtle = [
    MtxFeature.size,
    MtxFeature.rotation,
    MtxFeature.count,
  ];

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    // Resampling di dalam satu percobaan: pilihan aturan bersama yang tidak
    // menyisakan cukup variasi untuk empat gambar normal yang berbeda dibuang.
    List<MtxFeature>? shared;
    MtxFeature? oddFeature;
    Map<MtxFeature, int>? sharedValue;
    int? oddValue;
    List<int> domain(MtxFeature f, bool rotates) =>
        f == MtxFeature.shapes && rotates
            ? [for (final s in rotatable) 1 << s.index]
            : featureDomain(f);
    for (var t = 0; t < ruleTries && shared == null; t++) {
      final picked = rng
          .shuffle(sharedPool(difficulty))
          .take(sharedCount(difficulty))
          .toList();
      final candidates = difficulty == Difficulty.hard
          ? picked.where(subtle.contains).toList()
          : picked;
      if (candidates.isEmpty) continue;
      final rotates = picked.contains(MtxFeature.rotation);
      final values = {
        for (final f in picked) f: rng.pick(domain(f, rotates)),
      };
      final odd = rng.pick(candidates);
      if (!_hasVariety(picked, values)) continue;
      shared = picked;
      oddFeature = odd;
      sharedValue = values;
      oddValue = rng.pick([
        for (final v in domain(odd, rotates))
          if (v != values[odd]) v,
      ]);
    }
    if (shared == null) return null;
    final rotates = shared.contains(MtxFeature.rotation);

    // Indeks 0..3 normal, 4 pelanggar.
    List<List<int>>? images;
    for (var t = 0; t < freeTries && images == null; t++) {
      final candidate = [
        for (var i = 0; i < optionCount; i++)
          [
            for (final f in MtxFeature.values)
              if (!shared.contains(f))
                rng.pick(domain(f, rotates))
              else if (i == optionCount - 1 && f == oddFeature)
                oddValue!
              else
                sharedValue![f]!,
          ],
      ];
      if (_acceptable(candidate, shared)) images = candidate;
    }
    if (images == null) return null;

    final figures = [for (final v in images) figureFromValues(v)];
    final assembled = assembleOptions(
      rng,
      QuestionContent(figure: figures.last),
      [
        for (final f in figures.take(optionCount - 1))
          QuestionContent(figure: f)
      ],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: const QuestionContent(text: stemText),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(shared, sharedValue!, oddFeature!, oddValue!,
          Option.idFor(assembled.correctIndex), images.last),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 30,
        Difficulty.medium => 40,
        Difficulty.hard => 50,
      },
      tags: [
        for (final f in shared) 'rule:odd-shared:${f.code}',
        'odd:${oddFeature.code}',
      ],
    );
  }

  /// Cukup banyak kombinasi ciri bebas untuk empat gambar normal yang berbeda.
  /// Rotasi tak terlihat bila bentuk bersama simetris penuh.
  static bool _hasVariety(
      List<MtxFeature> shared, Map<MtxFeature, int> values) {
    var combinations = 1;
    for (final f in MtxFeature.values) {
      if (shared.contains(f)) continue;
      final dead = f == MtxFeature.rotation &&
          values.containsKey(MtxFeature.shapes) &&
          Shape.values[bitIndex(values[MtxFeature.shapes]!)].rotationPeriod ==
              1;
      if (!dead) combinations *= featureDomain(f).length;
    }
    return combinations >= optionCount - 1;
  }

  /// Empat gambar normal tidak kembar, dan di luar ciri bersama tidak ada
  /// nilai yang dimiliki tepat empat gambar (satu gambar lain berbeda).
  static bool _acceptable(List<List<int>> images, List<MtxFeature> shared) {
    final cells = [
      for (final v in images) MtxCell.parse(figureFromValues(v)),
    ];
    if (cells.any((c) => c == null)) return false;
    final keys = {
      for (final v in images.take(optionCount - 1))
        figureKey(figureFromValues(v)),
    };
    if (keys.length != optionCount - 1) return false;
    for (final f in MtxFeature.values) {
      if (shared.contains(f)) continue;
      final counts = <int, int>{};
      for (final c in cells) {
        counts[c![f]] = (counts[c[f]] ?? 0) + 1;
      }
      if (counts.values.any((n) => n == optionCount - 1)) return false;
    }
    return true;
  }

  static String _valueText(MtxFeature f, int raw, Shape shape) =>
      featureValueText(
          f, f == MtxFeature.rotation ? raw % shape.rotationPeriod : raw);

  static String _explain(
    List<MtxFeature> shared,
    Map<MtxFeature, int> sharedValue,
    MtxFeature oddFeature,
    int oddValue,
    String letter,
    List<int> odd,
  ) {
    final normalShape = Shape.values[bitIndex(
        sharedValue[MtxFeature.shapes] ?? odd[MtxFeature.shapes.index])];
    final sharedText = joinList([
      for (final f in shared)
        '${featureName(f)} ${_valueText(f, sharedValue[f]!, normalShape)}',
    ]);
    final oddShape = Shape.values[bitIndex(odd[MtxFeature.shapes.index])];
    return 'Empat gambar punya $sharedText yang sama. '
        'Gambar $letter berbeda: ${featureName(oddFeature)} '
        '${_valueText(oddFeature, oddValue, oddShape)}, sedangkan yang lain '
        '${_valueText(oddFeature, sharedValue[oddFeature]!, normalShape)}. '
        'Ciri lain berbeda-beda antar gambar sehingga tidak menjadi aturan.';
  }
}
