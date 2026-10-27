import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/naive_xls.dart';
import 'support/property_harness.dart';

List<String> itXlsBounds(Question q) {
  final issues = <String>[];
  final sheet = Sheet.fromTable(q.stem.figure);
  if (sheet == null) return ['tabel bukan lembar kerja'];
  final lines = (q.stem.text ?? '').split('\n');
  if (lines.length != 3) return ['stem bukan tiga baris'];
  final formula = parseFormula(lines[1]);
  if (renderFormula(formula) != lines[1]) issues.add('rumus tidak kanonik');
  // Rumus hanya merujuk baris data yang ada.
  for (final m in RegExp(r'[A-C](\d+)').allMatches(lines[1])) {
    final row = int.parse(m.group(1)!);
    if (row < 2 || row > sheet.rowCount) issues.add('rujukan baris $row');
  }
  final value = evalFormula(formula, sheet);
  if (value is XlsError || value is XlsBool) issues.add('hasil $value');
  if (q.options.length != ItXlsGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  if (!q.tags.single.startsWith('rule:it-xls:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  return issues;
}

/// Data acuan untuk kasus tulisan tangan.
final Sheet sample = Sheet({
  'A1': 'Nama', 'B1': 'Nilai', 'C1': 'Status', //
  'A2': 'Ani', 'B2': '80', 'C2': 'Lulus',
  'A3': 'Budi', 'B3': '65', 'C3': 'Remedial',
  'A4': 'Citra', 'B4': '72,5', 'C4': 'Lulus',
  'A5': 'Dewi', 'B5': '90', 'C5': 'lulus',
});

String calc(String formula) =>
    evalFormula(parseFormula(formula), sample).display();

Question xls(String formula, List<String> options) => Question(
      type: QuestionType.itXls,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(
        text: '$xlsIntro\n$formula\n$xlsQuestion',
        figure: sample.toTable(),
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
  group('rumus, kasus tulisan tangan', () {
    test('SUM melewati teks dan menghitung desimal eksak', () {
      // 80 + 65 + 72,5 + 90 = 307,5; B1 "Nilai" dilewati.
      expect(calc('=SUM(B1:B5)'), '307,5');
      // 65 + 72,5 = 137,5.
      expect(calc('=SUM(B3:B4)'), '137,5');
    });

    test('rata-rata eksak tanpa galat desimal', () {
      // 307,5 / 4 = 76,875 -> tiga desimal, ditulis sebagai pecahan 615/8.
      expect(calc('=SUM(B2:B5)/4'), '615/8');
      // (80 + 65) / 2 = 72,5.
      expect(calc('=SUM(B2:B3)/2'), '72,5');
    });

    test('COUNTIF angka: batas > lawan >=', () {
      // >= 80: 80 dan 90 = 2; > 80: hanya 90 = 1; < 72,5: 65 = 1.
      expect(calc('=COUNTIF(B2:B5; ">=80")'), '2');
      expect(calc('=COUNTIF(B2:B5; ">80")'), '1');
      expect(calc('=COUNTIF(B2:B5; "<72,5")'), '1');
      expect(calc('=COUNTIF(B2:B5; 65)'), '1');
    });

    test('COUNTIF teks tidak membedakan huruf besar', () {
      // "Lulus", "Lulus", "lulus" = 3; "<>Lulus" = Remedial saja = 1.
      expect(calc('=COUNTIF(C2:C5; "Lulus")'), '3');
      expect(calc('=COUNTIF(C2:C5; "<>Lulus")'), '1');
    });

    test('IF memilih cabang dari kondisi', () {
      // B3 = 65 >= 70 salah: 65 - 5 = 60. B2 = 80: 80 + 5 = 85.
      expect(calc('=IF(B3>=70; B3+5; B3-5)'), '60');
      expect(calc('=IF(B2>=70; B2+5; B2-5)'), '85');
      expect(calc('=IF(B2>=70; "Lulus"; "Remedial")'), 'Lulus');
    });

    test('VLOOKUP pencocokan tepat', () {
      // Baris Citra, kolom 2 = 72,5; kolom 3 = Lulus. Kunci "citra" juga cocok.
      expect(calc('=VLOOKUP("Citra"; A2:C5; 2; FALSE)'), '72,5');
      expect(calc('=VLOOKUP("citra"; A2:C5; 3; FALSE)'), 'Lulus');
      expect(calc('=VLOOKUP("Eka"; A2:C5; 2; FALSE)'), '#N/A');
      expect(calc('=VLOOKUP("Ani"; A2:C5; 4; FALSE)'), '#REF!');
    });

    test('prioritas operator dan kurung', () {
      // 80 + 65 * 2 = 210; (80 + 65) * 2 = 290; 90 - 80 - 5 = 5.
      expect(calc('=B2+B3*2'), '210');
      expect(calc('=(B2+B3)*2'), '290');
      expect(calc('=B5-B2-5'), '5');
    });

    test('IF bertingkat dengan VLOOKUP', () {
      // Budi = 65: tidak >= 80, tetapi >= 60, jadi Cukup.
      expect(
        calc('=IF(VLOOKUP("Budi"; A2:C5; 2; FALSE)>=80; "Baik"; '
            'IF(VLOOKUP("Budi"; A2:C5; 2; FALSE)>=60; "Cukup"; "Kurang"))'),
        'Cukup',
      );
    });

    test('galat: bagi nol, teks dalam aritmetika, rentang terbalik', () {
      expect(calc('=B2/0'), '#DIV/0!');
      expect(calc('=A2+1'), '#VALUE!');
      expect(calc('=SUM(B5:B2)'), '#REF!');
      // Sel kosong bernilai 0.
      expect(calc('=B9+1'), '1');
    });

    test('rumus salah bentuk ditolak pengurai', () {
      for (final bad in [
        'SUM(B2:B3)',
        '=SUM(B2:B3',
        '=FOO(1)',
        '=B2:',
        '=1 2'
      ]) {
        expect(() => parseFormula(bad), throwsA(isA<XlsSyntaxError>()),
            reason: bad);
      }
    });

    test('solver kedua setuju pada kasus tulisan tangan', () {
      for (final f in [
        '=SUM(B1:B5)',
        '=SUM(B2:B3)/2',
        '=COUNTIF(B2:B5; ">=80")',
        '=COUNTIF(C2:C5; "Lulus")',
        '=IF(B3>=70; B3+5; B3-5)',
        '=VLOOKUP("Citra"; A2:C5; 2; FALSE)',
        '=B2+B3*2',
        '=B5-B2-5',
        '=VLOOKUP("Eka"; A2:C5; 2; FALSE)',
      ]) {
        final q = xls(f, ['0', '1']);
        expect(naiveXlsAnswer(q), ItXlsSolver.answerOf(q), reason: f);
      }
    });

    test('pengecoh memuat rentang sel yang salah', () {
      final values = {
        for (final m in xlsMutants(parseFormula('=SUM(B2:B4)')))
          evalFormula(m, sample).display(),
      };
      // B3:B4 = 137,5; B2:B3 = 145; B2:B5 = 307,5; C2:C4 = 0 (teks).
      expect(values, containsAll(['137,5', '145', '307,5']));
    });
  });

  group('solver kedua independen', () {
    test('sama dengan solver utama pada 3000 soal per kesulitan', () {
      const g = ItXlsGenerator();
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 3000; seed++) {
          final q = g.generate(seed, d);
          final naive = naiveXlsAnswer(q);
          expect(naive, ItXlsSolver.answerOf(q),
              reason: 'seed $seed ${d.code}');
          expect(q.options[q.correctIndex].content.text, naive);
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
    test('semua templat muncul', () {
      const g = ItXlsGenerator();
      final templates = <String>{};
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 300; seed++) {
          templates.add(g.generate(seed, d).tags.single);
        }
      }
      expect(templates, hasLength(10));
    });
  });

  PropertyHarness(
    const ItXlsGenerator(),
    const ItXlsSolver(),
    bounds: itXlsBounds,
  ).register();
}
