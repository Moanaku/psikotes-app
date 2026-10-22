import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = NumAriGenerator();
const _solver = NumAriSolver();

List<String> numAriBounds(Question q) {
  final issues = <String>[];
  final text = q.stem.text ?? '';
  if (q.options.length != NumAriGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  if (q.tags.length != 1 || !q.tags.single.startsWith('rule:num-ari:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  if (text.startsWith(calcPrefix)) {
    final expr = parseExpr(text.substring(calcPrefix.length));
    if (expr == null) return [...issues, 'ekspresi tidak terurai: $text'];
    // Teks harus tercetak ulang persis dari pohon yang terurai.
    if (expr.text != text.substring(calcPrefix.length)) {
      issues.add('teks tidak kanonik: ${expr.text}');
    }
    final value = expr.value;
    if (value.toDecimal() == null) issues.add('hasil lebih dari 2 desimal');
    if (value > Fraction(100000) || value.isNegative || value.isZero) {
      issues.add('hasil di luar wajar: $value');
    }
    for (final o in q.options) {
      final v = parseDisplayNumber(o.content.text ?? '');
      if (v == null) issues.add('opsi bukan bilangan: ${o.content.text}');
    }
    final maxOps = switch (q.difficulty) {
      Difficulty.easy => 2,
      Difficulty.medium => 4,
      Difficulty.hard => 5,
    };
    final ops = RegExp(r'[+−×÷]').allMatches(text).length;
    if (ops < 1 || ops > maxOps) issues.add('$ops operator di luar 1..$maxOps');
    if (q.tags.single == 'rule:num-ari:percent' && !text.contains('%')) {
      issues.add('soal persen tanpa tanda %');
    }
  } else if (text == compareMaxText || text == compareMinText) {
    for (final o in q.options) {
      if (parseExpr(o.content.text ?? '') == null) {
        issues.add('opsi tidak terurai: ${o.content.text}');
      }
    }
    if (q.tags.single != 'rule:num-ari:compare') issues.add('tag compare');
  } else {
    issues.add('teks soal tidak dikenal: $text');
  }
  if (q.difficulty == Difficulty.easy && q.tags.single != 'rule:num-ari:expr') {
    issues.add('easy hanya ekspresi biasa');
  }
  return issues;
}

Question _calc(String expr, List<String> options) => Question(
      type: QuestionType.numAri,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(text: '$calcPrefix$expr'),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i), content: QuestionContent(text: options[i])),
      ],
      correctIndex: 0,
      explanation: 'uji',
      estimatedSeconds: 10,
    );

Question _compare(String stem, List<String> options) => Question(
      type: QuestionType.numAri,
      seed: 1,
      difficulty: Difficulty.medium,
      stem: QuestionContent(text: stem),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i), content: QuestionContent(text: options[i])),
      ],
      correctIndex: 0,
      explanation: 'uji',
      estimatedSeconds: 10,
    );

String _v(String s) => parseExpr(s)!.value.toString();

void main() {
  PropertyHarness(_generator, _solver, bounds: numAriBounds).register();

  group('parser dan nilai eksak', () {
    test('urutan operasi', () {
      expect(_v('12 + 8 × 3 − 4'), '32');
      expect(_v('(12 + 8) × 3 − 4'), '56');
      expect(_v('100 − 20 − 30'), '50');
      expect(_v('100 − (20 − 30)'), '110');
      expect(_v('64 ÷ 8 ÷ 2'), '4');
      expect(_v('64 ÷ (8 ÷ 2)'), '16');
    });

    test('desimal koma dan persen eksak', () {
      expect(_v('0,1 + 0,2'), '3/10');
      expect(_v('25% × 240'), '60');
      expect(_v('180 + 80% × 180'), '324');
      expect(_v('200 × (100% + 20%) × (100% − 10%)'), '216');
      expect(_v('2,5 × 4'), '10');
    });

    test('pecahan literal', () {
      expect(_v('3/4'), '3/4');
      expect(_v('125%'), '5/4');
      expect(_v('1,25'), '5/4');
    });

    test('bentuk tidak sah ditolak', () {
      for (final bad in [
        '',
        '12 +',
        '(1 + 2',
        '1 + 2)',
        'a + 1',
        '1,,5',
        '3/0'
      ]) {
        expect(parseExpr(bad), isNull, reason: bad);
      }
    });

    test('pembagian nol saat dihitung', () {
      expect(() => parseExpr('5 ÷ (3 − 3)')!.value, throwsArgumentError);
    });
  });

  group('pencetak teks', () {
    test('kurung ditambah hanya bila perlu', () {
      NumLit n(int v) => NumLit(Fraction(v));
      expect(
          BinExpr(Op.add, n(1), BinExpr(Op.mul, n(2), n(3))).text, '1 + 2 × 3');
      expect(BinExpr(Op.mul, BinExpr(Op.add, n(1), n(2)), n(3)).text,
          '(1 + 2) × 3');
      expect(BinExpr(Op.sub, n(9), BinExpr(Op.sub, n(5), n(2))).text,
          '9 − (5 − 2)');
      expect(
          BinExpr(Op.sub, BinExpr(Op.sub, n(9), n(5)), n(2)).text, '9 − 5 − 2');
      expect(BinExpr(Op.div, n(8), BinExpr(Op.mul, n(2), n(2))).text,
          '8 ÷ (2 × 2)');
    });

    test('cetak lalu urai memberi nilai yang sama', () {
      for (var seed = 0; seed < 500; seed++) {
        for (final d in Difficulty.values) {
          final q = _generator.generate(seed, d);
          final text = q.stem.text!;
          if (!text.startsWith(calcPrefix)) continue;
          final expr = parseExpr(text.substring(calcPrefix.length))!;
          expect(parseExpr(expr.text)!.value.equals(expr.value), isTrue);
        }
      }
    });
  });

  group('kesalahan umum', () {
    test('kiri ke kanan tanpa urutan operasi', () {
      expect(leftToRightValue('12 + 8 × 3 − 4')!.toString(), '56');
      expect(leftToRightValue('(12 + 8) × 3 − 4')!.toString(), '56');
      expect(leftToRightValue('2 + 3 × 4')!.toString(), '20');
      expect(leftToRightValue('abc'), isNull);
    });

    test('langkah hitung mengikuti urutan operasi', () {
      final steps = workSteps(parseExpr('12 + 8 × 3 − 4')!);
      expect(steps, ['8 × 3 = 24', '12 + 24 = 36', '36 − 4 = 32']);
      final percent = workSteps(parseExpr('180 + 80% × 180')!);
      expect(percent.first, '80% = 0,8');
      expect(percent.last, '180 + 144 = 324');
    });
  });

  group('solver', () {
    test('hitung: nilai eksak, bukan pembulatan', () {
      final q = _calc('0,1 + 0,2', ['0,3', '0,30000000000000004', '3']);
      expect(_solver.validOptions(q), [0]);
    });

    test('hitung: titik ribuan', () {
      expect(_solver.validOptions(_calc('250 × 4 × 10', ['10.000', '1.000'])),
          [0]);
    });

    test('hitung: urutan operasi memisahkan jawaban', () {
      final q = _calc('12 + 8 × 3 − 4', ['32', '56', '44']);
      expect(_solver.validOptions(q), [0]);
    });

    test('bandingkan: terbesar dan terkecil, campuran bentuk', () {
      final options = ['3/4', '0,7', '72%', '0,05', '7/10'];
      expect(_solver.validOptions(_compare(compareMaxText, options)), [0]);
      expect(_solver.validOptions(_compare(compareMinText, options)), [3]);
    });

    test('bandingkan: nilai sama menghasilkan dua opsi valid', () {
      final options = ['3/4', '75%', '0,5'];
      expect(_solver.validOptions(_compare(compareMaxText, options)), [0, 1]);
    });

    test('bentuk tak dikenal tidak punya opsi valid', () {
      expect(_solver.validOptions(_calc('1 +', ['1'])), isEmpty);
      expect(_solver.validOptions(_calc('5 ÷ 0', ['1'])), isEmpty);
      expect(_solver.validOptions(_compare('Pilih.', ['1'])), isEmpty);
    });
  });

  group('keluaran generator', () {
    test('tiga bentuk soal muncul', () {
      final tags = <String>{};
      for (var s = 0; s < 300; s++) {
        for (final d in Difficulty.values) {
          tags.addAll(_generator.generate(s, d).tags);
        }
      }
      expect(tags, {
        'rule:num-ari:expr',
        'rule:num-ari:percent',
        'rule:num-ari:compare',
      });
    });

    test('pembahasan menyebut salah urutan operasi bila itu pengecoh', () {
      var mentioned = 0;
      for (var s = 0; s < 400; s++) {
        final q = _generator.generate(s, Difficulty.medium);
        if (q.explanation.contains('tanpa urutan operasi')) mentioned++;
      }
      expect(mentioned, greaterThan(0));
    });
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:num-ari:expr']);
      expect(q.correctIndex, 3);
      expect(q.stem.text, 'Hitung: 13 + 14,8 × 7,5');
      expect(
          q.explanation,
          'Urutan operasi: hitung kurung lebih dulu, lalu × dan ÷ dari '
          'kiri, baru + dan −. 14,8 × 7,5 = 111; 13 + 111 = 124. Jadi '
          'hasilnya 124. Mengerjakan dari kiri ke kanan tanpa urutan '
          'operasi memberi 208,5, itu salah.');
    });
  });
}
