/// Ekspresi hitung untuk NUM-ARI: pohon, pencetak teks, dan pengurai.
///
/// Tata bahasa (teks tampilan Indonesia):
///
///     ekspresi := suku (('+' | '-' | '−') suku)*
///     suku     := faktor (('×' | '÷' | '*' | '/') faktor)*   // dari kiri
///     faktor   := bilangan ['%'] | pecahan | '(' ekspresi ')'
///     pecahan  := bilangan '/' bilangan                       // hanya literal
///
/// Bilangan memakai koma desimal ("2,5"). `%` di belakang bilangan berarti
/// dibagi 100. Semua hitungan memakai [Fraction] (eksak).
library;

import '../../fraction.dart';

sealed class Expr {
  const Expr();

  /// Nilai eksak. Melempar [FractionOverflow] atau [ArgumentError] (bagi nol).
  Fraction get value;

  /// Teks tampilan dengan kurung seperlunya.
  String get text;

  /// Prioritas operator: 3 bilangan dan kurung, 2 kali bagi, 1 tambah kurang.
  int get precedence;
}

final class NumLit extends Expr {
  const NumLit(this.number, {this.percent = false});

  /// Nilai tertulis (25 untuk "25%").
  final Fraction number;
  final bool percent;

  @override
  Fraction get value => percent ? number / Fraction(100) : number;

  @override
  String get text =>
      '${(number.toDecimal(maxPlaces: 3) ?? '$number').replaceAll('.', '')}'
      '${percent ? '%' : ''}';

  @override
  int get precedence => 3;
}

/// Pecahan literal "a/b", hanya untuk perbandingan.
final class FractionLit extends Expr {
  const FractionLit(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  @override
  Fraction get value => Fraction(numerator, denominator);

  @override
  String get text => '$numerator/$denominator';

  @override
  int get precedence => 3;
}

enum Op {
  add('+', 1),
  sub('−', 1),
  mul('×', 2),
  div('÷', 2);

  const Op(this.symbol, this.precedence);

  final String symbol;
  final int precedence;
}

final class BinExpr extends Expr {
  const BinExpr(this.op, this.left, this.right);

  final Op op;
  final Expr left;
  final Expr right;

  @override
  Fraction get value {
    final l = left.value;
    final r = right.value;
    return switch (op) {
      Op.add => l + r,
      Op.sub => l - r,
      Op.mul => l * r,
      Op.div => l / r,
    };
  }

  @override
  int get precedence => op.precedence;

  @override
  String get text {
    final l = left.precedence < op.precedence ? '(${left.text})' : left.text;
    // Sisi kanan: kurung juga untuk prioritas sama (a − (b − c), a ÷ (b × c)).
    final needsParens = right.precedence < op.precedence ||
        (right.precedence == op.precedence && right is BinExpr);
    final r = needsParens ? '(${right.text})' : right.text;
    return '$l ${op.symbol} $r';
  }
}

/// Pembungkus kurung eksplisit; hanya dihasilkan [parseExpr].
final class ParenExpr extends Expr {
  const ParenExpr(this.inner);

  final Expr inner;

  @override
  Fraction get value => inner.value;

  @override
  String get text => '(${inner.text})';

  @override
  int get precedence => 3;
}

/// Mengurai [source]; null bila tidak sesuai tata bahasa.
Expr? parseExpr(String source) {
  final p = _Parser(source);
  try {
    final e = p.parseExpression();
    p.skipSpaces();
    return p.atEnd ? e : null;
  } on FormatException {
    return null;
  }
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  bool get atEnd => i >= s.length;

  void skipSpaces() {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
  }

  Never fail() => throw const FormatException('ekspresi tidak sah');

  Expr parseExpression() {
    var left = parseTerm();
    while (true) {
      skipSpaces();
      if (atEnd) return left;
      final c = s[i];
      final op = switch (c) {
        '+' => Op.add,
        '-' || '−' => Op.sub,
        _ => null,
      };
      if (op == null) return left;
      i++;
      left = BinExpr(op, left, parseTerm());
    }
  }

  Expr parseTerm() {
    var left = parseFactor();
    while (true) {
      skipSpaces();
      if (atEnd) return left;
      final c = s[i];
      final op = switch (c) {
        '×' || '*' => Op.mul,
        '÷' => Op.div,
        _ => null,
      };
      if (op == null) return left;
      i++;
      left = BinExpr(op, left, parseFactor());
    }
  }

  Expr parseFactor() {
    skipSpaces();
    if (atEnd) fail();
    if (s[i] == '(') {
      i++;
      final inner = parseExpression();
      skipSpaces();
      if (atEnd || s[i] != ')') fail();
      i++;
      return ParenExpr(inner);
    }
    final m = RegExp(r'\d+(?:,\d+)?').matchAsPrefix(s, i);
    if (m == null) fail();
    final number = Fraction.parseDecimal(m.group(0)!);
    if (number == null) fail();
    i = m.end;
    if (i < s.length && s[i] == '%') {
      i++;
      return NumLit(number, percent: true);
    }
    if (i < s.length && s[i] == '/') {
      final d = RegExp(r'\d+').matchAsPrefix(s, i + 1);
      if (d != null && number.isInteger) {
        i = d.end;
        final den = int.parse(d.group(0)!);
        if (den == 0) fail();
        return FractionLit(number.num, den);
      }
    }
    return NumLit(number);
  }
}

/// Nilai bila operator dikerjakan dari kiri ke kanan tanpa urutan operasi
/// (kesalahan umum). Kurung tetap dikerjakan lebih dulu. Null bila tidak
/// terurai atau melampaui batas hitung.
Fraction? leftToRightValue(String source) {
  final e = parseExpr(source);
  if (e == null) return null;
  try {
    return _ltr(e);
  } on FractionOverflow {
    return null;
  } on ArgumentError {
    return null;
  }
}

Fraction _ltr(Expr e) {
  final items = <Fraction>[];
  final ops = <Op>[];
  // Urutan tengah pohon sama dengan urutan tulisan; kurung dikerjakan sendiri.
  void inorder(Expr x) {
    switch (x) {
      case BinExpr():
        inorder(x.left);
        ops.add(x.op);
        inorder(x.right);
      case ParenExpr():
        items.add(_ltr(x.inner));
      case NumLit() || FractionLit():
        items.add(x.value);
    }
  }

  inorder(e);
  var acc = items.first;
  for (var k = 0; k < ops.length; k++) {
    final r = items[k + 1];
    acc = switch (ops[k]) {
      Op.add => acc + r,
      Op.sub => acc - r,
      Op.mul => acc * r,
      Op.div => acc / r,
    };
  }
  return acc;
}

/// Langkah hitung berurutan sesuai urutan operasi, untuk pembahasan.
List<String> workSteps(Expr e) {
  final steps = <String>[];
  String show(Fraction f) => f.toDecimal(maxPlaces: 4) ?? f.toString();

  void percents(Expr x) {
    switch (x) {
      case NumLit() when x.percent:
        final line = '${x.text} = ${show(x.value)}';
        if (!steps.contains(line)) steps.add(line);
      case BinExpr():
        percents(x.left);
        percents(x.right);
      case ParenExpr():
        percents(x.inner);
      default:
        break;
    }
  }

  void walk(Expr x) {
    switch (x) {
      case BinExpr():
        walk(x.left);
        walk(x.right);
        steps.add('${show(x.left.value)} ${x.op.symbol} ${show(x.right.value)}'
            ' = ${show(x.value)}');
      case ParenExpr():
        walk(x.inner);
      default:
        break;
    }
  }

  percents(e);
  walk(e);
  return steps;
}
