import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/figure_view.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';

import 'golden_helper.dart';

const _boundaryKey = ValueKey('golden-boundary');

SingleFigure _one(
  Shape shape, {
  Fill fill = Fill.empty,
  Rotation rotation = Rotation.r0,
  FigureSize size = FigureSize.medium,
  int count = 1,
}) =>
    SingleFigure([
      FigureObject(
        shape: shape,
        fill: fill,
        rotation: rotation,
        size: size,
        count: count,
      ),
    ]);

Widget _fig(FigureSpec f, {double extent = 64}) => SizedBox(
      width: extent,
      height: extent,
      child: FigureView(figure: f, maxExtent: extent),
    );

Widget _caption(String text) => Builder(
      builder: (context) =>
          Text(text, style: AppType.caption(context.tokens.colors.inkMuted)),
    );

Widget _row(String label, List<Widget> cells) => Row(
      children: [
        SizedBox(width: AppSpace.s48 + AppSpace.s16, child: _caption(label)),
        for (final c in cells) ...[c, const SizedBox(width: AppSpace.s8)],
      ],
    );

/// Cuplikan layar soal: stem, gambar stem, lalu opsi dalam dua kolom.
Widget _questionScene(Question q) => Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caption('${q.type.code} ${q.difficulty.code} seed ${q.seed}'),
          const SizedBox(height: AppSpace.s8),
          if (q.stem.text != null)
            Builder(
              builder: (c) =>
                  Text(q.stem.text!, style: AppType.body(c.tokens.colors.ink)),
            ),
          if (q.stem.figure != null) ...[
            const SizedBox(height: AppSpace.s8),
            FigureView(figure: q.stem.figure!),
          ],
          const SizedBox(height: AppSpace.s16),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (var i = 0; i < q.options.length; i++)
                LayoutBuilder(
                  builder: (context, _) => SizedBox(
                    width: 150,
                    child: _option(q.options[i], i == q.correctIndex),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

Widget _option(Option o, bool selected) {
  final fig = o.content.figure;
  return OptionTile(
    letter: o.id,
    label: fig == null ? o.content.text : null,
    semanticLabel: fig == null ? null : describeFigure(fig),
    selected: selected,
    onTap: null,
    child: fig == null ? null : FigureView(figure: fig, maxExtent: 96),
  );
}

Question _q(QuestionType t, int seed, Difficulty d) =>
    GeneratorRegistry.generate(t, seed, d);

/// Piksel RGBA dari bidang gambar bertanda `golden-boundary`.
Future<({Uint8List bytes, int width, int height})> _pixels(
    WidgetTester tester) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (
      bytes: data!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  }))!;
}

/// Pecahan piksel yang berbeda dari warna latar dalam gambar.
double _inkFraction(({Uint8List bytes, int width, int height}) px) {
  final bg = AppColors.light.surface;
  final br = (bg.r * 255).round();
  final bgc = (bg.g * 255).round();
  final bb = (bg.b * 255).round();
  var ink = 0;
  for (var i = 0; i < px.bytes.length; i += 4) {
    final d = (px.bytes[i] - br).abs() +
        (px.bytes[i + 1] - bgc).abs() +
        (px.bytes[i + 2] - bb).abs();
    if (d > 60) ink++;
  }
  return ink / (px.bytes.length / 4);
}

/// Jumlah piksel yang berbeda nyata antara dua gambar yang sama ukurannya.
int _diffPixels(({Uint8List bytes, int width, int height}) a,
    ({Uint8List bytes, int width, int height}) b) {
  expect(a.bytes.length, b.bytes.length);
  var n = 0;
  for (var i = 0; i < a.bytes.length; i += 4) {
    final d = (a.bytes[i] - b.bytes[i]).abs() +
        (a.bytes[i + 1] - b.bytes[i + 1]).abs() +
        (a.bytes[i + 2] - b.bytes[i + 2]).abs();
    if (d > 48) n++;
  }
  return n;
}

Future<({Uint8List bytes, int width, int height})> _render(
    WidgetTester tester, FigureSpec f,
    {double extent = 96}) async {
  await pumpScene(tester, _fig(f, extent: extent), width: extent);
  return _pixels(tester);
}

void main() {
  // ---------- golden: tiap jenis, di 360 dp dan 412 dp ----------
  for (final width in [360.0, 412.0]) {
    final w = width.round();

    goldenTest('golden: 6 bentuk x 3 isian @$w', (tester) async {
      await pumpScene(
        tester,
        scene([
          _row('', [
            for (final f in Fill.values)
              SizedBox(width: 64, child: _caption(f.code)),
          ]),
          for (final s in Shape.values)
            _row(s.code, [
              for (final f in Fill.values) _fig(_one(s, fill: f)),
            ]),
        ], gap: AppSpace.s8),
        width: width,
      );
      await expectGolden(tester, 'figure_shapes_fill_$w');
    });

    goldenTest('golden: rotasi 0, 90, 180, 270 @$w', (tester) async {
      await pumpScene(
        tester,
        scene([
          for (final s in [
            Shape.triangle,
            Shape.pentagon,
            Shape.diamond,
            Shape.cross,
            Shape.square,
          ])
            _row(s.code, [
              for (final r in Rotation.values)
                _fig(_one(s, fill: Fill.hatch, rotation: r), extent: 56),
            ]),
        ], gap: AppSpace.s8),
        width: width,
      );
      await expectGolden(tester, 'figure_rotation_$w');
    });

    goldenTest('golden: ukuran dan jumlah @$w', (tester) async {
      await pumpScene(
        tester,
        scene([
          for (var n = 1; n <= 4; n++)
            _row('jumlah $n', [
              for (final s in FigureSize.values)
                _fig(_one(Shape.pentagon, fill: Fill.hatch, size: s, count: n)),
            ]),
          _row('gabungan', [
            _fig(SingleFigure(const [
              FigureObject(shape: Shape.circle, fill: Fill.solid),
              FigureObject(shape: Shape.cross),
            ])),
            _fig(SingleFigure(const [
              FigureObject(shape: Shape.square, fill: Fill.hatch),
              FigureObject(shape: Shape.triangle),
              FigureObject(shape: Shape.diamond, fill: Fill.solid),
            ])),
            _fig(SingleFigure(const [])),
          ]),
        ], gap: AppSpace.s8),
        width: width,
      );
      await expectGolden(tester, 'figure_size_count_$w');
    });

    goldenTest('golden: matriks 3x3 lengkap (FIG-MTX) @$w', (tester) async {
      await pumpScene(
          tester, _questionScene(_q(QuestionType.figMtx, 11, Difficulty.hard)),
          width: width);
      await expectGolden(tester, 'figure_matrix_$w');
    });

    goldenTest('golden: deret 4 dan 5 gambar (FIG-SEQ) @$w', (tester) async {
      await pumpScene(
        tester,
        Column(children: [
          _questionScene(_q(QuestionType.figSeq, 3, Difficulty.easy)),
          _questionScene(_q(QuestionType.figSeq, 5, Difficulty.hard)),
        ]),
        width: width,
      );
      await expectGolden(tester, 'figure_sequence_$w');
    });

    goldenTest('golden: kisi 4x4 (FIG-MIR) @$w', (tester) async {
      await pumpScene(
          tester, _questionScene(_q(QuestionType.figMir, 8, Difficulty.medium)),
          width: width);
      await expectGolden(tester, 'figure_grid_$w');
    });

    goldenTest('golden: pilih yang berbeda (FIG-ODD) @$w', (tester) async {
      await pumpScene(
          tester, _questionScene(_q(QuestionType.figOdd, 4, Difficulty.hard)),
          width: width);
      await expectGolden(tester, 'figure_odd_$w');
    });

    goldenTest('golden: tabel soal cerita (NUM-WORD) @$w', (tester) async {
      await pumpScene(
          tester, _questionScene(_q(QuestionType.numWord, 6, Difficulty.hard)),
          width: width);
      await expectGolden(tester, 'figure_table_$w');
    });
  }

  // ---------- perilaku ----------

  testWidgets('semantik: label sama dengan describeFigure, sel jawaban disebut',
      (tester) async {
    final handle = tester.ensureSemantics();
    final q = _q(QuestionType.figMtx, 11, Difficulty.medium);
    final fig = q.stem.figure!;
    await pumpScene(tester, FigureView(figure: fig));
    final label = describeFigure(fig);
    expect(find.bySemanticsLabel(label), findsOneWidget);
    expect(label, contains('yang harus dijawab'));
    expect(label, startsWith('Matriks 3 kali 3'));
    handle.dispose();
  });

  testWidgets('semantik: semanticLabel menimpa label otomatis', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScene(
        tester,
        FigureView(
            figure: _one(Shape.circle), semanticLabel: 'Pilihan lingkaran'));
    expect(find.bySemanticsLabel('Pilihan lingkaran'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantik: opsi figural dibaca "Opsi [huruf], [deskripsi]"',
      (tester) async {
    final handle = tester.ensureSemantics();
    final fig = _one(Shape.triangle, fill: Fill.hatch, rotation: Rotation.r90);
    await pumpScene(
      tester,
      OptionTile(
        letter: 'B',
        semanticLabel: describeFigure(fig),
        selected: false,
        onTap: () {},
        child: FigureView(figure: fig, maxExtent: 96),
      ),
    );
    expect(tester.getSemantics(find.byType(OptionTile)).label,
        'Opsi B, ${describeFigure(fig)}');
    handle.dispose();
  });

  testWidgets('tabel: label ringkas, teks sel tetap terbaca pembaca layar',
      (tester) async {
    final handle = tester.ensureSemantics();
    final t = TableFigure(headers: const [
      'Hari',
      'Terjual'
    ], rows: const [
      ['Senin', '10'],
      ['Selasa', '12']
    ]);
    await pumpScene(tester, FigureView(figure: t));
    expect(find.text('Selasa'), findsOneWidget);
    expect(find.bySemanticsLabel(describeFigure(t)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tabel tidak meluap pada font sistem 200% di 360 dp',
      (tester) async {
    final t = TableFigure(headers: const [
      'Produk',
      'Harga satuan',
      'Jumlah terjual'
    ], rows: const [
      ['Kabel pengisi daya', 'Rp45.000', '12'],
      ['Penyangga laptop', 'Rp120.000', '7'],
    ]);
    await pumpScene(tester, FigureView(figure: t), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  test('tata letak deret: 4 gambar satu baris, 5 gambar dipecah di 360 dp', () {
    final cell = SingleFigure(const [FigureObject(shape: Shape.circle)]);
    final s4 = SequenceFigure([cell, cell, cell, null]);
    final s5 = SequenceFigure([cell, cell, cell, cell, null]);
    final l4 = FigureLayout.of(s4, 328);
    final l5 = FigureLayout.of(s5, 328);
    expect(l4.perRow, 4);
    expect(l4.cell, greaterThanOrEqualTo(FigureView.minSequenceCell));
    expect(l5.perRow, 3);
    expect(l5.cell, greaterThanOrEqualTo(FigureView.minSequenceCell));
    expect(l5.size.height, greaterThan(l5.cell));
    expect(l5.size.width, 328);
    // Di lebar longgar 5 gambar tetap satu baris.
    expect(FigureLayout.of(s5, 560).perRow, 5);
  });

  testWidgets(
      'isian dibedakan lewat pola: kosong < arsir < penuh di semua ukuran dan jumlah',
      (tester) async {
    for (final shape in Shape.values) {
      for (final size in FigureSize.values) {
        for (final count in [1, 4]) {
          final cover = <Fill, double>{};
          for (final fill in Fill.values) {
            final px = await _render(
                tester, _one(shape, fill: fill, size: size, count: count),
                extent: 64);
            cover[fill] = _inkFraction(px);
          }
          final why = '${shape.code} ${size.code} x$count $cover';
          expect(cover[Fill.hatch]!, greaterThan(cover[Fill.empty]! * 1.1),
              reason: 'arsir harus lebih padat dari kosong: $why');
          expect(cover[Fill.solid]!, greaterThan(cover[Fill.hatch]! * 1.1),
              reason: 'penuh harus lebih padat dari arsir: $why');
        }
      }
    }
  });

  testWidgets(
      'simetri rotasi mengikuti A8: bentuk simetris tidak berubah, bentuk lain berbeda',
      (tester) async {
    const tolerance = 40; // piksel; anti-aliasing putaran 90 derajat
    for (final fill in Fill.values) {
      for (final shape in Shape.values) {
        final px = <Rotation, ({Uint8List bytes, int width, int height})>{};
        for (final r in Rotation.values) {
          px[r] = await _render(tester, _one(shape, fill: fill, rotation: r));
        }
        final period = shape.rotationPeriod;
        for (final a in Rotation.values) {
          for (final b in Rotation.values) {
            if (a.index >= b.index) continue;
            final same = (a.index % period) == (b.index % period);
            final diff = _diffPixels(px[a]!, px[b]!);
            final why =
                '${shape.code} ${fill.code} ${a.degrees} vs ${b.degrees}: $diff';
            if (same) {
              expect(diff, lessThanOrEqualTo(tolerance),
                  reason: 'harus sama, $why');
            } else {
              expect(diff, greaterThan(tolerance * 4),
                  reason: 'harus beda, $why');
            }
          }
        }
      }
    }
  });

  testWidgets('ukuran s, m, l dan jumlah 1 sampai 4 tampak berbeda',
      (tester) async {
    final seen = <String>{};
    for (final size in FigureSize.values) {
      for (var n = 1; n <= 4; n++) {
        final px = await _render(
            tester, _one(Shape.square, fill: Fill.solid, size: size, count: n));
        seen.add(_inkFraction(px).toStringAsFixed(3));
      }
    }
    // 12 kombinasi; beberapa boleh serupa (mis. besar x4 dan sedang x1 mendekati), tetapi tidak semua.
    expect(seen.length, greaterThanOrEqualTo(8));
  });

  // ---------- semua generator di registry ----------

  testWidgets(
      'soal dari seluruh generator tergambar tanpa galat dengan label semantik',
      (tester) async {
    final handle = tester.ensureSemantics();
    var figures = 0;
    for (final type in GeneratorRegistry.types) {
      for (final d in Difficulty.values) {
        for (var seed = 1; seed <= 12; seed++) {
          final q = _q(type, seed, d);
          await pumpScene(tester, _questionScene(q));
          expect(tester.takeException(), isNull,
              reason: '${type.code} ${d.code} seed $seed');
          final expected = [
            q.stem.figure,
            for (final o in q.options) o.content.figure,
          ].whereType<FigureSpec>().toList();
          expect(find.byType(FigureView), findsNWidgets(expected.length),
              reason: '${type.code} ${d.code} seed $seed');
          if (q.stem.figure != null) {
            expect(find.bySemanticsLabel(describeFigure(q.stem.figure!)),
                findsOneWidget);
            figures++;
          }
          // Opsi figural dibaca lewat OptionTile: "Opsi [huruf], [deskripsi]".
          for (var i = 0; i < q.options.length; i++) {
            final fig = q.options[i].content.figure;
            if (fig == null) continue;
            expect(
              tester.getSemantics(find.byType(OptionTile).at(i)).label,
              'Opsi ${q.options[i].id}, ${describeFigure(fig)}',
            );
            figures++;
          }
        }
      }
    }
    expect(figures, greaterThan(500));
    // Setiap jenis gambar muncul sedikitnya sekali di seluruh generator.
    final kinds = <String>{};
    for (final type in GeneratorRegistry.types) {
      final q = _q(type, 1, Difficulty.medium);
      for (final f in [
        q.stem.figure,
        for (final o in q.options) o.content.figure,
      ].whereType<FigureSpec>()) {
        kinds.add(f.kind);
      }
    }
    expect(kinds, {'single', 'sequence', 'matrix3x3', 'grid', 'table'});
    handle.dispose();
  });
}
