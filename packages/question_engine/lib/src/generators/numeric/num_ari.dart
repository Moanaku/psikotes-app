/// Generator NUM-ARI (hitungan cepat, persen, perbandingan),
/// docs/06-bank-konten.md, "Spesifikasi ringkas tipe lain".
///
/// Tiga bentuk soal:
///  - `expr`: "Hitung: 12 + 8 × 3 − 4" dengan urutan operasi;
///  - `percent`: ekspresi dengan persen ("25% × 240", "harga naik lalu turun");
///  - `compare`: pilih nilai terbesar atau terkecil dari pecahan, desimal, dan
///    persen.
///
/// Semua hitungan memakai [Fraction] (eksak). Solver mengurai teks soal dan
/// opsi, menghitung ulang, dan membandingkan nilai eksak.
library;

import '../../fraction.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'arith_expr.dart';

const String calcPrefix = 'Hitung: ';
const String compareMaxText = 'Pilih nilai yang paling besar.';
const String compareMinText = 'Pilih nilai yang paling kecil.';

final class NumAriSolver implements QuestionSolver {
  const NumAriSolver();

  @override
  List<int> validOptions(Question question) {
    final text = question.stem.text ?? '';
    final optionTexts = [
      for (final o in question.options) o.content.text ?? ''
    ];
    try {
      if (text.startsWith(calcPrefix)) {
        final expr = parseExpr(text.substring(calcPrefix.length));
        if (expr == null) return const [];
        final value = expr.value;
        return [
          for (var i = 0; i < optionTexts.length; i++)
            if (parseDisplayNumber(optionTexts[i]) case final v?
                when v.equals(value))
              i,
        ];
      }
      if (text == compareMaxText || text == compareMinText) {
        final values = <Fraction>[];
        for (final t in optionTexts) {
          final e = parseExpr(t);
          if (e == null) return const [];
          values.add(e.value);
        }
        if (values.isEmpty) return const [];
        var best = values.first;
        for (final v in values) {
          if (text == compareMaxText ? v > best : v < best) best = v;
        }
        return [
          for (var i = 0; i < values.length; i++)
            if (values[i].equals(best)) i,
        ];
      }
    } on FractionOverflow {
      return const [];
    } on ArgumentError {
      return const [];
    }
    return const [];
  }
}

class NumAriGenerator extends RetryingGenerator {
  const NumAriGenerator();

  static const int optionCount = 5;

  /// Pengambilan ekspresi acak per percobaan sampai memenuhi syarat angka.
  static const int treeTries = 60;

  static const List<int> percentValues = [
    5, 10, 12, 15, 20, 25, 30, 40, 45, 50, 60, 75, 80, //
  ];

  @override
  QuestionType get type => QuestionType.numAri;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const NumAriSolver();

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final roll = rng.nextInt(10);
    final kind = switch (difficulty) {
      Difficulty.easy => 'expr',
      Difficulty.medium =>
        roll < 5 ? 'expr' : (roll < 8 ? 'percent' : 'compare'),
      Difficulty.hard => roll < 4 ? 'expr' : (roll < 7 ? 'percent' : 'compare'),
    };
    return kind == 'compare'
        ? _buildCompare(rng, seed, difficulty)
        : _buildCalc(rng, seed, difficulty, kind);
  }

  // Hitung.

  Question? _buildCalc(Rng rng, int seed, Difficulty difficulty, String kind) {
    Expr? tree;
    for (var t = 0; t < treeTries && tree == null; t++) {
      final candidate = kind == 'percent'
          ? _percentTree(rng, difficulty)
          : _plainTree(rng, difficulty);
      if (_acceptable(candidate)) tree = candidate;
    }
    if (tree == null) return null;
    final answer = tree.value;
    final answerText = answer.toDecimal();
    if (answerText == null) return null;

    final text = tree.text;
    // Teks harus terurai kembali menjadi nilai yang sama.
    final parsed = parseExpr(text);
    if (parsed == null || !parsed.value.equals(answer)) return null;

    final foils = _foils(rng, text, answer);
    if (foils.length < optionCount - 1) return null;
    final distractors = foils.take(optionCount - 1).toList();

    final assembled = assembleOptions(
      rng,
      QuestionContent(text: answerText),
      [for (final d in distractors) QuestionContent(text: d.$1)],
    );
    final ltr = leftToRightValue(text);
    final ltrShown = ltr != null &&
        distractors.any((d) => ltr.toDecimal() == d.$1) &&
        !ltr.equals(answer);
    final steps = workSteps(parsed);
    final explanation =
        'Urutan operasi: hitung kurung lebih dulu, lalu × dan ÷ '
        'dari kiri, baru + dan −. ${steps.join('; ')}. '
        'Jadi hasilnya $answerText.'
        '${ltrShown ? ' Mengerjakan dari kiri ke kanan tanpa urutan operasi '
            'memberi ${ltr.toDecimal()}, itu salah.' : ''}';
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(text: '$calcPrefix$text'),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: explanation,
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 25,
        Difficulty.medium => 40,
        Difficulty.hard => 60,
      },
      tags: ['rule:num-ari:$kind'],
    );
  }

  /// Setiap simpul bernilai tak negatif dengan paling banyak dua desimal;
  /// hasil akhir positif dan tidak melampaui 100.000.
  static bool _acceptable(Expr e) {
    try {
      bool walk(Expr x) {
        switch (x) {
          case BinExpr():
            if (!walk(x.left) || !walk(x.right)) return false;
            final v = x.value;
            // a - a dan a ÷ a tidak menarik.
            if ((x.op == Op.sub || x.op == Op.div) &&
                x.left.value.equals(x.right.value)) {
              return false;
            }
            return !v.isNegative && v.toDecimal() != null;
          case NumLit() || FractionLit() || ParenExpr():
            return true;
        }
      }

      if (!walk(e)) return false;
      final v = e.value;
      return !v.isZero && v <= Fraction(100000);
    } on FractionOverflow {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  static Expr _plainTree(Rng rng, Difficulty d) {
    final ops = switch (d) {
      Difficulty.easy => 1 + rng.nextInt(2),
      Difficulty.medium => 2 + rng.nextInt(2),
      Difficulty.hard => 3 + rng.nextInt(2),
    };
    Expr leaf() {
      final maxInt = switch (d) {
        Difficulty.easy => 12,
        Difficulty.medium => 30,
        Difficulty.hard => 40,
      };
      if (d != Difficulty.easy && rng.nextInt(10) < 3) {
        // Satu desimal, misalnya 2,5.
        return NumLit(Fraction(11 + rng.nextInt(maxInt * 10 - 10), 10));
      }
      return NumLit(Fraction(2 + rng.nextInt(maxInt - 1)));
    }

    return _randomTree(rng, ops, leaf);
  }

  static Expr _randomTree(Rng rng, int ops, Expr Function() leaf) {
    if (ops == 0) return leaf();
    final leftOps = rng.nextInt(ops);
    final op = rng.pick(const [Op.add, Op.sub, Op.mul, Op.mul, Op.div]);
    return BinExpr(
      op,
      _randomTree(rng, leftOps, leaf),
      _randomTree(rng, ops - 1 - leftOps, leaf),
    );
  }

  static Expr _percentTree(Rng rng, Difficulty d) {
    NumLit pct() => NumLit(Fraction(rng.pick(percentValues)), percent: true);
    NumLit base() => NumLit(
        Fraction(20 * (1 + rng.nextInt(d == Difficulty.hard ? 40 : 25))));
    Expr mul(Expr a, Expr b) => BinExpr(Op.mul, a, b);
    final pick = rng.nextInt(3);
    if (d == Difficulty.medium) {
      switch (pick) {
        case 0:
          return mul(pct(), base());
        case 1:
          final b = base();
          return BinExpr(rng.nextBool() ? Op.add : Op.sub, b, mul(pct(), b));
        default:
          return BinExpr(Op.add, mul(pct(), base()), mul(pct(), base()));
      }
    }
    switch (pick) {
      case 0:
        // Naik p% lalu turun q%.
        return mul(
          mul(base(),
              BinExpr(Op.add, NumLit(Fraction(100), percent: true), pct())),
          BinExpr(Op.sub, NumLit(Fraction(100), percent: true), pct()),
        );
      case 1:
        return BinExpr(
          Op.sub,
          BinExpr(Op.add, mul(pct(), base()), mul(pct(), base())),
          NumLit(Fraction(2 + rng.nextInt(30))),
        );
      default:
        final b = base();
        return BinExpr(
          Op.div,
          BinExpr(Op.add, b, mul(pct(), b)),
          NumLit(Fraction(2 + rng.nextInt(9))),
        );
    }
  }

  /// Pengecoh yang masuk akal beserta nilainya, tanpa jawaban dan tanpa
  /// teks kembar: kesalahan urutan operasi dan pembulatan lebih dulu.
  static List<(String, Fraction)> _foils(
      Rng rng, String text, Fraction answer) {
    final seen = {answer.toDecimal()};
    final out = <(String, Fraction)>[];
    void add(Fraction? v) {
      if (v == null || v.isNegative) return;
      final s = v.toDecimal();
      if (s != null && seen.add(s)) out.add((s, v));
    }

    final plausible = <Fraction?>[
      leftToRightValue(text),
      if (!answer.isInteger) Fraction(answer.roundHalfUp()),
      if (!answer.isInteger) Fraction(answer.truncate()),
      if (!answer.isInteger && answer.toDecimal(maxPlaces: 1) == null)
        _roundTo(answer, 10),
      _safe(() => answer * Fraction(10)),
      _safe(() => answer / Fraction(10)),
    ];
    for (final v in rng.shuffle(plausible)) {
      add(v);
    }
    // Pelengkap: angka dekat jawaban dengan langkah sesuai ketelitiannya.
    final unit = answer.isInteger ? Fraction(1) : Fraction(1, 10);
    for (final k in rng.shuffle([1, -1, 2, -2, 3, -3, 5, 10])) {
      add(_safe(() => answer + unit * Fraction(k)));
    }
    return out;
  }

  static Fraction? _roundTo(Fraction v, int scale) {
    final r = (v * Fraction(scale)).roundHalfUp();
    return Fraction(r, scale);
  }

  static Fraction? _safe(Fraction Function() f) {
    try {
      return f();
    } on FractionOverflow {
      return null;
    }
  }

  // Perbandingan.

  Question? _buildCompare(Rng rng, int seed, Difficulty difficulty) {
    final gap = difficulty == Difficulty.hard ? 1 : 4;
    // Nilai dalam perseratus agar bisa ditulis sebagai desimal dan persen.
    List<int>? hundredths;
    for (var t = 0; t < treeTries && hundredths == null; t++) {
      final candidate = [
        for (var i = 0; i < optionCount; i++) 10 + rng.nextInt(141)
      ];
      final sorted = [...candidate]..sort();
      var ok = true;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] - sorted[i - 1] < gap) ok = false;
      }
      if (ok) hundredths = candidate;
    }
    if (hundredths == null) return null;

    final wantMax = rng.nextBool();
    final sorted = [...hundredths]..sort();
    final extreme = wantMax ? sorted.last : sorted.first;
    final texts = [for (final h in hundredths) _representation(rng, h)];
    if (texts.toSet().length != texts.length) return null;

    final answerText = texts[hundredths.indexOf(extreme)];
    final others = [
      for (var i = 0; i < hundredths.length; i++)
        if (hundredths[i] != extreme) texts[i],
    ];
    final assembled = assembleOptions(
      rng,
      QuestionContent(text: answerText),
      [for (final o in others) QuestionContent(text: o)],
    );

    final decimals = [
      for (var i = 0; i < hundredths.length; i++)
        texts[i] == Fraction(hundredths[i], 100).toDecimal()
            ? texts[i]
            : '${texts[i]} = ${Fraction(hundredths[i], 100).toDecimal()}',
    ];
    final extremeDecimal = Fraction(extreme, 100).toDecimal();
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(text: wantMax ? compareMaxText : compareMinText),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: 'Ubah semua nilai ke desimal agar bisa dibandingkan: '
          '${decimals.join('; ')}. Nilai paling ${wantMax ? 'besar' : 'kecil'} '
          'adalah $extremeDecimal, yaitu $answerText.',
      estimatedSeconds: difficulty == Difficulty.hard ? 50 : 35,
      tags: const ['rule:num-ari:compare'],
    );
  }

  /// Penulisan nilai [hundredths]/100 sebagai pecahan, desimal, atau persen.
  static String _representation(Rng rng, int hundredths) {
    final value = Fraction(hundredths, 100);
    final choices = <String>[
      value.toDecimal()!,
      '$hundredths%',
      if (value.den <= 25 && !value.isInteger) '${value.num}/${value.den}',
    ];
    return rng.pick(choices);
  }
}
