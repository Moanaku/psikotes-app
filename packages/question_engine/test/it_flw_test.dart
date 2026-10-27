import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/naive_flw.dart';
import 'support/property_harness.dart';

List<String> itFlwBounds(Question q) {
  final issues = <String>[];
  final chart = Flowchart.fromTable(q.stem.figure);
  if (chart == null) return ['tabel bukan flowchart'];
  if (chart.toTable().toJson().toString() !=
      q.stem.figure!.toJson().toString()) {
    issues.add('tabel tidak kanonik');
  }
  if (chart.reachable.length != chart.nodes.length) {
    issues.add('ada kotak yang tidak tercapai');
  }
  final lines = (q.stem.text ?? '').split('\n');
  if (lines.length != 2 || FlwQuestion.parse(lines.last) == null) {
    issues.add('pertanyaan tidak terurai');
  }
  final run = chart.run();
  if (run.path.length > ItFlwGenerator.maxPath) {
    issues.add('jalur ${run.path.length} kotak');
  }
  if (q.options.length != ItFlwGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  if (!q.tags.single.startsWith('rule:it-flw:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  return issues;
}

Question flw(List<List<String>> rows, String ask, List<String> options) =>
    Question(
      type: QuestionType.itFlw,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(
        text: '$flwIntro\n$ask',
        figure: TableFigure(headers: flwHeaders, rows: rows),
      ),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i), content: QuestionContent(text: options[i])),
      ],
      correctIndex: 0,
      explanation: 'x',
      estimatedSeconds: 30,
    );

void main() {
  group('flowchart, kasus tulisan tangan', () {
    final branch = [
      ['1', 'x := 7', '2'],
      ['2', 'x > 5 ?', 'Ya: 3, Tidak: 4'],
      ['3', 'y := x * 2', '5'],
      ['4', 'y := x + 1', '5'],
      ['5', 'TAMPILKAN y', 'SELESAI'],
    ];

    test('cabang Ya', () {
      // 7 > 5 benar: ke kotak 3, y = 14. Jalur 1, 2, 3, 5.
      final q = flw(branch, FlwShown.text, ['14', '8', '7', '15']);
      expect(ItFlwSolver.answerOf(q), '14');
      expect(naiveFlwAnswer(q), '14');
      final path = flw(branch, FlwPath.text, ['1, 2, 3, 5', '1, 2, 4, 5']);
      expect(const ItFlwSolver().validOptions(path), [0]);
    });

    test('jalur cabang lain menjadi pengecoh', () {
      final chart =
          Flowchart.fromTable(TableFigure(headers: flwHeaders, rows: branch))!;
      // Keputusan pertama dibalik: ke kotak 4, y = 8.
      expect(chart.run(flipAt: 0).output, [8]);
      expect(chart.run(flipAt: 0).path, [1, 2, 4, 5]);
    });

    test('perulangan dengan penghitung', () {
      // i = 1..4 dengan i <= 4: s = 1 + 2 + 3 + 4 = 10. Kotak 4 dijalankan
      // empat kali; kotak 3 diperiksa lima kali (i = 1..5).
      final rows = [
        ['1', 's := 0', '2'],
        ['2', 'i := 1', '3'],
        ['3', 'i <= 4 ?', 'Ya: 4, Tidak: 6'],
        ['4', 's := s + i', '5'],
        ['5', 'i := i + 1', '3'],
        ['6', 'TAMPILKAN s', 'SELESAI'],
      ];
      expect(ItFlwSolver.answerOf(flw(rows, FlwShown.text, ['10', '6'])), '10');
      expect(
          ItFlwSolver.answerOf(
              flw(rows, 'Berapa kali kotak 4 dijalankan?', ['4', '5'])),
          '4');
      expect(
          naiveFlwAnswer(
              flw(rows, 'Berapa kali kotak 3 dijalankan?', ['4', '5'])),
          '5');
      expect(
          Flowchart.fromTable(TableFigure(headers: flwHeaders, rows: rows))!
              .hasLoop,
          isTrue);
    });

    test('kondisi DAN dan MOD', () {
      // n = 12: 12 MOD 3 = 0 dan 12 > 10, jadi Ya; tampil 12 DIV 3 = 4.
      final rows = [
        ['1', 'n := 12', '2'],
        ['2', 'n MOD 3 = 0 DAN n > 10 ?', 'Ya: 3, Tidak: 4'],
        ['3', 'TAMPILKAN n DIV 3', 'SELESAI'],
        ['4', 'TAMPILKAN n', 'SELESAI'],
      ];
      expect(ItFlwSolver.answerOf(flw(rows, FlwShown.text, ['4', '12'])), '4');
      expect(naiveFlwAnswer(flw(rows, FlwShown.text, ['4', '12'])), '4');
    });

    test('flowchart tak berhenti, rujukan salah, dan tabel rusak', () {
      final loop = [
        ['1', 'x := 0', '2'],
        ['2', 'x = 0 ?', 'Ya: 2, Tidak: SELESAI'],
      ];
      expect(
          ItFlwSolver.answerOf(flw(loop, FlwShown.text, ['0', '1'])), isNull);
      final dangling = [
        ['1', 'x := 0', '9'],
        ['2', 'TAMPILKAN x', 'SELESAI'],
      ];
      expect(
          Flowchart.fromTable(TableFigure(headers: flwHeaders, rows: dangling)),
          isNull);
      final bad = [
        ['1', 'x = 0', '2'],
        ['2', 'TAMPILKAN x', 'SELESAI'],
      ];
      expect(Flowchart.fromTable(TableFigure(headers: flwHeaders, rows: bad)),
          isNull);
    });
  });

  group('solver kedua independen', () {
    test('sama dengan solver utama pada 3000 soal per kesulitan', () {
      const g = ItFlwGenerator();
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 3000; seed++) {
          final q = g.generate(seed, d);
          final naive = naiveFlwAnswer(q);
          expect(naive, isNotNull, reason: 'seed $seed');
          expect(naive, ItFlwSolver.answerOf(q),
              reason: 'seed $seed ${d.code}');
          expect(q.options[q.correctIndex].content.text, naive);
          // Tidak ada pengecoh yang benar menurut solver kedua.
          expect(
            [for (final o in q.options) o.content.text]
                .where((t) => t == naive),
            hasLength(1),
          );
        }
      }
    });
  });

  group('generator', () {
    test('semua templat dan bentuk pertanyaan muncul', () {
      const g = ItFlwGenerator();
      final templates = <String>{};
      final kinds = <Type>{};
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 300; seed++) {
          final q = g.generate(seed, d);
          templates.add(q.tags.single);
          kinds.add(
              FlwQuestion.parse(q.stem.text!.split('\n').last)!.runtimeType);
        }
      }
      expect(templates, hasLength(6));
      expect(kinds, {FlwShown, FlwPath, FlwVisits});
    });
  });

  PropertyHarness(
    const ItFlwGenerator(),
    const ItFlwSolver(),
    bounds: itFlwBounds,
  ).register();
}
