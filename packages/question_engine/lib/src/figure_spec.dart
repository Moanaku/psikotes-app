/// Spesifikasi gambar soal figural (docs/06-bank-konten.md, "FigureSpec").
///
/// Gambar hanya data; renderer (`CustomPainter`, T08) menggambarnya. Kelas di
/// sini tidak menimpa `==` atau `hashCode` (engine dilarang memakai `hashCode`).
/// Kesamaan dibandingkan lewat JSON kanonik, lihat [FigureSpec.canonical].
library;

import 'json_utils.dart';

enum Shape {
  circle('circle', 1),
  triangle('triangle', 4),
  square('square', 1),
  diamond('diamond', 2),
  pentagon('pentagon', 4),
  cross('cross', 1);

  const Shape(this.code, this.rotationPeriod);

  final String code;

  /// Banyak langkah 90 derajat sampai bentuk tampak sama lagi.
  ///
  /// 1: tampak sama di semua rotasi (lingkaran, persegi, palang simetris).
  /// 2: tampak sama setelah 180 derajat (belah ketupat yang lebih tinggi
  /// daripada lebarnya). 4: keempat rotasi tampak berbeda. Renderer wajib
  /// menggambar bentuk sesuai simetri ini.
  final int rotationPeriod;

  static Shape fromCode(String code) => enumByCode(values, code, (v) => v.code);
}

/// Isian dibedakan lewat pola, bukan warna. Arsiran digambar dengan sudut tetap
/// di layar (tidak ikut berputar), sehingga tidak mengubah simetri bentuk.
enum Fill {
  empty('empty'),
  solid('solid'),
  hatch('hatch');

  const Fill(this.code);

  final String code;

  static Fill fromCode(String code) => enumByCode(values, code, (v) => v.code);
}

enum Rotation {
  r0(0),
  r90(90),
  r180(180),
  r270(270);

  const Rotation(this.degrees);

  final int degrees;

  /// Rotasi searah jarum jam sebanyak [steps] kali 90 derajat (boleh negatif).
  Rotation turn(int steps) => values[(index + steps) % values.length];

  static Rotation fromDegrees(int degrees) {
    for (final r in values) {
      if (r.degrees == degrees) return r;
    }
    throw FormatException('rotation tidak dikenal: $degrees');
  }
}

enum FigureSize {
  small('s'),
  medium('m'),
  large('l');

  const FigureSize(this.code);

  final String code;

  static FigureSize fromCode(String code) =>
      enumByCode(values, code, (v) => v.code);
}

/// Satu objek: `{shape, count, fill, rotation, size}`.
final class FigureObject {
  static const int minCount = 1;
  static const int maxCount = 4;

  const FigureObject({
    required this.shape,
    this.count = 1,
    this.fill = Fill.empty,
    this.rotation = Rotation.r0,
    this.size = FigureSize.medium,
  });

  final Shape shape;

  /// 1 sampai 4 salinan bentuk yang sama di dalam satu sel.
  final int count;
  final Fill fill;
  final Rotation rotation;
  final FigureSize size;

  /// Bentuk yang tampak sama di layar: rotasi diturunkan sesuai simetri bentuk.
  FigureObject canonical() => copyWith(
        rotation: Rotation.values[rotation.index % shape.rotationPeriod],
      );

  FigureObject copyWith({
    Shape? shape,
    int? count,
    Fill? fill,
    Rotation? rotation,
    FigureSize? size,
  }) =>
      FigureObject(
        shape: shape ?? this.shape,
        count: count ?? this.count,
        fill: fill ?? this.fill,
        rotation: rotation ?? this.rotation,
        size: size ?? this.size,
      );

  List<String> validate(String path) => [
        if (count < minCount || count > maxCount)
          '$path.count di luar $minCount..$maxCount: $count',
      ];

  Map<String, Object?> toJson() => {
        'shape': shape.code,
        'count': count,
        'fill': fill.code,
        'rotation': rotation.degrees,
        'size': size.code,
      };

  factory FigureObject.fromJson(Object? json) {
    final m = asJsonMap(json, 'objek gambar');
    return FigureObject(
      shape: Shape.fromCode(readString(m, 'shape')),
      count: readInt(m, 'count'),
      fill: Fill.fromCode(readString(m, 'fill')),
      rotation: Rotation.fromDegrees(readInt(m, 'rotation')),
      size: FigureSize.fromCode(readString(m, 'size')),
    );
  }
}

/// Akar semua gambar. `kind` di JSON menentukan subkelas.
///
/// `single` dan `matrix3x3` dari dokumen; `sequence` (FIG-SEQ) dan `grid`
/// (FIG-MIR) ditambahkan oleh T05.
sealed class FigureSpec {
  const FigureSpec();

  String get kind;

  /// Salinan yang tampak sama di layar dengan bentuk data tunggal.
  FigureSpec canonical();

  List<String> validate(String path);

  Map<String, Object?> toJson();

  factory FigureSpec.fromJson(Object? json) {
    final m = asJsonMap(json, 'gambar');
    final kind = readString(m, 'kind');
    return switch (kind) {
      SingleFigure.kindCode => SingleFigure._fromMap(m),
      MatrixFigure.kindCode => MatrixFigure._fromMap(m),
      SequenceFigure.kindCode => SequenceFigure._fromMap(m),
      GridFigure.kindCode => GridFigure._fromMap(m),
      _ => throw FormatException('kind gambar tidak dikenal: $kind'),
    };
  }
}

/// Satu sel atau satu opsi: daftar objek, digambar berurutan oleh renderer.
///
/// Boleh kosong (sel hasil pengurangan bentuk). Urutan objek bermakna karena
/// menentukan tata letak.
final class SingleFigure extends FigureSpec {
  static const String kindCode = 'single';
  static const int maxObjects = 4;

  SingleFigure(Iterable<FigureObject> objects)
      : objects = List.unmodifiable(objects);

  final List<FigureObject> objects;

  @override
  String get kind => kindCode;

  @override
  SingleFigure canonical() => SingleFigure([
        for (final o in objects) o.canonical(),
      ]);

  @override
  List<String> validate(String path) => [
        if (objects.length > maxObjects)
          '$path.objects lebih dari $maxObjects: ${objects.length}',
        for (var i = 0; i < objects.length; i++)
          ...objects[i].validate('$path.objects[$i]'),
      ];

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'objects': [for (final o in objects) o.toJson()],
      };

  factory SingleFigure.fromJson(Object? json) {
    final figure = FigureSpec.fromJson(json);
    if (figure is! SingleFigure) {
      throw FormatException('diharapkan gambar single, didapat ${figure.kind}');
    }
    return figure;
  }

  static SingleFigure _fromMap(Map<String, Object?> m) => SingleFigure(
        readList(m, 'objects').map(FigureObject.fromJson),
      );
}

/// Matriks 3x3. Tepat satu sel bernilai null: sel yang harus dijawab.
final class MatrixFigure extends FigureSpec {
  static const String kindCode = 'matrix3x3';
  static const int size = 3;

  MatrixFigure(Iterable<Iterable<SingleFigure?>> cells)
      : cells = List.unmodifiable([
          for (final row in cells) List<SingleFigure?>.unmodifiable(row),
        ]);

  /// `cells[baris][kolom]`.
  final List<List<SingleFigure?>> cells;

  @override
  String get kind => kindCode;

  @override
  MatrixFigure canonical() => MatrixFigure([
        for (final row in cells) [for (final c in row) c?.canonical()],
      ]);

  @override
  List<String> validate(String path) {
    final issues = <String>[];
    if (cells.length != size || cells.any((r) => r.length != size)) {
      issues.add('$path.cells bukan ${size}x$size');
    }
    final missing = cells.expand((r) => r).where((c) => c == null).length;
    if (missing != 1) {
      issues.add('$path.cells harus punya tepat satu sel kosong, ada $missing');
    }
    for (var r = 0; r < cells.length; r++) {
      for (var c = 0; c < cells[r].length; c++) {
        issues.addAll(cells[r][c]?.validate('$path.cells[$r][$c]') ?? const []);
      }
    }
    return issues;
  }

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'cells': [
          for (final row in cells) [for (final c in row) c?.toJson()],
        ],
      };

  static MatrixFigure _fromMap(Map<String, Object?> m) => MatrixFigure([
        for (final row in readList(m, 'cells'))
          [
            for (final c in asJsonList(row, 'baris cells'))
              c == null ? null : SingleFigure.fromJson(c),
          ],
      ]);
}

/// Deret gambar (FIG-SEQ): 3 sampai 4 gambar terlihat, lalu tepat satu sel
/// kosong (null) di ujung yang harus dijawab.
final class SequenceFigure extends FigureSpec {
  static const String kindCode = 'sequence';
  static const int minItems = 4;
  static const int maxItems = 5;

  SequenceFigure(Iterable<SingleFigure?> items)
      : items = List.unmodifiable(items);

  /// Gambar terlihat berurutan, lalu null.
  final List<SingleFigure?> items;

  @override
  String get kind => kindCode;

  @override
  SequenceFigure canonical() =>
      SequenceFigure([for (final i in items) i?.canonical()]);

  @override
  List<String> validate(String path) {
    final issues = <String>[];
    if (items.length < minItems || items.length > maxItems) {
      issues.add('$path.items berjumlah ${items.length}, '
          'harus $minItems..$maxItems');
    }
    if (items.isEmpty || items.last != null) {
      issues.add('$path.items harus berakhir dengan sel kosong');
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item == null) {
        if (i != items.length - 1) issues.add('$path.items[$i] kosong');
      } else {
        issues.addAll(item.validate('$path.items[$i]'));
      }
    }
    return issues;
  }

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'items': [for (final i in items) i?.toJson()],
      };

  static SequenceFigure _fromMap(Map<String, Object?> m) => SequenceFigure([
        for (final i in readList(m, 'items'))
          i == null ? null : SingleFigure.fromJson(i),
      ]);
}

/// Bentuk dari sel berisi pada kisi 4x4 (FIG-MIR). `cells[baris][kolom]`.
///
/// Dua kisi dianggap sama bila bentuknya sama setelah digeser ke pojok kiri
/// atas ([canonical]), karena yang dinilai adalah bentuknya, bukan letaknya.
final class GridFigure extends FigureSpec {
  static const String kindCode = 'grid';
  static const int size = 4;
  static const int minFilled = 1;

  GridFigure(Iterable<Iterable<bool>> cells)
      : cells = List.unmodifiable([
          for (final row in cells) List<bool>.unmodifiable(row),
        ]);

  factory GridFigure.fromPoints(Iterable<(int, int)> points) {
    final filled = points.toSet();
    return GridFigure([
      for (var r = 0; r < size; r++)
        [for (var c = 0; c < size; c++) filled.contains((r, c))],
    ]);
  }

  final List<List<bool>> cells;

  /// Sel berisi sebagai (baris, kolom), terurut baris lalu kolom.
  List<(int, int)> get points => [
        for (var r = 0; r < cells.length; r++)
          for (var c = 0; c < cells[r].length; c++)
            if (cells[r][c]) (r, c),
      ];

  int get filledCount => points.length;

  /// Cermin kiri-kanan (sumbu vertikal) dalam kotak 4x4.
  GridFigure mirrorLeftRight() =>
      GridFigure.fromPoints([for (final (r, c) in points) (r, size - 1 - c)]);

  /// Cermin atas-bawah (sumbu horizontal) dalam kotak 4x4.
  GridFigure mirrorTopBottom() =>
      GridFigure.fromPoints([for (final (r, c) in points) (size - 1 - r, c)]);

  /// Putar searah jarum jam sebanyak [quarterTurns] kali 90 derajat.
  GridFigure rotate(int quarterTurns) {
    var out = points;
    for (var i = 0; i < quarterTurns % 4; i++) {
      out = [for (final (r, c) in out) (c, size - 1 - r)];
    }
    return GridFigure.fromPoints(out);
  }

  /// Geser ke pojok kiri atas.
  @override
  GridFigure canonical() {
    final pts = points;
    if (pts.isEmpty) return this;
    var minR = size;
    var minC = size;
    for (final (r, c) in pts) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }
    return GridFigure.fromPoints(
        [for (final (r, c) in pts) (r - minR, c - minC)]);
  }

  /// Satu baris per kisi, "#" berisi dan "." kosong. Untuk pembahasan.
  String rowText(int r) => cells[r].map((b) => b ? '#' : '.').join();

  @override
  String get kind => kindCode;

  @override
  List<String> validate(String path) {
    final issues = <String>[];
    if (cells.length != size || cells.any((r) => r.length != size)) {
      issues.add('$path.cells bukan ${size}x$size');
    } else if (filledCount < minFilled) {
      issues.add('$path.cells kosong');
    }
    return issues;
  }

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'cells': [
          for (final row in cells) [for (final c in row) c ? 1 : 0],
        ],
      };

  static GridFigure _fromMap(Map<String, Object?> m) => GridFigure([
        for (final row in readList(m, 'cells'))
          [
            for (final c in asJsonList(row, 'baris cells'))
              c == 1
                  ? true
                  : c == 0
                      ? false
                      : throw const FormatException('sel kisi bukan 0 atau 1'),
          ],
      ]);
}
