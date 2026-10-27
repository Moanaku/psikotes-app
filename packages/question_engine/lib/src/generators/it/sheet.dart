/// Lembar kerja mini dan rumus Excel untuk IT-XLS.
///
/// Rumus: bilangan bulat, teks berkutip, rujukan sel (`B3`), rentang (`B2:B6`,
/// hanya sebagai argumen fungsi), `+ - * /`, perbandingan `= <> < > <= >=`,
/// dan fungsi SUM, IF, VLOOKUP (hanya pencocokan tepat, argumen keempat
/// FALSE), dan COUNTIF. Pemisah argumen titik koma, seperti Excel berbahasa
/// Indonesia, karena angka desimal di tabel memakai koma. Aritmetika memakai
/// [Fraction], jadi tidak ada galat pembulatan.
///
/// Aturan Excel yang diikuti: SUM melewati sel teks dan kosong di rentang;
/// perbandingan teks tidak membedakan huruf besar; kriteria COUNTIF berupa
/// teks dengan operator di depan (">=70") atau teks biasa ("Lulus").
/// Kesalahan menjadi nilai `#N/A`, `#VALUE!`, `#REF!`, atau `#DIV/0!`.
library;

import '../../figure_spec.dart';
import '../../fraction.dart';

// ---------------------------------------------------------------------------
// Nilai
// ---------------------------------------------------------------------------

sealed class XlsValue {
  const XlsValue();

  /// Teks yang tampil di sel.
  String display();
}

final class XlsNumber extends XlsValue {
  const XlsNumber(this.value);

  final Fraction value;

  /// Desimal dengan koma, paling banyak dua angka di belakang koma; pecahan
  /// lain ditulis apa adanya (tidak dipakai generator).
  @override
  String display() => value.toDecimal() ?? value.toString();
}

final class XlsText extends XlsValue {
  const XlsText(this.value);

  final String value;

  @override
  String display() => value;
}

final class XlsBool extends XlsValue {
  const XlsBool(this.value);

  final bool value;

  @override
  String display() => value ? 'TRUE' : 'FALSE';
}

final class XlsError extends XlsValue {
  const XlsError(this.code);

  static const XlsError na = XlsError('#N/A');
  static const XlsError value = XlsError('#VALUE!');
  static const XlsError ref = XlsError('#REF!');
  static const XlsError div0 = XlsError('#DIV/0!');

  final String code;

  @override
  String display() => code;
}

// ---------------------------------------------------------------------------
// Lembar kerja
// ---------------------------------------------------------------------------

/// Sel berisi teks atau bilangan; sel di luar data dianggap kosong.
final class Sheet {
  Sheet(Map<String, String> cells) : cells = Map.unmodifiable(cells);

  /// Kunci "B3"; isi seperti tampil di tabel.
  final Map<String, String> cells;

  static const List<String> columns = ['A', 'B', 'C'];

  /// Judul kolom tabel: penanda nomor baris lalu huruf kolom.
  static const List<String> headers = ['#', 'A', 'B', 'C'];

  /// Isi sel; null bila kosong.
  XlsValue? at(int col, int row) {
    if (col < 0 || col >= columns.length) return null;
    final raw = cells['${columns[col]}$row'];
    if (raw == null) return null;
    final n = Fraction.parseDecimal(raw);
    return n == null ? XlsText(raw) : XlsNumber(n);
  }

  int get rowCount {
    var max = 0;
    for (final k in cells.keys) {
      final r = int.parse(k.substring(1));
      if (r > max) max = r;
    }
    return max;
  }

  TableFigure toTable() => TableFigure(
        headers: headers,
        rows: [
          for (var r = 1; r <= rowCount; r++)
            ['$r', for (final c in columns) cells['$c$r'] ?? '-'],
        ],
      );

  /// Null bila tabel bukan lembar kerja IT-XLS. Sel "-" berarti kosong.
  static Sheet? fromTable(FigureSpec? figure) {
    if (figure is! TableFigure) return null;
    if (figure.headers.join('|') != headers.join('|')) return null;
    final cells = <String, String>{};
    for (var i = 0; i < figure.rows.length; i++) {
      final row = figure.rows[i];
      if (row[0] != '${i + 1}') return null;
      for (var c = 0; c < columns.length; c++) {
        if (row[c + 1] != '-') cells['${columns[c]}${i + 1}'] = row[c + 1];
      }
    }
    return Sheet(cells);
  }
}

// ---------------------------------------------------------------------------
// Rumus
// ---------------------------------------------------------------------------

/// Kesalahan sintaks rumus (bukan nilai galat Excel).
final class XlsSyntaxError implements Exception {
  const XlsSyntaxError(this.message);

  final String message;

  @override
  String toString() => 'XlsSyntaxError($message)';
}

sealed class XlsExpr {
  const XlsExpr();

  String render();
}

final class XlsNum extends XlsExpr {
  const XlsNum(this.value);

  final int value;

  @override
  String render() => '$value';
}

final class XlsStr extends XlsExpr {
  const XlsStr(this.value);

  final String value;

  @override
  String render() => '"$value"';
}

final class XlsFalse extends XlsExpr {
  const XlsFalse();

  @override
  String render() => 'FALSE';
}

/// Rujukan satu sel. [col] 0 untuk A.
final class XlsRef extends XlsExpr {
  const XlsRef(this.col, this.row);

  final int col;
  final int row;

  static String name(int col, int row) =>
      '${String.fromCharCode(0x41 + col)}$row';

  @override
  String render() => name(col, row);
}

final class XlsRange extends XlsExpr {
  const XlsRange(this.col1, this.row1, this.col2, this.row2);

  final int col1;
  final int row1;
  final int col2;
  final int row2;

  @override
  String render() => '${XlsRef.name(col1, row1)}:${XlsRef.name(col2, row2)}';
}

final class XlsBin extends XlsExpr {
  const XlsBin(this.op, this.left, this.right);

  /// `+ - * /` atau perbandingan `= <> < > <= >=`.
  final String op;
  final XlsExpr left;
  final XlsExpr right;

  static bool isCompare(String op) =>
      const {'=', '<>', '<', '>', '<=', '>='}.contains(op);

  int get precedence => isCompare(op) ? 0 : (op == '+' || op == '-' ? 1 : 2);

  @override
  String render() {
    String side(XlsExpr e, bool right) {
      final p = e is XlsBin ? e.precedence : 9;
      final wrap = right ? p <= precedence : p < precedence;
      return wrap ? '(${e.render()})' : e.render();
    }

    return '${side(left, false)} $op ${side(right, true)}';
  }
}

final class XlsCall extends XlsExpr {
  const XlsCall(this.name, this.args);

  final String name;
  final List<XlsExpr> args;

  @override
  String render() => '$name(${args.map((a) => a.render()).join('; ')})';
}

/// Rumus lengkap dengan tanda `=` di depan.
String renderFormula(XlsExpr e) => '=${e.render()}';

const Set<String> xlsFunctions = {'SUM', 'IF', 'VLOOKUP', 'COUNTIF'};

final RegExp _xlsToken = RegExp(
  r'\s*(?:(\d+)|"([^"]*)"|([A-Z]+[0-9]*)|(<=|>=|<>|[-+*/()<>=;:]))',
);

/// Rumus dari teks yang diawali `=`. Melempar [XlsSyntaxError].
XlsExpr parseFormula(String text) {
  if (!text.startsWith('=')) throw const XlsSyntaxError('tanpa =');
  final tokens = <(String kind, String value)>[];
  var pos = 1;
  final src = text.trimRight();
  while (pos < src.length) {
    final m = _xlsToken.matchAsPrefix(src, pos);
    if (m == null || m.end == pos) {
      throw XlsSyntaxError('karakter tak dikenal di posisi $pos');
    }
    pos = m.end;
    if (m.group(1) != null) {
      tokens.add(('num', m.group(1)!));
    } else if (m.group(2) != null) {
      tokens.add(('str', m.group(2)!));
    } else if (m.group(3) != null) {
      tokens.add(('name', m.group(3)!));
    } else {
      tokens.add(('op', m.group(4)!));
    }
  }
  var i = 0;
  (String, String)? peek() => i < tokens.length ? tokens[i] : null;
  (String, String) next() =>
      i < tokens.length ? tokens[i++] : throw const XlsSyntaxError('terpotong');
  bool takeOp(String op) {
    final t = peek();
    if (t != null && t.$1 == 'op' && t.$2 == op) {
      i++;
      return true;
    }
    return false;
  }

  (int, int)? ref(String name) {
    final m = RegExp(r'^([A-Z])([1-9][0-9]?)$').firstMatch(name);
    if (m == null) return null;
    return (m.group(1)!.codeUnitAt(0) - 0x41, int.parse(m.group(2)!));
  }

  late final XlsExpr Function() expr;

  XlsExpr primary() {
    final t = next();
    switch (t.$1) {
      case 'num':
        return XlsNum(int.parse(t.$2));
      case 'str':
        return XlsStr(t.$2);
      case 'op':
        if (t.$2 == '(') {
          final e = expr();
          if (!takeOp(')')) throw const XlsSyntaxError('kurung tidak ditutup');
          return e;
        }
        if (t.$2 == '-') {
          final inner = primary();
          return XlsBin('-', const XlsNum(0), inner);
        }
        throw XlsSyntaxError('operator di tempat nilai: ${t.$2}');
    }
    final name = t.$2;
    if (name == 'FALSE') return const XlsFalse();
    if (xlsFunctions.contains(name)) {
      if (!takeOp('(')) throw XlsSyntaxError('$name tanpa kurung');
      final args = <XlsExpr>[];
      if (!takeOp(')')) {
        do {
          args.add(expr());
        } while (takeOp(';'));
        if (!takeOp(')')) throw XlsSyntaxError('$name tidak ditutup');
      }
      return XlsCall(name, args);
    }
    final r = ref(name);
    if (r == null) throw XlsSyntaxError('nama tak dikenal: $name');
    if (takeOp(':')) {
      final t2 = next();
      final r2 = t2.$1 == 'name' ? ref(t2.$2) : null;
      if (r2 == null) throw const XlsSyntaxError('rentang salah');
      return XlsRange(r.$1, r.$2, r2.$1, r2.$2);
    }
    return XlsRef(r.$1, r.$2);
  }

  XlsExpr binary(int level) {
    if (level == 3) return primary();
    var left = binary(level + 1);
    while (true) {
      final t = peek();
      if (t == null || t.$1 != 'op') return left;
      final ok = switch (level) {
        0 => XlsBin.isCompare(t.$2),
        1 => t.$2 == '+' || t.$2 == '-',
        _ => t.$2 == '*' || t.$2 == '/',
      };
      if (!ok) return left;
      i++;
      left = XlsBin(t.$2, left, binary(level + 1));
      // Perbandingan tidak berantai.
      if (level == 0) return left;
    }
  }

  expr = () => binary(0);
  final result = expr();
  if (i != tokens.length) throw const XlsSyntaxError('sisa teks');
  return result;
}

// ---------------------------------------------------------------------------
// Evaluasi
// ---------------------------------------------------------------------------

/// Nilai rumus [e] pada [sheet]. Tidak melempar kecuali [FractionOverflow].
XlsValue evalFormula(XlsExpr e, Sheet sheet) => switch (e) {
      XlsNum() => XlsNumber(Fraction(e.value)),
      XlsStr() => XlsText(e.value),
      XlsFalse() => const XlsBool(false),
      XlsRef() => sheet.at(e.col, e.row) ?? const XlsNumber(Fraction.zero),
      XlsRange() => XlsError.value,
      XlsBin() => _binary(e, sheet),
      XlsCall() => _call(e, sheet),
    };

XlsValue _binary(XlsBin e, Sheet sheet) {
  final l = evalFormula(e.left, sheet);
  if (l is XlsError) return l;
  final r = evalFormula(e.right, sheet);
  if (r is XlsError) return r;
  if (XlsBin.isCompare(e.op)) {
    final c = _compare(l, r);
    if (c == null) return XlsError.value;
    return XlsBool(switch (e.op) {
      '=' => c == 0,
      '<>' => c != 0,
      '<' => c < 0,
      '>' => c > 0,
      '<=' => c <= 0,
      _ => c >= 0,
    });
  }
  if (l is! XlsNumber || r is! XlsNumber) return XlsError.value;
  return switch (e.op) {
    '+' => XlsNumber(l.value + r.value),
    '-' => XlsNumber(l.value - r.value),
    '*' => XlsNumber(l.value * r.value),
    _ => r.value.isZero ? XlsError.div0 : XlsNumber(l.value / r.value),
  };
}

/// Urutan dua nilai sejenis; null bila tidak bisa dibandingkan.
int? _compare(XlsValue a, XlsValue b) {
  if (a is XlsNumber && b is XlsNumber) return a.value.compareTo(b.value);
  if (a is XlsText && b is XlsText) {
    return a.value.toLowerCase().compareTo(b.value.toLowerCase());
  }
  return null;
}

/// Isi rentang baris demi baris (sel kosong = null).
List<List<XlsValue?>> _cells(XlsRange r, Sheet sheet) => [
      for (var row = r.row1; row <= r.row2; row++)
        [for (var col = r.col1; col <= r.col2; col++) sheet.at(col, row)],
    ];

bool _rangeValid(XlsRange r) => r.row1 <= r.row2 && r.col1 <= r.col2;

XlsValue _call(XlsCall e, Sheet sheet) {
  switch (e.name) {
    case 'SUM':
      if (e.args.isEmpty) return XlsError.value;
      var sum = Fraction.zero;
      for (final a in e.args) {
        if (a is XlsRange) {
          if (!_rangeValid(a)) return XlsError.ref;
          for (final row in _cells(a, sheet)) {
            for (final v in row) {
              if (v is XlsNumber) sum = sum + v.value;
            }
          }
        } else {
          final v = evalFormula(a, sheet);
          if (v is XlsError) return v;
          if (v is! XlsNumber) return XlsError.value;
          sum = sum + v.value;
        }
      }
      return XlsNumber(sum);
    case 'IF':
      if (e.args.length != 3) return XlsError.value;
      final c = evalFormula(e.args[0], sheet);
      if (c is XlsError) return c;
      final bool truth;
      if (c is XlsBool) {
        truth = c.value;
      } else if (c is XlsNumber) {
        truth = !c.value.isZero;
      } else {
        return XlsError.value;
      }
      return evalFormula(e.args[truth ? 1 : 2], sheet);
    case 'VLOOKUP':
      if (e.args.length != 4 || e.args[3] is! XlsFalse) return XlsError.value;
      final range = e.args[1];
      if (range is! XlsRange || !_rangeValid(range)) return XlsError.ref;
      final key = evalFormula(e.args[0], sheet);
      if (key is XlsError) return key;
      final idx = evalFormula(e.args[2], sheet);
      if (idx is! XlsNumber || !idx.value.isInteger) return XlsError.value;
      final col = idx.value.num;
      if (col < 1) return XlsError.value;
      if (col > range.col2 - range.col1 + 1) return XlsError.ref;
      for (final row in _cells(range, sheet)) {
        final first = row.first;
        if (first != null && _compare(first, key) == 0) {
          return row[col - 1] ?? const XlsNumber(Fraction.zero);
        }
      }
      return XlsError.na;
    case 'COUNTIF':
      if (e.args.length != 2) return XlsError.value;
      final range = e.args[0];
      if (range is! XlsRange || !_rangeValid(range)) return XlsError.ref;
      final crit = evalFormula(e.args[1], sheet);
      if (crit is XlsError) return crit;
      final match = _criterion(crit);
      if (match == null) return XlsError.value;
      var count = 0;
      for (final row in _cells(range, sheet)) {
        for (final v in row) {
          if (match(v)) count++;
        }
      }
      return XlsNumber(Fraction(count));
  }
  return XlsError.value;
}

/// Pencocok kriteria COUNTIF; null bila kriteria tidak didukung.
bool Function(XlsValue?)? _criterion(XlsValue crit) {
  if (crit is XlsNumber) {
    return (v) => v is XlsNumber && v.value.equals(crit.value);
  }
  if (crit is! XlsText) return null;
  final m = RegExp(r'^(<=|>=|<>|<|>|=)?(.*)$').firstMatch(crit.value)!;
  final op = m.group(1) ?? '=';
  final rest = m.group(2)!;
  final n = Fraction.parseDecimal(rest);
  if (n != null) {
    return (v) {
      if (v is! XlsNumber) return op == '<>';
      final c = v.value.compareTo(n);
      return switch (op) {
        '=' => c == 0,
        '<>' => c != 0,
        '<' => c < 0,
        '>' => c > 0,
        '<=' => c <= 0,
        _ => c >= 0,
      };
    };
  }
  if (op != '=' && op != '<>') return null;
  final want = rest.toLowerCase();
  return (v) {
    final same = v is XlsText && v.value.toLowerCase() == want;
    return op == '=' ? same : !same;
  };
}
