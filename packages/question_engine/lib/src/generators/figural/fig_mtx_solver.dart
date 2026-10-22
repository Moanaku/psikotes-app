/// Solver FIG-MTX: menyimpulkan aturan dari delapan sel yang terlihat.
///
/// Solver tidak membaca tag atau `correctIndex`. Untuk tiap ciri sel (bentuk,
/// jumlah, isian, ukuran, rotasi) solver mencoba semua hipotesis aturan yang
/// dikenal, per baris dan per kolom, lalu mengumpulkan nilai sel kosong yang
/// diramalkan setiap hipotesis yang cocok dengan sel terlihat. Opsi valid bila
/// setiap cirinya ada di ramalan.
///
/// Hipotesis sengaja lebih luas daripada aturan pembuatan di `fig_mtx.dart`
/// (dua arah, distribusi multiset, operasi himpunan dan hitung lain), supaya
/// tafsiran lain yang masuk akal ikut terhitung. Bila tafsiran itu meramalkan
/// gambar lain, lebih dari satu gambar menjadi valid dan generator menolak
/// matriksnya.
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';

/// Ciri sel yang dibandingkan solver. Semua dikodekan sebagai bilangan bulat.
enum MtxFeature {
  /// Bitmask indeks [Shape] dari bentuk yang ada di sel.
  shapes('shape'),

  /// Salinan tiap bentuk, 1 sampai 4.
  count('count'),

  /// Tingkat gelap isian: kosong 0, arsir 1, penuh 2.
  fill('fill'),

  /// Indeks [FigureSize]: kecil 0, sedang 1, besar 2.
  size('size'),

  /// Indeks rotasi kanonik (sesudah simetri bentuk), 0 sampai 3.
  rotation('rotation');

  const MtxFeature(this.code);

  final String code;
}

/// Ciri satu sel atau opsi setelah dikanonikkan.
final class MtxCell {
  MtxCell._(this.values, this.rotationPeriod);

  final List<int> values;

  /// Periode rotasi bentuk bila sel berisi satu bentuk; 0 bila lebih.
  final int rotationPeriod;

  int operator [](MtxFeature f) => values[f.index];

  /// Null bila gambar tidak bisa dibaca sebagai sel matriks: bukan `single`,
  /// kosong, ada bentuk ganda, atau objeknya tidak seragam pada jumlah,
  /// isian, ukuran, atau rotasi tampak.
  static MtxCell? parse(FigureSpec? figure) {
    if (figure is! SingleFigure || figure.objects.isEmpty) return null;
    final objects = figure.canonical().objects;
    final first = objects.first;
    var mask = 0;
    for (final o in objects) {
      final bit = 1 << o.shape.index;
      if (mask & bit != 0) return null;
      mask |= bit;
      if (o.count != first.count ||
          o.fill != first.fill ||
          o.size != first.size ||
          o.rotation != first.rotation) {
        return null;
      }
    }
    return MtxCell._(
      [
        mask,
        first.count,
        fillRank(first.fill),
        first.size.index,
        first.rotation.index,
      ],
      objects.length == 1 ? first.shape.rotationPeriod : 0,
    );
  }

  static int fillRank(Fill fill) => switch (fill) {
        Fill.empty => 0,
        Fill.hatch => 1,
        Fill.solid => 2,
      };
}

typedef _Op = int Function(int a, int b);

/// Operasi himpunan bentuk antar sel: sel ketiga = op(sel pertama, kedua).
final List<_Op> _setOps = [
  (a, b) => a | b,
  (a, b) => a & b,
  (a, b) => a ^ b,
  (a, b) => a & ~b,
  (a, b) => b & ~a,
];

/// Operasi hitung jumlah antar sel.
final List<_Op> _countOps = [
  (a, b) => a + b,
  (a, b) => a - b,
  (a, b) => b - a,
];

/// Ramalan solver untuk sel kanan bawah: himpunan nilai per ciri.
final class MtxPrediction {
  MtxPrediction._(this.values);

  final List<Set<int>> values;

  Set<int> operator [](MtxFeature f) => values[f.index];

  /// Null bila [figure] bukan matriks 3x3 dengan tepat sel kanan bawah kosong
  /// dan delapan sel lain terbaca.
  static MtxPrediction? of(FigureSpec? figure) {
    if (figure is! MatrixFigure) return null;
    final cells = figure.cells;
    if (cells.length != 3 || cells.any((r) => r.length != 3)) return null;
    final grid = [
      for (var r = 0; r < 3; r++) List<MtxCell?>.filled(3, null),
    ];
    final periods = <int>{};
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (r == 2 && c == 2) {
          if (cells[r][c] != null) return null;
          continue;
        }
        final cell = MtxCell.parse(cells[r][c]);
        if (cell == null) return null;
        grid[r][c] = cell;
        periods.add(cell.rotationPeriod);
      }
    }
    final period = periods.length == 1 ? periods.single : 0;
    return MtxPrediction._([
      for (final f in MtxFeature.values) _predict(grid, f, period),
    ]);
  }

  /// Banyak ciri [cell] yang tidak ada di ramalan.
  int violations(MtxCell cell) =>
      MtxFeature.values.where((f) => !this[f].contains(cell[f])).length;

  bool accepts(MtxCell cell) => violations(cell) == 0;

  /// true bila setiap ciri punya tepat satu ramalan dan semuanya sama dengan
  /// [cell]: tidak ada tafsiran lain untuk sel kosong.
  bool isExactly(MtxCell cell) => MtxFeature.values
      .every((f) => this[f].length == 1 && this[f].contains(cell[f]));

  /// [period]: periode rotasi bersama semua sel terlihat, 0 bila berbeda.
  static Set<int> _predict(List<List<MtxCell?>> g, MtxFeature f, int period) {
    final out = <int>{};
    for (final byRow in const [true, false]) {
      // Garis 0 dan 1 lengkap; garis 2 berakhir di sel kosong.
      int at(int line, int pos) => (byRow ? g[line][pos] : g[pos][line])![f];
      final full = [
        for (var l = 0; l < 2; l++) [for (var p = 0; p < 3; p++) at(l, p)],
      ];
      final x = at(2, 0);
      final y = at(2, 1);

      // Konstan dalam garis.
      if (full.every((l) => l[0] == l[1] && l[1] == l[2]) && x == y) {
        out.add(x);
      }

      // Distribusi: tiap garis memuat multiset nilai yang sama.
      final m0 = List.of(full[0])..sort();
      final m1 = List.of(full[1])..sort();
      if (m0[0] == m1[0] && m0[1] == m1[1] && m0[2] == m1[2]) {
        final rest = List.of(m0);
        if (rest.remove(x) && rest.remove(y)) out.add(rest.single);
      }

      // Deret aritmetika dalam garis (ciri bertingkat).
      if (f == MtxFeature.count ||
          f == MtxFeature.fill ||
          f == MtxFeature.size) {
        if (full.every((l) => l[1] - l[0] == l[2] - l[1])) out.add(2 * y - x);
      }

      // Rotasi bertahap: deret siklik modulo periode bentuk.
      if (f == MtxFeature.rotation && period > 1) {
        if (full
            .every((l) => (l[1] - l[0]) % period == (l[2] - l[1]) % period)) {
          out.add((2 * y - x) % period);
        }
      }

      // Sel ketiga hasil operasi dua sel pertama.
      final ops = switch (f) {
        MtxFeature.shapes => _setOps,
        MtxFeature.count => _countOps,
        _ => const <_Op>[],
      };
      for (final op in ops) {
        if (full.every((l) => op(l[0], l[1]) == l[2])) out.add(op(x, y));
      }
    }
    return out;
  }
}

final class FigMtxSolver implements QuestionSolver {
  const FigMtxSolver();

  @override
  List<int> validOptions(Question question) {
    final prediction = MtxPrediction.of(question.stem.figure);
    if (prediction == null) return const [];
    return [
      for (var i = 0; i < question.options.length; i++)
        if (MtxCell.parse(question.options[i].content.figure) case final cell?
            when prediction.accepts(cell))
          i,
    ];
  }

  /// Banyak ciri opsi ke-[index] yang melanggar ramalan. Null bila matriks
  /// atau opsinya tidak terbaca.
  int? violations(Question question, int index) {
    final prediction = MtxPrediction.of(question.stem.figure);
    final cell = MtxCell.parse(question.options[index].content.figure);
    if (prediction == null || cell == null) return null;
    return prediction.violations(cell);
  }
}
