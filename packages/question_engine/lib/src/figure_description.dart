/// Deskripsi teks gambar untuk pembaca layar (label semantik renderer, T08).
///
/// Dart murni dan deterministik. Teks memakai nama bentuk, isian, dan ukuran
/// dari `figure_text.dart` supaya sama dengan pembahasan otomatis.
library;

import 'figure_spec.dart';
import 'generators/figural/figure_text.dart';

/// Satu objek, mis. "2 lingkaran arsir besar" atau "segitiga penuh sedang,
/// diputar 90°". Rotasi disebut hanya bila terlihat (bentuk tidak simetris).
String describeObject(FigureObject o) {
  final turned = o.canonical().rotation != Rotation.r0;
  final count = o.count == 1 ? '1' : '${o.count}';
  return '$count ${shapeName(o.shape)} ${fillName(o.fill)} '
      '${sizeName(o.size)}${turned ? ', diputar ${o.rotation.degrees}°' : ''}';
}

String describeSingle(SingleFigure f) =>
    f.objects.isEmpty ? 'kosong' : f.objects.map(describeObject).join(' dan ');

/// Deskripsi lengkap. Sel yang harus dijawab disebut "yang harus dijawab".
String describeFigure(FigureSpec figure) => switch (figure) {
      SingleFigure() => 'Gambar: ${describeSingle(figure)}.',
      MatrixFigure() => _describeMatrix(figure),
      SequenceFigure() => _describeSequence(figure),
      GridFigure() => _describeGrid(figure),
      TableFigure() => _describeTable(figure),
    };

String _describeMatrix(MatrixFigure m) {
  final rows = <String>[];
  for (var r = 0; r < m.cells.length; r++) {
    final cells = <String>[];
    for (var c = 0; c < m.cells[r].length; c++) {
      final cell = m.cells[r][c];
      cells.add(
          'kolom ${c + 1} ${cell == null ? 'yang harus dijawab' : describeSingle(cell)}');
    }
    rows.add('Baris ${r + 1}: ${cells.join('; ')}.');
  }
  return 'Matriks ${MatrixFigure.size} kali ${MatrixFigure.size}. ${rows.join(' ')}';
}

String _describeSequence(SequenceFigure s) {
  final items = <String>[];
  for (var i = 0; i < s.items.length; i++) {
    final item = s.items[i];
    items.add(
        'gambar ${i + 1} ${item == null ? 'yang harus dijawab' : describeSingle(item)}');
  }
  return 'Deret ${s.items.length} gambar. ${items.join('; ')}.';
}

String _describeGrid(GridFigure g) {
  final rows = <String>[];
  for (var r = 0; r < g.cells.length; r++) {
    final cols = [
      for (var c = 0; c < g.cells[r].length; c++)
        if (g.cells[r][c]) '${c + 1}',
    ];
    rows.add(
        'baris ${r + 1} ${cols.isEmpty ? 'kosong' : 'sel terisi di kolom ${joinList(cols)}'}');
  }
  return 'Kisi ${GridFigure.size} kali ${GridFigure.size} dengan '
      '${g.filledCount} sel terisi. ${rows.join('; ')}.';
}

String _describeTable(TableFigure t) =>
    'Tabel ${t.rows.length} baris dengan kolom ${joinList(t.headers)}.';
