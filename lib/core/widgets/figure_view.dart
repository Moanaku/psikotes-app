import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:question_engine/question_engine.dart';

import '../theme/app_tokens.dart';

/// Menggambar `FigureSpec` dari data (single, sequence, matrix3x3, grid, table),
/// tanpa aset gambar. Warna hanya dari token: bentuk digambar `ink`, kerangka
/// `outline`, sel yang harus dijawab berlatar `accent` dengan tanda tanya.
///
/// `fill` dibedakan lewat pola, bukan warna: kosong (hanya garis), penuh, dan
/// arsir (garis diagonal 45 derajat di layar, tidak ikut berputar). Rotasi
/// searah jarum jam; lingkaran, persegi, dan palang tampak sama di semua rotasi
/// (docs/11-asumsi-dan-pertanyaan.md, A8).
///
/// Lebar mengikuti ruang yang tersedia, dibatasi [maxExtent]. Label semantik
/// otomatis dari `describeFigure`; isi [semanticLabel] untuk menimpanya.
class FigureView extends StatelessWidget {
  const FigureView({
    super.key,
    required this.figure,
    this.maxExtent,
    this.semanticLabel,
    this.mono = false,
  });

  final FigureSpec figure;

  /// Isi tabel dengan font kode (lembar kerja dan flowchart IT).
  final bool mono;

  /// Batas lebar gambar; null berarti selebar ruang yang tersedia.
  final double? maxExtent;
  final String? semanticLabel;

  /// Lebar bawaan bila ruang tidak terbatas.
  static const double fallbackExtent = 240;

  /// Lebar terkecil satu gambar dalam deret sebelum deret dipecah ke dua baris.
  static const double minSequenceCell = 64;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? describeFigure(figure);
    final spec = figure;
    if (spec is TableFigure) {
      return Semantics(
        container: true,
        label: label,
        child: _FigureTable(table: spec, mono: mono),
      );
    }
    final tokens = context.tokens.colors;
    final palette = FigurePalette(
      ink: tokens.ink,
      outline: tokens.outline,
      outlineVariant: tokens.outlineVariant,
      accent: tokens.accent,
      onAccent: tokens.onAccent,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (maxExtent ?? fallbackExtent);
        if (maxExtent != null) width = math.min(width, maxExtent!);
        final layout = FigureLayout.of(spec, width);
        return Semantics(
          image: true,
          label: label,
          excludeSemantics: true,
          child: CustomPaint(
            size: layout.size,
            painter: FigurePainter(figure: spec, palette: palette),
          ),
        );
      },
    );
  }
}

/// Warna painter, diambil dari token oleh [FigureView].
@immutable
class FigurePalette {
  const FigurePalette({
    required this.ink,
    required this.outline,
    required this.outlineVariant,
    required this.accent,
    required this.onAccent,
  });

  final Color ink;
  final Color outline;
  final Color outlineVariant;
  final Color accent;
  final Color onAccent;
}

/// Ukuran gambar untuk lebar tertentu: [size] dan, untuk deret, jumlah sel per baris.
@immutable
class FigureLayout {
  const FigureLayout(this.size, {this.perRow = 0, this.cell = 0});

  final Size size;
  final int perRow;
  final double cell;

  /// Jarak antar sel deret, sebagai pecahan lebar sel.
  static const double _gapRatio = 0.12;

  static FigureLayout of(FigureSpec spec, double width) {
    if (spec is SequenceFigure) {
      final n = spec.items.length;
      var perRow = n;
      double cell = _cellFor(width, perRow);
      if (cell < FigureView.minSequenceCell && n > 3) {
        perRow = (n + 1) ~/ 2;
        cell = _cellFor(width, perRow);
      }
      final rows = (n / perRow).ceil();
      final gap = cell * _gapRatio;
      return FigureLayout(
        Size(width, rows * cell + (rows - 1) * gap),
        perRow: perRow,
        cell: cell,
      );
    }
    return FigureLayout(Size(width, width));
  }

  static double _cellFor(double width, int perRow) =>
      width / (perRow + (perRow - 1) * _gapRatio);
}

class FigurePainter extends CustomPainter {
  FigurePainter({required this.figure, required this.palette});

  final FigureSpec figure;
  final FigurePalette palette;

  /// Garis kerangka dan arsir, dalam dp. Garis bentuk menipis pada bentuk kecil
  /// ([_shapeStroke]) agar isian di dalamnya tetap terlihat.
  static const double frameStroke = 1;
  static const double hatchStroke = 1;
  static const double maxShapeStroke = 2;
  static const double minShapeStroke = 1.25;

  /// Pecahan sisi sel yang dipakai bentuk menurut ukuran (s, m, l).
  static const Map<FigureSize, double> _sizeFactor = {
    FigureSize.small: 0.5,
    FigureSize.medium: 0.72,
    FigureSize.large: 0.94,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final spec = figure;
    switch (spec) {
      case SingleFigure():
        _paintSingle(canvas, Offset.zero & size, spec);
      case MatrixFigure():
        _paintMatrix(canvas, size, spec);
      case SequenceFigure():
        _paintSequence(canvas, size, spec);
      case GridFigure():
        _paintGrid(canvas, size, spec);
      case TableFigure():
        break; // digambar sebagai widget teks oleh FigureView
    }
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      !identical(old.figure, figure) || old.palette != palette;

  // ---------- kerangka ----------

  Paint get _frame => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = frameStroke
    ..color = palette.outline;

  void _paintAnswerCell(Canvas canvas, Rect cell) {
    canvas.drawRect(cell, Paint()..color = palette.accent);
    canvas.drawRect(cell, _frame..color = palette.ink);
    final style = cell.shortestSide >= 80
        ? AppType.headline(palette.onAccent)
        : AppType.title(palette.onAccent);
    final tp = TextPainter(
      text: TextSpan(text: '?', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, cell.center - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------- matriks, deret, kisi ----------

  void _paintMatrix(Canvas canvas, Size size, MatrixFigure m) {
    final cell = size.width / MatrixFigure.size;
    for (var r = 0; r < MatrixFigure.size; r++) {
      for (var c = 0; c < MatrixFigure.size; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final f =
            r < m.cells.length && c < m.cells[r].length ? m.cells[r][c] : null;
        if (f == null) {
          _paintAnswerCell(canvas, rect);
        } else {
          _paintSingle(canvas, rect, f);
        }
      }
    }
    // Garis dalam di bawah ketebalan garis luar: satu jalur gambar untuk semuanya.
    final line = _frame..color = palette.outlineVariant;
    for (var i = 1; i < MatrixFigure.size; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    canvas.drawRect(Offset.zero & size, _frame..color = palette.outline);
  }

  void _paintSequence(Canvas canvas, Size size, SequenceFigure s) {
    final layout = FigureLayout.of(s, size.width);
    final cell = layout.cell;
    final gap = cell * FigureLayout._gapRatio;
    for (var i = 0; i < s.items.length; i++) {
      final row = i ~/ layout.perRow;
      final col = i % layout.perRow;
      final rect =
          Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell);
      final item = s.items[i];
      if (item == null) {
        _paintAnswerCell(canvas, rect);
      } else {
        _paintSingle(canvas, rect, item);
        canvas.drawRect(rect, _frame..color = palette.outline);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size, GridFigure g) {
    final cell = size.width / GridFigure.size;
    final inset = math.max(1.0, cell * 0.04);
    final fill = Paint()..color = palette.ink;
    for (var r = 0; r < g.cells.length; r++) {
      for (var c = 0; c < g.cells[r].length; c++) {
        if (g.cells[r][c]) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell, cell).deflate(inset),
            fill,
          );
        }
      }
    }
    final line = _frame..color = palette.outlineVariant;
    for (var i = 1; i < GridFigure.size; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    canvas.drawRect(Offset.zero & size, _frame..color = palette.outline);
  }

  // ---------- satu sel ----------

  /// Satu sel berisi 0 sampai 4 objek: tiap objek mendapat satu petak, dan
  /// `count` salinannya dibagi lagi di dalam petak itu.
  void _paintSingle(Canvas canvas, Rect cell, SingleFigure f) {
    final area = cell.deflate(cell.shortestSide * 0.04);
    final slots = _split(area, f.objects.length);
    for (var i = 0; i < f.objects.length; i++) {
      final o = f.objects[i];
      final copies = _split(slots[i], o.count);
      for (final copy in copies) {
        final d = copy.shortestSide * _sizeFactor[o.size]!;
        _paintShape(canvas, copy.center, d, o);
      }
    }
  }

  /// Membagi [area] menjadi [n] petak persegi (1 sampai 4): 1 di tengah, 2
  /// berdampingan, 3 dua di atas satu di tengah bawah, 4 dua kali dua.
  static List<Rect> _split(Rect area, int n) {
    if (n <= 0) return const [];
    final c = area.center;
    final w = area.width;
    final h = area.height;
    Rect box(double cx, double cy, double side) =>
        Rect.fromCenter(center: Offset(cx, cy), width: side, height: side);
    switch (n) {
      case 1:
        return [box(c.dx, c.dy, math.min(w, h))];
      case 2:
        final s = math.min(w / 2, h);
        return [
          box(c.dx - w / 4, c.dy, s),
          box(c.dx + w / 4, c.dy, s),
        ];
      case 3:
        final s = math.min(w / 2, h / 2);
        return [
          box(c.dx - w / 4, c.dy - h / 4, s),
          box(c.dx + w / 4, c.dy - h / 4, s),
          box(c.dx, c.dy + h / 4, s),
        ];
      default:
        final s = math.min(w / 2, h / 2);
        return [
          box(c.dx - w / 4, c.dy - h / 4, s),
          box(c.dx + w / 4, c.dy - h / 4, s),
          box(c.dx - w / 4, c.dy + h / 4, s),
          box(c.dx + w / 4, c.dy + h / 4, s),
        ].sublist(0, n);
    }
  }

  // ---------- bentuk ----------

  /// Garis bentuk dalam koordinat satuan: pusat di (0, 0), lebar dan tinggi
  /// terbesar 1. Dikalikan [d] dan diputar oleh pemanggil.
  static Path _unitPath(Shape shape) {
    final p = Path();
    switch (shape) {
      case Shape.circle:
        p.addOval(Rect.fromCircle(center: Offset.zero, radius: 0.5));
      case Shape.square:
        p.addRect(
            Rect.fromCenter(center: Offset.zero, width: 0.88, height: 0.88));
      case Shape.triangle:
        p
          ..moveTo(0, -0.45)
          ..lineTo(0.48, 0.45)
          ..lineTo(-0.48, 0.45)
          ..close();
      case Shape.diamond:
        p
          ..moveTo(0, -0.5)
          ..lineTo(0.31, 0)
          ..lineTo(0, 0.5)
          ..lineTo(-0.31, 0)
          ..close();
      case Shape.pentagon:
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final x = 0.52 * math.cos(a);
          final y = 0.52 * math.sin(a);
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        p.close();
      case Shape.cross:
        const t = 0.16; // setengah tebal lengan
        const e = 0.45; // setengah bentangan
        p
          ..moveTo(-t, -e)
          ..lineTo(t, -e)
          ..lineTo(t, -t)
          ..lineTo(e, -t)
          ..lineTo(e, t)
          ..lineTo(t, t)
          ..lineTo(t, e)
          ..lineTo(-t, e)
          ..lineTo(-t, t)
          ..lineTo(-e, t)
          ..lineTo(-e, -t)
          ..lineTo(-t, -t)
          ..close();
    }
    return p;
  }

  void _paintShape(Canvas canvas, Offset center, double d, FigureObject o) {
    final m = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(o.rotation.degrees * math.pi / 180)
      ..scaleByDouble(d, d, 1, 1);
    final path = _unitPath(o.shape).transform(m.storage);

    switch (o.fill) {
      case Fill.empty:
        break;
      case Fill.solid:
        canvas.drawPath(path, Paint()..color = palette.ink);
      case Fill.hatch:
        _hatch(canvas, path, d);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            math.max(minShapeStroke, math.min(maxShapeStroke, d * 0.09))
        ..strokeJoin = StrokeJoin.round
        ..color = palette.ink,
    );
  }

  /// Garis diagonal "/" pada sudut tetap di layar, dipotong oleh bentuk.
  void _hatch(Canvas canvas, Path path, double d) {
    final spacing = math.max(3.0, d * 0.15);
    final b = path.getBounds();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hatchStroke
      ..color = palette.ink;
    canvas.save();
    canvas.clipPath(path);
    // Garis hanya perlu dari x = kiri - tinggi sampai kanan; fasenya sama
    // dengan yang berawal dari -(lebar + tinggi), jadi gambar tidak bergeser.
    final reach = b.width + b.height;
    final first = -reach + (b.width / spacing).ceil() * spacing;
    for (var k = first; k <= b.width; k += spacing) {
      final x = b.left + k;
      canvas.drawLine(Offset(x, b.bottom), Offset(x + b.height, b.top), paint);
    }
    canvas.restore();
  }
}

/// Tabel data soal cerita: judul kolom tebal, baris dipisah garis, angka rata
/// kanan. Bukan kartu; mengikuti aturan daftar sebagai baris dan garis.
///
/// Lebar kolom: tiap kolom paling sedikit selebar kata terpanjangnya (pada
/// skala huruf pengguna), sisa lebar dibagi menurut bobot kolom. Judul panjang
/// membungkus per kata. Bila kata-kata terpanjang pun tidak muat, tabel
/// digulir mendatar, jadi tidak ada kata yang terpotong di tengah.
class _FigureTable extends StatelessWidget {
  const _FigureTable({required this.table, required this.mono});

  final TableFigure table;
  final bool mono;

  static const double _cellPadding = AppSpace.s4;

  /// Lebar kata terpanjang di antara [texts] untuk [style] pada skala huruf
  /// [scaler].
  static double _longestWord(
    Iterable<String> texts,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    var widest = 0.0;
    for (final text in texts) {
      for (final word in text.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final head = AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600);
    final body = mono ? AppType.code(c.ink) : AppType.body(c.ink);
    final scaler = MediaQuery.textScalerOf(context);
    // Teks sel digambar dengan `DefaultTextStyle` di bawahnya (mis. jarak
    // huruf dari tema); pengukuran harus memakai gaya gabungan yang sama.
    final inherited = DefaultTextStyle.of(context).style;
    final direction = Directionality.of(context);
    TextAlign align(int col) => col == 0 ? TextAlign.start : TextAlign.end;

    Widget cell(String text, int col, TextStyle style) => Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s8,
            horizontal: _cellPadding,
          ),
          child: Text(text, style: style, textAlign: align(col)),
        );

    final columns = table.headers.length;
    final minWidths = [
      for (var i = 0; i < columns; i++)
        math.max(
              _longestWord(
                [table.headers[i]],
                inherited.merge(head),
                scaler,
                direction,
              ),
              _longestWord(
                [for (final row in table.rows) row[i]],
                inherited.merge(body),
                scaler,
                direction,
              ),
            ) +
            2 * _cellPadding +
            1,
    ];
    final weights = [
      for (var i = 0; i < columns; i++) i == 0 ? 1.6 : 1.0,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final needed = minWidths.fold<double>(0, (a, b) => a + b);
        final spare = math.max(0.0, available - needed);
        final weightSum = weights.fold<double>(0, (a, b) => a + b);
        final widths = [
          for (var i = 0; i < columns; i++)
            minWidths[i] + spare * weights[i] / weightSum,
        ];
        final grid = Table(
          border: TableBorder(
            top: BorderSide(color: c.outline),
            bottom: BorderSide(color: c.outline),
            horizontalInside: BorderSide(color: c.outlineVariant),
          ),
          columnWidths: {
            for (var i = 0; i < columns; i++) i: FixedColumnWidth(widths[i]),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: c.surfaceContainerHigh),
              children: [
                for (var i = 0; i < columns; i++)
                  cell(table.headers[i], i, head),
              ],
            ),
            for (final row in table.rows)
              TableRow(
                children: [
                  for (var i = 0; i < row.length; i++) cell(row[i], i, body),
                ],
              ),
          ],
        );
        if (needed <= available) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: grid,
        );
      },
    );
  }
}
