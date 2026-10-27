/// Solver kedua IT-FLW yang ditulis terpisah dari engine, untuk dibandingkan
/// dengan [ItFlwSolver]. Tidak memakai `pseudo.dart`: teks kotak dibaca
/// dengan regex, ekspresi dan kondisi dihitung dengan shunting-yard sendiri
/// (semua operator dalam satu tabel prioritas, termasuk DAN, ATAU, dan
/// perbandingan; benar = 1, salah = 0).
library;

import 'package:question_engine/question_engine.dart';

/// Prioritas operator biner; makin besar makin kuat.
const Map<String, int> _prec = {
  'ATAU': 1,
  'DAN': 2,
  '=': 3,
  '!=': 3,
  '<': 3,
  '>': 3,
  '<=': 3,
  '>=': 3,
  '+': 4,
  '-': 4,
  '*': 5,
  'DIV': 5,
  'MOD': 5,
};

List<String> _lex(String s) => RegExp(r'\d+|[A-Za-z_]\w*|!=|<=|>=|[-+*()=<>]')
    .allMatches(s)
    .map((m) => m.group(0)!)
    .toList();

/// Nilai teks ekspresi atau kondisi. Melempar [StateError] bila tidak
/// terdefinisi (variabel kosong, DIV atau MOD di luar ranah).
int naiveEval(String text, Map<String, int> vars) {
  final out = <Object>[]; // Notasi pascatetap: int, String variabel, operator.
  final ops = <String>[];
  var expectOperand = true;
  for (final t in _lex(text)) {
    if (expectOperand) {
      if (t == '(') {
        ops.add(t);
      } else if (t == '-') {
        ops.add('neg');
      } else {
        out.add(int.tryParse(t) ?? 'var:$t');
        expectOperand = false;
      }
      continue;
    }
    if (t == ')') {
      while (ops.last != '(') {
        out.add(ops.removeLast());
      }
      ops.removeLast();
      continue;
    }
    final p = _prec[t] ?? (throw StateError('operator $t'));
    while (ops.isNotEmpty &&
        ops.last != '(' &&
        (ops.last == 'neg' || _prec[ops.last]! >= p)) {
      out.add(ops.removeLast());
    }
    ops.add(t);
    expectOperand = true;
  }
  while (ops.isNotEmpty) {
    out.add(ops.removeLast());
  }

  final stack = <int>[];
  for (final item in out) {
    if (item is int) {
      stack.add(item);
    } else if ((item as String).startsWith('var:')) {
      stack.add(vars[item.substring(4)] ?? (throw StateError('kosong')));
    } else if (item == 'neg') {
      stack.add(-stack.removeLast());
    } else {
      final b = stack.removeLast();
      final a = stack.removeLast();
      stack.add(switch (item) {
        '+' => a + b,
        '-' => a - b,
        '*' => a * b,
        'DIV' || 'MOD' when a < 0 || b <= 0 => throw StateError('ranah'),
        'DIV' => a ~/ b,
        'MOD' => a % b,
        '=' => a == b ? 1 : 0,
        '!=' => a != b ? 1 : 0,
        '<' => a < b ? 1 : 0,
        '>' => a > b ? 1 : 0,
        '<=' => a <= b ? 1 : 0,
        '>=' => a >= b ? 1 : 0,
        'DAN' => a != 0 && b != 0 ? 1 : 0,
        'ATAU' => a != 0 || b != 0 ? 1 : 0,
        _ => throw StateError('operator $item'),
      });
    }
  }
  if (stack.length != 1) throw StateError('ekspresi rusak');
  return stack.single;
}

/// Jawaban soal IT-FLW sebagai teks opsi, atau null.
String? naiveFlwAnswer(Question q) {
  final table = q.stem.figure;
  if (table is! TableFigure) return null;
  final ask = (q.stem.text ?? '').split('\n').last;
  final vars = <String, int>{};
  final path = <int>[];
  final shown = <int>[];
  var at = 1;
  try {
    while (at != 0) {
      if (path.length > 500) return null;
      path.add(at);
      final row = table.rows[at - 1];
      final box = row[1];
      final next = row[2];
      int go(String s) => s == 'SELESAI' ? 0 : int.parse(s);
      if (box.endsWith(' ?')) {
        final yesNo = RegExp(r'Ya: (\w+), Tidak: (\w+)').firstMatch(next)!;
        final ok = naiveEval(box.substring(0, box.length - 2), vars) != 0;
        at = go(yesNo.group(ok ? 1 : 2)!);
      } else if (box.startsWith('TAMPILKAN ')) {
        shown.add(naiveEval(box.substring(10), vars));
        at = go(next);
      } else {
        final eq = box.indexOf(' := ');
        vars[box.substring(0, eq)] = naiveEval(box.substring(eq + 4), vars);
        at = go(next);
      }
    }
  } on StateError {
    return null;
  }
  if (ask == 'Berapa nilai yang ditampilkan?') {
    return shown.length == 1 ? '${shown.single}' : null;
  }
  if (ask == 'Urutan kotak mana yang dilewati?') return path.join(', ');
  final m = RegExp(r'kotak (\d+) dijalankan').firstMatch(ask);
  if (m == null) return null;
  final node = int.parse(m.group(1)!);
  return '${path.where((n) => n == node).length}';
}
