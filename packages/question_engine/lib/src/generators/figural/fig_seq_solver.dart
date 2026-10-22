/// Solver FIG-SEQ: menyimpulkan aturan tiap ciri dari gambar yang terlihat dan
/// meramalkan gambar berikutnya.
///
/// Solver tidak membaca tag atau `correctIndex`. Untuk tiap ciri (bentuk,
/// jumlah, isian, ukuran, rotasi) solver mencoba hipotesis: tetap, selisih
/// tetap (juga melingkar untuk isian, ukuran, rotasi), dan berulang tiap 2 atau
/// 3 langkah. Opsi valid bila setiap cirinya ada di ramalan.
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import 'fig_mtx_solver.dart';

final class SeqPrediction {
  SeqPrediction._(this.values);

  final List<Set<int>> values;

  Set<int> operator [](MtxFeature f) => values[f.index];

  /// Null bila [figure] bukan deret dengan 3 sampai 4 gambar terlihat lalu
  /// satu sel kosong, atau ada gambar terlihat yang tidak terbaca sebagai sel.
  static SeqPrediction? of(FigureSpec? figure) {
    if (figure is! SequenceFigure || figure.items.length < 4) return null;
    final shown = figure.items.sublist(0, figure.items.length - 1);
    if (figure.items.last != null) return null;
    final cells = <MtxCell>[];
    for (final item in shown) {
      final cell = MtxCell.parse(item);
      if (cell == null) return null;
      cells.add(cell);
    }
    return SeqPrediction._([
      for (final f in MtxFeature.values)
        _predict(f, [for (final c in cells) c[f]]),
    ]);
  }

  /// Domain nilai sah tiap ciri; ramalan di luar domain dibuang.
  static bool inDomain(MtxFeature f, int v) => switch (f) {
        MtxFeature.shapes => v > 0 && v & (v - 1) == 0,
        MtxFeature.count =>
          v >= FigureObject.minCount && v <= FigureObject.maxCount,
        MtxFeature.fill || MtxFeature.size => v >= 0 && v <= 2,
        MtxFeature.rotation => v >= 0 && v <= 3,
      };

  /// Modulus untuk ciri yang berulang melingkar; 0 bila tidak melingkar.
  static int modulus(MtxFeature f) => switch (f) {
        MtxFeature.fill || MtxFeature.size => 3,
        MtxFeature.rotation => 4,
        _ => 0,
      };

  static Set<int> _predict(MtxFeature f, List<int> v) {
    final n = v.length;
    final out = <int>{};
    void add(int x) {
      if (inDomain(f, x)) out.add(x);
    }

    if (v.every((x) => x == v[0])) add(v[0]);

    final diffs = [for (var i = 1; i < n; i++) v[i] - v[i - 1]];
    if (f != MtxFeature.shapes && diffs.every((d) => d == diffs[0])) {
      add(v[n - 1] + diffs[0]);
    }
    final m = modulus(f);
    if (m > 0) {
      final md = [for (final d in diffs) d % m];
      if (md.every((d) => d == md[0])) add((v[n - 1] + md[0]) % m);
    }

    for (final p in const [2, 3]) {
      if (n < p + 1) continue;
      var periodic = true;
      for (var i = p; i < n; i++) {
        if (v[i] != v[i - p]) periodic = false;
      }
      if (periodic) add(v[n - p]);
    }
    return out;
  }

  int violations(MtxCell cell) =>
      MtxFeature.values.where((f) => !this[f].contains(cell[f])).length;

  bool accepts(MtxCell cell) => violations(cell) == 0;

  /// Tepat satu ramalan per ciri dan semuanya sama dengan [cell].
  bool isExactly(MtxCell cell) => MtxFeature.values
      .every((f) => this[f].length == 1 && this[f].contains(cell[f]));
}

final class FigSeqSolver implements QuestionSolver {
  const FigSeqSolver();

  @override
  List<int> validOptions(Question question) {
    final prediction = SeqPrediction.of(question.stem.figure);
    if (prediction == null) return const [];
    return [
      for (var i = 0; i < question.options.length; i++)
        if (MtxCell.parse(question.options[i].content.figure) case final cell?
            when prediction.accepts(cell))
          i,
    ];
  }

  /// Banyak ciri opsi ke-[index] yang melanggar ramalan; null bila tidak
  /// terbaca.
  int? violations(Question question, int index) {
    final prediction = SeqPrediction.of(question.stem.figure);
    final cell = MtxCell.parse(question.options[index].content.figure);
    if (prediction == null || cell == null) return null;
    return prediction.violations(cell);
  }
}
