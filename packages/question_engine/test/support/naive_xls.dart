/// Solver kedua IT-XLS yang ditulis terpisah dari engine, untuk dibandingkan
/// dengan [ItXlsSolver]. Tidak memakai `sheet.dart`. Cara kerjanya reduksi
/// teks: kurung atau fungsi terdalam dihitung lalu diganti penanda `#n#` yang
/// menunjuk ke daftar nilai, berulang sampai tinggal satu ekspresi datar.
/// Ekspresi datar dipecah pada operator berprioritas terendah paling kanan.
library;

import 'package:question_engine/question_engine.dart';

/// Nilai galat Excel.
final class _Err {
  const _Err(this.code);
  final String code;
}

String? naiveXlsAnswer(Question q) {
  final table = q.stem.figure;
  if (table is! TableFigure) return null;
  final lines = (q.stem.text ?? '').split('\n');
  if (lines.length != 3) return null;
  final cells = <String, Object>{};
  for (final row in table.rows) {
    for (var c = 1; c < row.length; c++) {
      if (row[c] == '-') continue;
      cells['${'ABC'[c - 1]}${row[0]}'] = _number(row[c]) ?? row[c];
    }
  }
  final v = _Reducer(cells).run(lines[1].substring(1));
  return switch (v) {
    Fraction() => v.toDecimal() ?? v.toString(),
    String() => v,
    bool() => v ? 'TRUE' : 'FALSE',
    _Err() => v.code,
    _ => null,
  };
}

Fraction? _number(String s) {
  final m = RegExp(r'^(\d+)(?:,(\d+))?$').firstMatch(s);
  if (m == null) return null;
  final whole = Fraction(int.parse(m.group(1)!));
  final frac = m.group(2);
  if (frac == null) return whole;
  var den = 1;
  for (var i = 0; i < frac.length; i++) {
    den *= 10;
  }
  return whole + Fraction(int.parse(frac), den);
}

final class _Reducer {
  _Reducer(this.cells);

  final Map<String, Object> cells;
  final List<Object> slots = [];

  String _slot(Object v) {
    slots.add(v);
    return '#${slots.length - 1}#';
  }

  Object run(String formula) {
    var s = formula;
    final innermost = RegExp(r'([A-Z]*)\(([^()]*)\)');
    while (true) {
      final m = innermost.firstMatch(s);
      if (m == null) break;
      final name = m.group(1)!;
      final inner = m.group(2)!;
      final Object value =
          name.isEmpty ? _flat(inner) : _function(name, _args(inner));
      s = s.replaceRange(m.start, m.end, _slot(value));
    }
    return _flat(s);
  }

  /// Argumen dipisah titik koma di luar kutip.
  List<String> _args(String s) {
    final out = <String>[];
    var buf = StringBuffer();
    var quoted = false;
    for (final ch in s.split('')) {
      if (ch == '"') quoted = !quoted;
      if (ch == ';' && !quoted) {
        out.add(buf.toString().trim());
        buf = StringBuffer();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  /// Sel di rentang "B2:C4", baris demi baris; kosong = null.
  List<List<Object?>>? _range(String s) {
    final m = RegExp(r'^([A-C])(\d+):([A-C])(\d+)$').firstMatch(s);
    if (m == null) return null;
    final c1 = m.group(1)!.codeUnitAt(0);
    final c2 = m.group(3)!.codeUnitAt(0);
    final r1 = int.parse(m.group(2)!);
    final r2 = int.parse(m.group(4)!);
    if (r1 > r2 || c1 > c2) return null;
    return [
      for (var r = r1; r <= r2; r++)
        [for (var c = c1; c <= c2; c++) cells['${String.fromCharCode(c)}$r']],
    ];
  }

  bool _same(Object? a, Object? b) {
    if (a is Fraction && b is Fraction) return a.equals(b);
    if (a is String && b is String) return a.toLowerCase() == b.toLowerCase();
    return false;
  }

  Object _function(String name, List<String> args) {
    switch (name) {
      case 'SUM':
        var total = Fraction.zero;
        for (final a in args) {
          final r = _range(a);
          if (r != null) {
            for (final v in r.expand((row) => row)) {
              if (v is Fraction) total = total + v;
            }
            continue;
          }
          final v = _flat(a);
          if (v is _Err) return v;
          if (v is! Fraction) return const _Err('#VALUE!');
          total = total + v;
        }
        return total;
      case 'IF':
        final c = _flat(args[0]);
        if (c is _Err) return c;
        final yes = c is bool ? c : (c is Fraction ? !c.isZero : null);
        if (yes == null) return const _Err('#VALUE!');
        return _flat(args[yes ? 1 : 2]);
      case 'VLOOKUP':
        if (args.length != 4 || args[3] != 'FALSE') {
          return const _Err('#VALUE!');
        }
        final key = _flat(args[0]);
        final r = _range(args[1]);
        if (r == null) return const _Err('#REF!');
        final col = _flat(args[2]);
        if (col is! Fraction) return const _Err('#VALUE!');
        if (col.num > r.first.length) return const _Err('#REF!');
        for (final row in r) {
          if (_same(row.first, key)) return row[col.num - 1] ?? Fraction.zero;
        }
        return const _Err('#N/A');
      case 'COUNTIF':
        final r = _range(args[0]);
        if (r == null) return const _Err('#REF!');
        final crit = _flat(args[1]);
        var n = 0;
        for (final v in r.expand((row) => row)) {
          if (_meets(v, crit)) n++;
        }
        return Fraction(n);
    }
    return const _Err('#NAME?');
  }

  bool _meets(Object? v, Object crit) {
    if (crit is Fraction) return v is Fraction && v.equals(crit);
    final text = crit as String;
    for (final op in ['<=', '>=', '<>', '<', '>', '=']) {
      if (!text.startsWith(op)) continue;
      final n = _number(text.substring(op.length));
      if (n == null) {
        final same = _same(v, text.substring(op.length));
        return op == '<>' ? !same : same;
      }
      if (v is! Fraction) return op == '<>';
      return switch (op) {
        '<=' => v <= n,
        '>=' => v >= n,
        '<>' => !v.equals(n),
        '<' => v < n,
        '>' => v > n,
        _ => v.equals(n),
      };
    }
    return _same(v, text);
  }

  /// Ekspresi tanpa kurung: pecah di operator terendah paling kanan.
  Object _flat(String raw) {
    final s = raw.trim();
    for (final ops in const [
      ['<=', '>=', '<>', '<', '>', '='],
      ['+', '-'],
      ['*', '/'],
    ]) {
      final split = _rightmost(s, ops);
      if (split == null) continue;
      final (at, op) = split;
      final l = _flat(s.substring(0, at));
      final r = _flat(s.substring(at + op.length));
      if (l is _Err) return l;
      if (r is _Err) return r;
      if (ops.first == '<=') {
        final int c;
        if (l is Fraction && r is Fraction) {
          c = l.compareTo(r);
        } else if (l is String && r is String) {
          c = l.toLowerCase().compareTo(r.toLowerCase());
        } else {
          return const _Err('#VALUE!');
        }
        return switch (op) {
          '<=' => c <= 0,
          '>=' => c >= 0,
          '<>' => c != 0,
          '<' => c < 0,
          '>' => c > 0,
          _ => c == 0,
        };
      }
      if (l is! Fraction || r is! Fraction) return const _Err('#VALUE!');
      return switch (op) {
        '+' => l + r,
        '-' => l - r,
        '*' => l * r,
        _ => r.isZero ? const _Err('#DIV/0!') : l / r,
      };
    }
    if (s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    final slot = RegExp(r'^#(\d+)#$').firstMatch(s);
    if (slot != null) return slots[int.parse(slot.group(1)!)];
    if (RegExp(r'^\d+$').hasMatch(s)) return Fraction(int.parse(s));
    if (RegExp(r'^[A-C]\d+$').hasMatch(s)) return cells[s] ?? Fraction.zero;
    if (s == 'FALSE') return false;
    return const _Err('#NAME?');
  }

  /// Posisi operator dari [ops] paling kanan di luar kutip. Operator dua
  /// huruf dicoba lebih dulu; "<" yang bagian dari "<=" tidak dipakai.
  (int, String)? _rightmost(String s, List<String> ops) {
    var quoted = false;
    (int, String)? found;
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"') {
        quoted = !quoted;
        i++;
        continue;
      }
      if (!quoted) {
        String? hit;
        for (final op in ops) {
          if (s.startsWith(op, i)) {
            hit = op;
            break;
          }
        }
        // Lewati operator dua huruf dari kelompok lain ("<=" saat mencari +).
        if (hit == null && i + 1 < s.length) {
          final two = s.substring(i, i + 2);
          if (const ['<=', '>=', '<>'].contains(two)) {
            i += 2;
            continue;
          }
        }
        if (hit != null) {
          // Minus di awal bukan operator biner.
          if (!(hit == '-' && s.substring(0, i).trim().isEmpty)) {
            found = (i, hit);
          }
          i += hit.length;
          continue;
        }
      }
      i++;
    }
    return found;
  }
}
