/// Nama atribut gambar dalam bahasa Indonesia untuk pembahasan otomatis.
library;

import '../../figure_spec.dart';
import '../../models.dart';
import 'fig_mtx_solver.dart';

String featureName(MtxFeature f) => switch (f) {
      MtxFeature.shapes => 'bentuk',
      MtxFeature.count => 'jumlah',
      MtxFeature.fill => 'isian',
      MtxFeature.size => 'ukuran',
      MtxFeature.rotation => 'rotasi',
    };

String shapeName(Shape s) => switch (s) {
      Shape.circle => 'lingkaran',
      Shape.triangle => 'segitiga',
      Shape.square => 'persegi',
      Shape.diamond => 'belah ketupat',
      Shape.pentagon => 'segi lima',
      Shape.cross => 'palang',
    };

String fillName(Fill f) => switch (f) {
      Fill.empty => 'kosong',
      Fill.solid => 'penuh',
      Fill.hatch => 'arsir',
    };

String sizeName(FigureSize s) => switch (s) {
      FigureSize.small => 'kecil',
      FigureSize.medium => 'sedang',
      FigureSize.large => 'besar',
    };

String joinList(List<String> items) => switch (items.length) {
      0 => '',
      1 => items.single,
      2 => '${items[0]} dan ${items[1]}',
      _ => '${items.sublist(0, items.length - 1).join(', ')}, dan '
          '${items.last}',
    };

/// Nilai mentah [MtxCell] untuk ciri [f] sebagai teks.
/// Bentuk: bitmask indeks [Shape]; isian: 0 kosong, 1 arsir, 2 penuh.
String featureValueText(MtxFeature f, int value) => switch (f) {
      MtxFeature.shapes => joinList([
          for (final s in Shape.values)
            if (value & (1 << s.index) != 0) shapeName(s),
        ]),
      MtxFeature.count => '$value',
      MtxFeature.fill => switch (value) {
          0 => 'kosong',
          1 => 'arsir',
          _ => 'penuh',
        },
      MtxFeature.size => sizeName(FigureSize.values[value]),
      MtxFeature.rotation => '${Rotation.values[value].degrees}°',
    };

const List<Fill> _fillByRank = [Fill.empty, Fill.hatch, Fill.solid];

/// Indeks bit tertinggi dari bitmask bentuk (indeks [Shape]).
int bitIndex(int mask) {
  var i = 0;
  while (mask > 1) {
    mask >>= 1;
    i++;
  }
  return i;
}

/// Gambar satu objek dari nilai mentah (urutan [MtxFeature]): bitmask bentuk
/// satu bit, jumlah, peringkat isian (0 kosong, 1 arsir, 2 penuh), indeks
/// ukuran, indeks rotasi.
SingleFigure figureFromValues(List<int> v) => SingleFigure([
      FigureObject(
        shape: Shape.values[bitIndex(v[MtxFeature.shapes.index])],
        count: v[MtxFeature.count.index],
        fill: _fillByRank[v[MtxFeature.fill.index]],
        rotation: Rotation.values[v[MtxFeature.rotation.index]],
        size: FigureSize.values[v[MtxFeature.size.index]],
      ),
    ]);

/// Nilai sah tiap ciri untuk gambar satu objek.
List<int> featureDomain(MtxFeature f) => switch (f) {
      MtxFeature.shapes => [for (final s in Shape.values) 1 << s.index],
      MtxFeature.count => [
          for (var n = FigureObject.minCount; n <= FigureObject.maxCount; n++)
            n,
        ],
      MtxFeature.fill || MtxFeature.size => [0, 1, 2],
      MtxFeature.rotation => [0, 1, 2, 3],
    };

/// Kunci pembanding gambar yang tampak sama (simetri bentuk diperhitungkan).
String figureKey(FigureSpec f) => QuestionContent(figure: f).visualKey;
