import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

/// Program dari teks berindentasi; tiap baris di [code] satu baris kode.
PseudoRun run(String code) => psRunProgram(psParseProgram(code.split('\n')));

List<String> itPseBounds(Question q) {
  final issues = <String>[];
  final stem = PseStem.parse(q.stem.text);
  if (stem == null) return ['stem tidak terurai'];
  final lines = psRenderProgram(stem.program);
  if (lines.length > ItPseGenerator.maxCodeLines) {
    issues.add('kode ${lines.length} baris');
  }
  // Kode tercetak ulang persis dari hasil uraiannya.
  if (PseStem.compose(stem.program, stem.question) != q.stem.text) {
    issues.add('stem tidak kanonik');
  }
  final r = psRunProgram(stem.program);
  if (r.steps > ItPseGenerator.maxSteps) issues.add('${r.steps} langkah');
  if (q.options.length != ItPseGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  for (final o in q.options) {
    final v = int.tryParse(o.content.text ?? '');
    if (v == null) issues.add('opsi bukan bilangan bulat: ${o.content.text}');
    if (v != null && v.abs() > 100000) issues.add('opsi terlalu besar: $v');
  }
  if (!q.tags.single.startsWith('rule:it-pse:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  return issues;
}

void main() {
  // Kasus tulisan tangan: hasil di komentar dihitung manual, bukan dari
  // interpreter. Ini bukti kebenaran interpreter di luar property test.
  group('interpreter, kasus tulisan tangan', () {
    test('1. penugasan berurutan', () {
      // a = 5; b = 5 * 2 + 1 = 11.
      final r = run('a := 5\nb := a * 2 + 1\nTAMPILKAN b');
      expect(r.output, [11]);
      expect(r.variables, {'a': 5, 'b': 11});
    });

    test('2. kali lebih dulu dari tambah, kurung mengubah urutan', () {
      // 2 + 3 * 4 = 2 + 12 = 14; (2 + 3) * 4 = 5 * 4 = 20.
      final r = run('x := 2 + 3 * 4\ny := (2 + 3) * 4');
      expect(r.variables, {'x': 14, 'y': 20});
    });

    test('3. operator setara dihitung dari kiri', () {
      // 10 - 4 - 3 = 6 - 3 = 3 (bukan 10 - 1 = 9);
      // 7 * 3 DIV 4 = 21 DIV 4 = 5 (bukan 7 * 0 = 0).
      final r = run('x := 10 - 4 - 3\ny := 7 * 3 DIV 4');
      expect(r.variables, {'x': 3, 'y': 5});
    });

    test('4. DIV dan MOD', () {
      // 47 = 9 * 5 + 2, jadi 47 DIV 5 = 9 dan 47 MOD 5 = 2; 0 MOD 3 = 0.
      final r = run('q := 47 DIV 5\nr := 47 MOD 5\nz := 0 MOD 3');
      expect(r.variables, {'q': 9, 'r': 2, 'z': 0});
    });

    test('5. minus di depan bilangan', () {
      // -3 + 5 = 2; 4 - (-2) = 6.
      final r = run('x := -3 + 5\ny := 4 - -2');
      expect(r.variables, {'x': 2, 'y': 6});
    });

    test('6. JIKA benar menjalankan MAKA, salah menjalankan LAINNYA', () {
      // a = 7 > 3, jadi c = 1. Lalu 7 < 3 salah, jadi d = 2.
      final r = run('a := 7\n'
          'JIKA a > 3 MAKA\n  c := 1\nLAINNYA\n  c := 0\n'
          'JIKA a < 3 MAKA\n  d := 1\nLAINNYA\n  d := 2');
      expect(r.variables, {'a': 7, 'c': 1, 'd': 2});
    });

    test('7. JIKA salah tanpa LAINNYA tidak mengubah apa pun', () {
      // 4 = 5 salah: s tetap 9.
      final r = run('s := 9\nJIKA 4 = 5 MAKA\n  s := 0\nTAMPILKAN s');
      expect(r.output, [9]);
    });

    test('8. ULANGI termasuk batas akhir', () {
      // 1 + 2 + 3 + 4 + 5 = 15; i terakhir 5.
      final r = run('s := 0\nULANGI i DARI 1 SAMPAI 5\n  s := s + i');
      expect(r.variables, {'s': 15, 'i': 5});
      expect(r.executions['s := s + i'], 5);
    });

    test('9. ULANGI dengan awal lebih besar dari akhir tidak berputar', () {
      // DARI 5 SAMPAI 4: nol putaran; s tetap 0, i tidak pernah diisi.
      final r = run('s := 0\nULANGI i DARI 5 SAMPAI 4\n  s := s + 1');
      expect(r.variables, {'s': 0});
      expect(r.executions['s := s + 1'], isNull);
    });

    test('10. ULANGI dengan awal sama dengan akhir berputar sekali', () {
      // i = 3 saja: s = 0 + 3 * 2 = 6.
      final r = run('s := 0\nULANGI i DARI 3 SAMPAI 3\n  s := s + i * 2');
      expect(r.variables['s'], 6);
    });

    test('11. batas ULANGI dihitung sekali di awal', () {
      // n = 3 saat masuk loop: tiga putaran walau n naik menjadi 6.
      final r = run('n := 3\nc := 0\nULANGI i DARI 1 SAMPAI n\n'
          '  n := n + 1\n  c := c + 1');
      expect(r.variables, {'n': 6, 'c': 3, 'i': 3});
    });

    test('12. SELAMA dengan > berhenti setelah melewati batas', () {
      // x: 10 -> 7 -> 4 -> 1 -> -2. Kondisi diperiksa di 10, 7, 4, 1, -2:
      // lima kali, empat putaran.
      final r = run('x := 10\nc := 0\nSELAMA x > 0 LAKUKAN\n'
          '  x := x - 3\n  c := c + 1');
      expect(r.variables, {'x': -2, 'c': 4});
      expect(r.executions['SELAMA x > 0 LAKUKAN'], 5);
    });

    test('13. SELAMA dengan >= ikut memproses batasnya (off-by-one)', () {
      // x: 9 -> 6 -> 3 -> 0. 3 >= 3 masih benar, jadi tiga putaran.
      final r = run('x := 9\nc := 0\nSELAMA x >= 3 LAKUKAN\n'
          '  x := x - 3\n  c := c + 1');
      expect(r.variables, {'x': 0, 'c': 3});
    });

    test('14. SELAMA yang kondisinya salah sejak awal', () {
      // 0 > 5 salah: badan tidak pernah jalan, kepala diperiksa sekali.
      final r = run('x := 0\nSELAMA x > 5 LAKUKAN\n  x := x - 1');
      expect(r.variables, {'x': 0});
      expect(r.executions['SELAMA x > 5 LAKUKAN'], 1);
      expect(r.executions['x := x - 1'], isNull);
    });

    test('15. ULANGI bersarang segitiga', () {
      // i = 1: j 1..1 (1); i = 2: j 1..2 (2); i = 3: j 1..3 (3). Total 6.
      final r = run('c := 0\nULANGI i DARI 1 SAMPAI 3\n'
          '  ULANGI j DARI 1 SAMPAI i\n    c := c + 1');
      expect(r.variables['c'], 6);
      expect(r.executions['c := c + 1'], 6);
      // Kepala ULANGI dalam dihitung sekali per masuk loop: tiga kali.
      expect(r.executions['ULANGI j DARI 1 SAMPAI i'], 3);
    });

    test('16. ULANGI bersarang dengan JIKA', () {
      // Pasangan (i, j) di 1..3 x 1..3 dengan i < j: (1,2), (1,3), (2,3) = 3.
      // Pasangan dengan i = j: (1,1), (2,2), (3,3) = 3.
      final r = run('a := 0\nb := 0\nULANGI i DARI 1 SAMPAI 3\n'
          '  ULANGI j DARI 1 SAMPAI 3\n'
          '    JIKA i < j MAKA\n      a := a + 1\n'
          '    JIKA i = j MAKA\n      b := b + 1');
      expect(r.variables['a'], 3);
      expect(r.variables['b'], 3);
      expect(r.executions['JIKA i < j MAKA'], 9);
    });

    test('17. DAN mengikat lebih kuat dari ATAU', () {
      // 1 = 1 ATAU (1 = 2 DAN 2 = 3) = benar ATAU salah = benar.
      // Dibaca kiri ke kanan ((benar ATAU salah) DAN salah) akan salah.
      final r = run('JIKA 1 = 1 ATAU 1 = 2 DAN 2 = 3 MAKA\n  x := 1\n'
          'LAINNYA\n  x := 0');
      expect(r.variables['x'], 1);
    });

    test('18. jumlah digit dan membalik bilangan', () {
      // 4729: s = 9, 9 + 2 = 11, 11 + 7 = 18, 18 + 4 = 22.
      final s = run('n := 4729\ns := 0\nSELAMA n > 0 LAKUKAN\n'
          '  s := s + n MOD 10\n  n := n DIV 10');
      expect(s.variables, {'n': 0, 's': 22});
      // Balik: r = 9, 92, 927, 9274.
      final r = run('n := 4729\nr := 0\nSELAMA n > 0 LAKUKAN\n'
          '  r := r * 10 + n MOD 10\n  n := n DIV 10');
      expect(r.variables['r'], 9274);
    });

    test('19. pangkat tiga sampai melewati batas', () {
      // p: 1 -> 3 -> 9 -> 27 -> 81; 81 < 50 salah. k = 4.
      final r = run('p := 1\nk := 0\nSELAMA p < 50 LAKUKAN\n'
          '  p := p * 3\n  k := k + 1');
      expect(r.variables, {'p': 81, 'k': 4});
    });

    test('20. Fibonacci enam putaran', () {
      // (a, b): (0,1) -> (1,1) -> (1,2) -> (2,3) -> (3,5) -> (5,8) -> (8,13).
      final r = run('a := 0\nb := 1\nULANGI i DARI 1 SAMPAI 6\n'
          '  t := a + b\n  a := b\n  b := t');
      expect(r.variables['a'], 8);
      expect(r.variables['b'], 13);
    });

    test('21. Collatz 6 dengan JIKA dan LAINNYA di dalam SELAMA', () {
      // 6 -> 3 -> 10 -> 5 -> 16 -> 8 -> 4 -> 2 -> 1: delapan langkah.
      final r = run('n := 6\nc := 0\nSELAMA n != 1 LAKUKAN\n'
          '  JIKA n MOD 2 = 0 MAKA\n    n := n DIV 2\n'
          '  LAINNYA\n    n := n * 3 + 1\n  c := c + 1\nTAMPILKAN c');
      expect(r.output, [8]);
      // Genap: 6, 10, 16, 8, 4, 2 = enam; ganjil: 3, 5 = dua.
      expect(r.executions['n := n DIV 2'], 6);
      expect(r.executions['n := n * 3 + 1'], 2);
    });

    test('22. TAMPILKAN di dalam loop mencatat semua nilai berurutan', () {
      // i = 1..4, tampilkan i * i: 1, 4, 9, 16.
      final r = run('ULANGI i DARI 1 SAMPAI 4\n  TAMPILKAN i * i');
      expect(r.output, [1, 4, 9, 16]);
    });
  });

  group('interpreter, kasus galat', () {
    test('loop tak hingga berhenti di batas langkah', () {
      expect(() => run('x := 0\nSELAMA 1 = 1 LAKUKAN\n  x := x + 1'),
          throwsA(isA<StepLimitExceeded>()));
      // Batas juga berlaku pada ULANGI yang sangat panjang.
      expect(() => run('s := 0\nULANGI i DARI 1 SAMPAI 999999\n  s := 0'),
          throwsA(isA<StepLimitExceeded>()));
    });

    test('variabel belum diisi, bagi nol, MOD negatif, nilai terlalu besar',
        () {
      expect(() => run('x := y + 1'), throwsA(isA<PseudoError>()));
      expect(() => run('x := 5 DIV 0'), throwsA(isA<PseudoError>()));
      expect(() => run('x := -5 MOD 3'), throwsA(isA<PseudoError>()));
      expect(
        () => run('x := 1000\nx := x * x\nx := x * x'),
        throwsA(isA<PseudoError>()),
      );
    });

    test('kode salah bentuk ditolak pengurai', () {
      for (final bad in [
        'JIKA x > 1\n  y := 1', // tanpa MAKA
        'JIKA 1 = 1 MAKA', // blok kosong
        'x := 1\n   y := 2', // indentasi ganjil
        'x := 1\n  y := 2', // indentasi tanpa blok
        'x = 1', // bukan penugasan
        'TAMPILKAN 1 +', // ekspresi terpotong
        'JIKA := 3', // kata kunci sebagai nama
        'SELAMA x LAKUKAN\n  x := 0', // bukan perbandingan
      ]) {
        expect(
            () => psParseProgram(bad.split('\n')), throwsA(isA<PseudoError>()),
            reason: bad);
      }
    });

    test('render lalu urai menghasilkan kode yang sama', () {
      const code = [
        's := 0',
        'ULANGI i DARI 1 SAMPAI 3',
        '  JIKA i MOD 2 = 0 ATAU i > 2 MAKA',
        '    s := s + (i - 1) * 2',
        '  LAINNYA',
        '    s := s - (2 - i)',
        'TAMPILKAN s',
      ];
      expect(psRenderProgram(psParseProgram(code)), code);
      // a - (b - c) tetap berkurung; (a - b) - c tidak.
      expect(psParseExpr('a - (b - c)').render(), 'a - (b - c)');
      expect(psParseExpr('(a - b) - c').render(), 'a - b - c');
    });
  });

  group('solver dan pengecoh', () {
    Question question(String code, String ask, List<String> options) =>
        Question(
          type: QuestionType.itPse,
          seed: 1,
          difficulty: Difficulty.easy,
          stem: QuestionContent(text: '$pseIntro\n\n$code\n\n$ask'),
          options: [
            for (var i = 0; i < options.length; i++)
              Option(
                  id: Option.idFor(i),
                  content: QuestionContent(text: options[i])),
          ],
          correctIndex: 0,
          explanation: 'x',
          estimatedSeconds: 30,
        );

    test('solver menjalankan kode dari stem, bukan correctIndex', () {
      const code =
          's := 0\nULANGI i DARI 1 SAMPAI 4\n  s := s + i\nTAMPILKAN s';
      // 1 + 2 + 3 + 4 = 10.
      expect(
        const ItPseSolver().validOptions(question(
            code, 'Berapa nilai yang ditampilkan?', ['6', '10', '15', '9'])),
        [1],
      );
      // Baris s := s + i dijalankan empat kali.
      expect(
        const ItPseSolver().validOptions(question(
            code,
            'Berapa kali baris "s := s + i" dijalankan?',
            ['3', '5', '4', '0'])),
        [2],
      );
      expect(
        const ItPseSolver().validOptions(question(code,
            'Berapa nilai s setelah program selesai?', ['10', '1', '2', '3'])),
        [0],
      );
    });

    test('stem rusak atau loop tak hingga: tidak ada opsi valid', () {
      expect(
        const ItPseSolver().validOptions(question(
            'x := 0\nSELAMA x = 0 LAKUKAN\n  x := 0\nTAMPILKAN x',
            'Berapa nilai yang ditampilkan?',
            ['0', '1'])),
        isEmpty,
      );
      expect(
        const ItPseSolver().validOptions(
            question('x := (1', 'Berapa nilai yang ditampilkan?', ['0', '1'])),
        isEmpty,
      );
    });

    test('pengecoh memuat off-by-one batas loop', () {
      final program = psParseProgram(
          's := 0\nULANGI i DARI 1 SAMPAI 4\n  s := s + i'.split('\n'));
      final finals = {
        for (final m in pseMutants(program)) psRunProgram(m).variables['s'],
      };
      // SAMPAI 5: 15; SAMPAI 3: 6; DARI 2: 9; DARI 0: 10 (sama dengan kunci).
      expect(finals, containsAll([15, 6, 9]));
    });
  });

  group('generator', () {
    test('deterministik dan semua templat muncul', () {
      const g = ItPseGenerator();
      final templates = <String>{};
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 300; seed++) {
          final q = g.generate(seed, d);
          expect(canonicalJson(g.generate(seed, d)), canonicalJson(q));
          templates.add(q.tags.single);
          expect(itPseBounds(q), isEmpty, reason: q.stem.text);
        }
      }
      expect(templates, hasLength(9));
    });

    test('ketiga bentuk pertanyaan muncul', () {
      const g = ItPseGenerator();
      final kinds = <Type>{};
      for (var seed = 0; seed < 300; seed++) {
        final q = g.generate(seed, Difficulty.medium);
        kinds.add(PseStem.parse(q.stem.text)!.question.runtimeType);
      }
      expect(kinds, {PseShown, PseFinal, PseCount});
    });
  });

  PropertyHarness(
    const ItPseGenerator(),
    const ItPseSolver(),
    bounds: itPseBounds,
  ).register();
}
