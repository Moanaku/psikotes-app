import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

void main() {
  const tri = FigureObject(
    shape: Shape.triangle,
    count: 2,
    fill: Fill.hatch,
    rotation: Rotation.r90,
    size: FigureSize.large,
  );
  const circle = FigureObject(shape: Shape.circle, rotation: Rotation.r90);

  test(
      'objek menyebut jumlah, bentuk, isian, ukuran; rotasi hanya bila terlihat',
      () {
    expect(describeObject(tri), '2 segitiga arsir besar, diputar 90°');
    // Lingkaran tampak sama di semua rotasi, jadi rotasi tidak disebut.
    expect(describeObject(circle), '1 lingkaran kosong sedang');
  });

  test('gambar tunggal, kosong, dan banyak objek', () {
    expect(describeFigure(SingleFigure([circle])),
        'Gambar: 1 lingkaran kosong sedang.');
    expect(describeFigure(SingleFigure(const [])), 'Gambar: kosong.');
    expect(describeFigure(SingleFigure([circle, tri])), contains(' dan '));
  });

  test('matriks menandai sel yang harus dijawab', () {
    final cell = SingleFigure([circle]);
    final m = MatrixFigure([
      [cell, cell, cell],
      [cell, cell, cell],
      [cell, cell, null],
    ]);
    final text = describeFigure(m);
    expect(text, startsWith('Matriks 3 kali 3.'));
    expect(text, contains('Baris 3: '));
    expect(text, contains('kolom 3 yang harus dijawab'));
    expect('yang harus dijawab'.allMatches(text), hasLength(1));
  });

  test('deret, kisi, dan tabel', () {
    final cell = SingleFigure([circle]);
    final s = SequenceFigure([cell, cell, cell, null]);
    expect(describeFigure(s), startsWith('Deret 4 gambar.'));
    expect(describeFigure(s), contains('gambar 4 yang harus dijawab'));

    final g = GridFigure.fromPoints([(0, 1), (0, 2), (3, 0)]);
    final gt = describeFigure(g);
    expect(gt, contains('3 sel terisi'));
    expect(gt, contains('baris 1 sel terisi di kolom 2 dan 3'));
    expect(gt, contains('baris 2 kosong'));

    final t = TableFigure(headers: [
      'Hari',
      'Terjual'
    ], rows: [
      ['Senin', '10'],
      ['Selasa', '12'],
    ]);
    expect(describeFigure(t), 'Tabel 2 baris dengan kolom Hari dan Terjual.');
  });

  test('deskripsi ada untuk setiap gambar semua generator terdaftar', () {
    for (final type in GeneratorRegistry.types) {
      for (final d in Difficulty.values) {
        for (var seed = 1; seed <= 20; seed++) {
          final q = GeneratorRegistry.generate(type, seed, d);
          final figures = [
            q.stem.figure,
            for (final o in q.options) o.content.figure,
          ].whereType<FigureSpec>();
          for (final f in figures) {
            final text = describeFigure(f);
            expect(text.trim(), isNotEmpty, reason: '${type.code} $seed');
            expect(text, isNot(contains('null')));
          }
        }
      }
    }
  });
}
