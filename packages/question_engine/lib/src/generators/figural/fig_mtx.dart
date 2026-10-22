/// Generator FIG-MTX (matriks 3x3), docs/06-bank-konten.md bagian
/// "FIG-MTX (matriks 3x3), spesifikasi lengkap".
///
/// Satu percobaan:
///  1. pilih aturan sesuai kesulitan; dua aturan tidak boleh mengatur ciri yang
///     sama (lihat [MtxRule.collidesWith]);
///  2. ciri yang tidak diatur dibuat tetap di semua sel (aturan tersirat);
///  3. bangun 9 sel; sel kanan bawah adalah jawaban;
///  4. tolak bila [FigMtxSolver] tidak menyimpulkan tepat satu gambar untuk
///     sel kosong (ada tafsiran lain);
///  5. pengecoh: satu salinan sel lain di matriks, lalu 5 sampai 6 gambar yang
///     masing-masing berbeda dari jawaban pada tepat satu ciri, sehingga
///     melanggar tepat satu aturan (aktif atau tersirat).
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'fig_mtx_solver.dart';

enum MtxRuleKind {
  constantRow('constant-row', isRowRule: true),
  distributeRow('distribute-row', isRowRule: true),
  progressCol('progress-col'),
  rotateCol('rotate-col'),
  addCol('add-col'),
  subtractCol('subtract-col');

  const MtxRuleKind(this.code, {this.isRowRule = false});

  final String code;

  /// true untuk aturan yang dibaca per baris; selain itu dibaca per kolom.
  final bool isRowRule;
}

final class MtxRule {
  const MtxRule(this.kind, this.feature);

  final MtxRuleKind kind;

  /// Ciri utama yang diatur.
  final MtxFeature feature;

  /// Penjumlahan dan pengurangan bentuk juga mengatur jumlah: tiap bentuk
  /// muncul sekali.
  List<MtxFeature> get claims => switch (kind) {
        MtxRuleKind.addCol || MtxRuleKind.subtractCol => const [
            MtxFeature.shapes,
            MtxFeature.count
          ],
        _ => [feature],
      };

  String get tag => switch (kind) {
        MtxRuleKind.rotateCol ||
        MtxRuleKind.addCol ||
        MtxRuleKind.subtractCol =>
          'rule:${kind.code}',
        _ => 'rule:${kind.code}:${feature.code}',
      };

  /// Bertabrakan bila mengatur ciri yang sama, atau bila satu mengatur rotasi
  /// dan yang lain mengatur bentuk: rotasi hanya terlihat bila bentuknya tetap
  /// dan tidak simetris (segitiga atau segi lima).
  bool collidesWith(MtxRule other) {
    final a = claims;
    final b = other.claims;
    if (a.any(b.contains)) return true;
    bool rot(List<MtxFeature> c) => c.contains(MtxFeature.rotation);
    bool shp(List<MtxFeature> c) => c.contains(MtxFeature.shapes);
    return (rot(a) && shp(b)) || (shp(a) && rot(b));
  }
}

/// Nilai mentah sembilan sel: `this[ciri][baris][kolom]`. Bentuk disimpan
/// sebagai bitmask indeks [Shape]; isian, ukuran, dan rotasi sebagai indeks
/// enum mentah ([Fill.values], [FigureSize.values], [Rotation.values]).
final class _Grid {
  final List<List<List<int>>> _values = [
    for (final _ in MtxFeature.values)
      [for (var r = 0; r < 3; r++) List.filled(3, 0)],
  ];

  List<List<int>> operator [](MtxFeature f) => _values[f.index];

  List<int> at(int r, int c) => [for (final v in _values) v[r][c]];

  void fill(MtxFeature f, int Function(int r, int c) value) {
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        this[f][r][c] = value(r, c);
      }
    }
  }
}

SingleFigure _figure(List<int> v) => SingleFigure([
      for (final s in Shape.values)
        if (v[MtxFeature.shapes.index] & (1 << s.index) != 0)
          FigureObject(
            shape: s,
            count: v[MtxFeature.count.index],
            fill: Fill.values[v[MtxFeature.fill.index]],
            rotation: Rotation.values[v[MtxFeature.rotation.index]],
            size: FigureSize.values[v[MtxFeature.size.index]],
          ),
    ]);

String _key(SingleFigure f) => QuestionContent(figure: f).visualKey;

List<Shape> _shapesOf(int mask) => [
      for (final s in Shape.values)
        if (mask & (1 << s.index) != 0) s,
    ];

int _maskOf(Iterable<Shape> shapes) =>
    shapes.fold(0, (m, s) => m | (1 << s.index));

int _bitCount(int mask) => _shapesOf(mask).length;

class FigMtxGenerator extends RetryingGenerator {
  const FigMtxGenerator();

  static const String stemText = 'Pilih gambar yang melengkapi pola.';

  /// Pengecoh yang melanggar tepat satu aturan: target dan batas bawah.
  static const int maxSingleViolations = 6;
  static const int minSingleViolations = 5;

  /// Bentuk dengan empat rotasi tampak berbeda, untuk aturan rotasi.
  static const List<Shape> rotatingShapes = [Shape.triangle, Shape.pentagon];

  static const List<MtxRule> basePool = [
    MtxRule(MtxRuleKind.constantRow, MtxFeature.shapes),
    MtxRule(MtxRuleKind.constantRow, MtxFeature.count),
    MtxRule(MtxRuleKind.constantRow, MtxFeature.fill),
    MtxRule(MtxRuleKind.constantRow, MtxFeature.size),
    MtxRule(MtxRuleKind.constantRow, MtxFeature.rotation),
    MtxRule(MtxRuleKind.progressCol, MtxFeature.count),
    MtxRule(MtxRuleKind.progressCol, MtxFeature.size),
    MtxRule(MtxRuleKind.rotateCol, MtxFeature.rotation),
    MtxRule(MtxRuleKind.addCol, MtxFeature.shapes),
    MtxRule(MtxRuleKind.subtractCol, MtxFeature.shapes),
  ];

  /// Aturan distribusi hanya dipakai pada hard.
  static const List<MtxRule> distributionPool = [
    MtxRule(MtxRuleKind.distributeRow, MtxFeature.shapes),
    MtxRule(MtxRuleKind.distributeRow, MtxFeature.count),
    MtxRule(MtxRuleKind.distributeRow, MtxFeature.fill),
    MtxRule(MtxRuleKind.distributeRow, MtxFeature.size),
    MtxRule(MtxRuleKind.distributeRow, MtxFeature.rotation),
  ];

  @override
  QuestionType get type => QuestionType.figMtx;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const FigMtxSolver();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final rules = pickRules(rng, difficulty);
    if (rules == null) return null;
    final claimed = {for (final r in rules) ...r.claims};

    final grid = _Grid();
    for (final rule in rules) {
      _applyRule(rng, grid, rule);
    }
    _applyImplicit(rng, grid, claimed);

    final cells = [
      for (var r = 0; r < 3; r++)
        [for (var c = 0; c < 3; c++) _figure(grid.at(r, c))],
    ];
    final answer = cells[2][2];
    final matrix = MatrixFigure([
      for (var r = 0; r < 3; r++)
        [for (var c = 0; c < 3; c++) r == 2 && c == 2 ? null : cells[r][c]],
    ]);
    final prediction = MtxPrediction.of(matrix);
    final answerCell = MtxCell.parse(answer);
    if (prediction == null ||
        answerCell == null ||
        !prediction.isExactly(answerCell)) {
      return null;
    }

    final distractors =
        _distractors(rng, grid, cells, rules, claimed, prediction);
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
      stem: QuestionContent(text: stemText, figure: matrix),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(grid, rules, claimed),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 30,
        Difficulty.medium => 45,
        Difficulty.hard => 60,
      },
      tags: [for (final r in rules) r.tag],
    );
  }

  /// easy 1 aturan, medium 2 aturan, hard 3 aturan atau 2 aturan dengan
  /// sedikitnya satu distribusi. Distribusi hanya ada di hard.
  static List<MtxRule>? pickRules(Rng rng, Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return _pickFrom(rng, basePool, 1, const []);
      case Difficulty.medium:
        return _pickFrom(rng, basePool, 2, const []);
      case Difficulty.hard:
        const all = [...basePool, ...distributionPool];
        if (rng.nextBool()) return _pickFrom(rng, all, 3, const []);
        return _pickFrom(rng, all, 2, [rng.pick(distributionPool)]);
    }
  }

  static List<MtxRule>? _pickFrom(
      Rng rng, List<MtxRule> pool, int count, List<MtxRule> start) {
    final chosen = [...start];
    for (final rule in rng.shuffle(pool)) {
      if (chosen.length == count) break;
      if (chosen.every((c) => !c.collidesWith(rule))) chosen.add(rule);
    }
    return chosen.length == count ? chosen : null;
  }

  static List<int> _domain(MtxFeature f) => switch (f) {
        MtxFeature.shapes => [for (final s in Shape.values) 1 << s.index],
        MtxFeature.count => [
            for (var n = FigureObject.minCount; n <= FigureObject.maxCount; n++)
              n,
          ],
        MtxFeature.fill => [for (final v in Fill.values) v.index],
        MtxFeature.size => [for (final v in FigureSize.values) v.index],
        MtxFeature.rotation => [for (final v in Rotation.values) v.index],
      };

  static void _applyRule(Rng rng, _Grid g, MtxRule rule) {
    final f = rule.feature;
    switch (rule.kind) {
      case MtxRuleKind.constantRow:
        // Tiga nilai berbeda, satu per baris.
        final v = rng.shuffle(_domain(f)).take(3).toList();
        g.fill(f, (r, c) => v[r]);
      case MtxRuleKind.distributeRow:
        // Bujur sangkar Latin 3x3 dari tiga nilai berbeda (12 kemungkinan).
        final v = rng.shuffle(_domain(f)).take(3).toList();
        final shift = 1 + rng.nextInt(2);
        g.fill(f, (r, c) => v[(c + shift * r) % 3]);
      case MtxRuleKind.progressCol:
        if (f == MtxFeature.count) {
          final start = [for (var r = 0; r < 3; r++) 1 + rng.nextInt(2)];
          g.fill(f, (r, c) => start[r] + c);
        } else {
          g.fill(f, (r, c) => c);
        }
      case MtxRuleKind.rotateCol:
        // 90 derajat searah (1) atau berlawanan (3) jarum jam per kolom.
        final step = rng.nextBool() ? 1 : 3;
        final start = [for (var r = 0; r < 3; r++) rng.nextInt(4)];
        g.fill(f, (r, c) => (start[r] + step * c) % 4);
      case MtxRuleKind.addCol:
        for (var r = 0; r < 3; r++) {
          final order = rng.shuffle(Shape.values);
          final a = 1 + rng.nextInt(2);
          final b = 1 + rng.nextInt(2);
          final first = _maskOf(order.take(a));
          final second = _maskOf(order.skip(a).take(b));
          g[f][r]
            ..[0] = first
            ..[1] = second
            ..[2] = first | second;
        }
        g.fill(MtxFeature.count, (r, c) => 1);
      case MtxRuleKind.subtractCol:
        for (var r = 0; r < 3; r++) {
          final order = rng.shuffle(Shape.values);
          final n = 2 + rng.nextInt(2);
          final first = _maskOf(order.take(n));
          final second = _maskOf(order.take(1 + rng.nextInt(n - 1)));
          g[f][r]
            ..[0] = first
            ..[1] = second
            ..[2] = first & ~second;
        }
        g.fill(MtxFeature.count, (r, c) => 1);
    }
  }

  /// Ciri yang tidak diatur: satu nilai tetap di semua sel. Rotasi hanya
  /// diacak bila bentuknya tetap; bila bentuk berubah, rotasi 0.
  static void _applyImplicit(Rng rng, _Grid g, Set<MtxFeature> claimed) {
    for (final f in MtxFeature.values) {
      if (claimed.contains(f)) continue;
      final value = switch (f) {
        MtxFeature.shapes => claimed.contains(MtxFeature.rotation)
            ? 1 << rng.pick(rotatingShapes).index
            : rng.pick(_domain(f)),
        MtxFeature.rotation =>
          claimed.contains(MtxFeature.shapes) ? 0 : rng.nextInt(4),
        _ => rng.pick(_domain(f)),
      };
      g.fill(f, (r, c) => value);
    }
  }

  static List<SingleFigure>? _distractors(
    Rng rng,
    _Grid grid,
    List<List<SingleFigure>> cells,
    List<MtxRule> rules,
    Set<MtxFeature> claimed,
    MtxPrediction prediction,
  ) {
    final used = {_key(cells[2][2])};

    // Satu kandidat yang sama dengan sel lain di matriks.
    final copies = <SingleFigure>[];
    final copyKeys = <String>{...used};
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (r == 2 && c == 2) continue;
        if (copyKeys.add(_key(cells[r][c]))) copies.add(cells[r][c]);
      }
    }
    if (copies.isEmpty) return null;
    final copy = rng.pick(copies);
    used.add(_key(copy));

    // Kandidat yang berbeda dari jawaban pada tepat satu ciri, dikelompokkan
    // per aturan pemilik ciri itu: aturan aktif dulu, lalu aturan tersirat.
    final answer = grid.at(2, 2);
    final setRule = rules.any((r) =>
        r.kind == MtxRuleKind.addCol || r.kind == MtxRuleKind.subtractCol);
    final owners = <List<MtxFeature>>[
      for (final r in rng.shuffle(rules)) r.claims,
      for (final f in rng.shuffle(MtxFeature.values))
        if (!claimed.contains(f)) [f],
    ];
    final groups = <List<SingleFigure>>[];
    for (final features in owners) {
      final group = <SingleFigure>[];
      for (final f in features) {
        for (final value in _alternatives(grid, f, answer, setRule)) {
          final v = List.of(answer)..[f.index] = value;
          final figure = _figure(v);
          final cell = MtxCell.parse(figure);
          if (cell != null && prediction.violations(cell) == 1) {
            group.add(figure);
          }
        }
      }
      groups.add(rng.shuffle(group));
    }

    // Ambil bergiliran dari tiap kelompok agar pelanggaran tersebar.
    final picked = <SingleFigure>[];
    var progress = true;
    while (picked.length < maxSingleViolations && progress) {
      progress = false;
      for (final group in groups) {
        if (picked.length == maxSingleViolations) break;
        while (group.isNotEmpty) {
          final figure = group.removeLast();
          if (used.add(_key(figure))) {
            picked.add(figure);
            progress = true;
            break;
          }
        }
      }
    }
    if (picked.length < minSingleViolations) return null;
    return [copy, ...picked];
  }

  /// Nilai pengganti untuk ciri [f] dari jawaban [answer].
  static List<int> _alternatives(
      _Grid g, MtxFeature f, List<int> answer, bool setRule) {
    final current = answer[f.index];
    if (f == MtxFeature.count && setRule) return const [];
    if (f == MtxFeature.shapes && setRule) {
      // Salah operasi, bentuk kurang satu, atau bentuk lebih satu.
      final a = g[f][2][0];
      final b = g[f][2][1];
      return [
        for (final m in [
          a,
          b,
          a | b,
          a & b,
          a ^ b,
          a & ~b,
          b & ~a,
          for (final s in Shape.values) current ^ (1 << s.index),
        ])
          if (m != 0 && m != current && _bitCount(m) <= SingleFigure.maxObjects)
            m,
      ];
    }
    return [
      for (final v in _domain(f))
        if (v != current) v,
    ];
  }

  // Pembahasan.

  static String _explain(
      _Grid g, List<MtxRule> rules, Set<MtxFeature> claimed) {
    final ordered = [
      ...rules.where((r) => r.kind.isRowRule),
      ...rules.where((r) => !r.kind.isRowRule),
    ];
    final parts = [for (final r in ordered) _ruleSentence(g, r)];
    final shapeFixed = !claimed.contains(MtxFeature.shapes);
    final fixed = [
      for (final f in MtxFeature.values)
        if (!claimed.contains(f) &&
            (f != MtxFeature.rotation ||
                (shapeFixed &&
                    _shapesOf(g[MtxFeature.shapes][0][0])
                            .single
                            .rotationPeriod >
                        1)))
          '${_featureName(f)} tetap ${_label(f, g[f][0][0])}',
    ];
    if (fixed.isNotEmpty) parts.add('Di semua sel, ${_join(fixed)}.');
    parts.add('Jadi sel kosong berisi ${_describe(g.at(2, 2))}.');
    return parts.join(' ');
  }

  static String _ruleSentence(_Grid g, MtxRule rule) {
    final f = rule.feature;
    final v = g[f];
    String l(int r, int c) => _label(f, v[r][c]);
    final name = _featureName(f);
    switch (rule.kind) {
      case MtxRuleKind.constantRow:
        return 'Baris: $name sama dalam satu baris (baris 1 ${l(0, 0)}, '
            'baris 2 ${l(1, 0)}, baris 3 ${l(2, 0)}).';
      case MtxRuleKind.distributeRow:
        return 'Baris: tiap baris memuat $name ${l(0, 0)}, ${l(0, 1)}, dan '
            '${l(0, 2)} masing-masing sekali; baris 3 sudah punya ${l(2, 0)} '
            'dan ${l(2, 1)}, jadi sel kosong memakai ${l(2, 2)}.';
      case MtxRuleKind.progressCol:
        if (f == MtxFeature.count) {
          return 'Kolom: jumlah bertambah satu tiap kolom ke kanan (baris 3: '
              '${l(2, 0)}, ${l(2, 1)}, jadi ${l(2, 2)}).';
        }
        return 'Kolom: ukuran naik tiap kolom ke kanan, dari ${l(2, 0)}, '
            '${l(2, 1)}, ke ${l(2, 2)}.';
      case MtxRuleKind.rotateCol:
        final clockwise = (v[2][1] - v[2][0]) % 4 == 1;
        return 'Kolom: gambar berputar 90° '
            '${clockwise ? 'searah' : 'berlawanan arah'} jarum jam tiap kolom '
            'ke kanan (baris 3: ${l(2, 0)}, ${l(2, 1)}, jadi ${l(2, 2)}).';
      case MtxRuleKind.addCol:
        return 'Kolom: kolom 3 adalah gabungan bentuk kolom 1 dan kolom 2 '
            '(baris 3: ${l(2, 0)} ditambah ${l(2, 1)} menjadi ${l(2, 2)}).';
      case MtxRuleKind.subtractCol:
        return 'Kolom: kolom 3 adalah bentuk kolom 1 dikurangi bentuk kolom 2 '
            '(baris 3: ${l(2, 0)} dikurangi ${l(2, 1)} menyisakan '
            '${l(2, 2)}).';
    }
  }

  static String _describe(List<int> v) {
    final shapes = _shapesOf(v[MtxFeature.shapes.index]);
    final rotation = Rotation.values[v[MtxFeature.rotation.index]];
    return [
      if (shapes.length == 1)
        '${v[MtxFeature.count.index]} ${_shapeName(shapes.single)}'
      else
        _label(MtxFeature.shapes, v[MtxFeature.shapes.index]),
      'isian ${_label(MtxFeature.fill, v[MtxFeature.fill.index])}',
      'ukuran ${_label(MtxFeature.size, v[MtxFeature.size.index])}',
      if (shapes.length == 1 && shapes.single.rotationPeriod > 1)
        'rotasi ${rotation.degrees}°',
    ].join(', ');
  }

  static String _featureName(MtxFeature f) => switch (f) {
        MtxFeature.shapes => 'bentuk',
        MtxFeature.count => 'jumlah',
        MtxFeature.fill => 'isian',
        MtxFeature.size => 'ukuran',
        MtxFeature.rotation => 'rotasi',
      };

  /// Label nilai mentah ciri [f] untuk pembahasan.
  static String _label(MtxFeature f, int value) => switch (f) {
        MtxFeature.shapes =>
          _join([for (final s in _shapesOf(value)) _shapeName(s)]),
        MtxFeature.count => '$value',
        MtxFeature.fill => switch (Fill.values[value]) {
            Fill.empty => 'kosong',
            Fill.solid => 'penuh',
            Fill.hatch => 'arsir',
          },
        MtxFeature.size => switch (FigureSize.values[value]) {
            FigureSize.small => 'kecil',
            FigureSize.medium => 'sedang',
            FigureSize.large => 'besar',
          },
        MtxFeature.rotation => '${Rotation.values[value].degrees}°',
      };

  static String _shapeName(Shape s) => switch (s) {
        Shape.circle => 'lingkaran',
        Shape.triangle => 'segitiga',
        Shape.square => 'persegi',
        Shape.diamond => 'belah ketupat',
        Shape.pentagon => 'segi lima',
        Shape.cross => 'palang',
      };

  static String _join(List<String> items) => switch (items.length) {
        0 => '',
        1 => items.single,
        2 => '${items[0]} dan ${items[1]}',
        _ => '${items.sublist(0, items.length - 1).join(', ')}, dan '
            '${items.last}',
      };
}
