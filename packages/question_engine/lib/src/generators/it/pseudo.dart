/// Pseudocode mini untuk IT-PSE (docs/06-bank-konten.md, "Katalog tipe soal").
///
/// Bahasa: bilangan bulat saja; penugasan `x := e`; `JIKA c MAKA` dengan
/// `LAINNYA` pilihan; `SELAMA c LAKUKAN`; `ULANGI v DARI a SAMPAI b` (batas
/// kedua ikut, dihitung sekali di awal); `TAMPILKAN e`. Blok ditandai
/// indentasi dua spasi. Ekspresi: `+ - * DIV MOD`, kurung, minus di depan.
/// Kondisi: perbandingan `= != < > <= >=` yang digabung `DAN` dan `ATAU`
/// (`DAN` mengikat lebih kuat).
///
/// DIV dan MOD hanya terdefinisi untuk pembilang tak negatif dan penyebut
/// positif; selain itu interpreter melempar [PseudoError] supaya tidak ada
/// soal yang bergantung pada konvensi pembulatan. Interpreter menghitung
/// langkah dan berhenti di [PseudoLimits.maxSteps], jadi tidak ada loop tak
/// hingga. Semuanya deterministik dan Dart murni.
library;

/// Kesalahan program (sintaks, variabel belum ada, bagi nol, melewati batas).
class PseudoError implements Exception {
  const PseudoError(this.message);

  final String message;

  @override
  String toString() => 'PseudoError($message)';
}

final class StepLimitExceeded extends PseudoError {
  const StepLimitExceeded() : super('melewati batas langkah');
}

abstract final class PseudoLimits {
  /// Satu langkah = satu pernyataan atau satu putaran loop dijalankan.
  static const int maxSteps = 2000;

  /// Nilai variabel dan hasil antara dibatasi agar tetap eksak di web.
  static const int maxMagnitude = 1000000;
}

// ---------------------------------------------------------------------------
// Ekspresi dan kondisi
// ---------------------------------------------------------------------------

sealed class PsExpr {
  const PsExpr();

  /// Teks kanonik; [parseExpr] mengembalikan ekspresi yang sama.
  String render();

  /// Prioritas untuk kurung otomatis: 1 tambah/kurang, 2 kali/bagi, 3 atom.
  int get precedence;
}

final class PsNum extends PsExpr {
  const PsNum(this.value);

  final int value;

  @override
  String render() => '$value';

  @override
  int get precedence => value < 0 ? 0 : 3;
}

final class PsVar extends PsExpr {
  const PsVar(this.name);

  final String name;

  @override
  String render() => name;

  @override
  int get precedence => 3;
}

final class PsBin extends PsExpr {
  const PsBin(this.op, this.left, this.right);

  /// `+ - * DIV MOD`.
  final String op;
  final PsExpr left;
  final PsExpr right;

  @override
  int get precedence => (op == '+' || op == '-') ? 1 : 2;

  @override
  String render() {
    // Operan kiri butuh kurung bila prioritasnya lebih rendah; operan kanan
    // juga bila setara, karena semua operator asosiatif kiri.
    final l =
        left.precedence < precedence ? '(${left.render()})' : left.render();
    final r =
        right.precedence <= precedence ? '(${right.render()})' : right.render();
    return '$l $op $r';
  }
}

sealed class PsCond {
  const PsCond();

  String render();
}

final class PsCmp extends PsCond {
  const PsCmp(this.op, this.left, this.right);

  /// `= != < > <= >=`.
  final String op;
  final PsExpr left;
  final PsExpr right;

  @override
  String render() => '${left.render()} $op ${right.render()}';
}

final class PsAndCond extends PsCond {
  const PsAndCond(this.parts);

  final List<PsCond> parts;

  @override
  String render() => parts.map((p) => p.render()).join(' DAN ');
}

final class PsOrCond extends PsCond {
  const PsOrCond(this.parts);

  final List<PsCond> parts;

  @override
  String render() => parts.map((p) => p.render()).join(' ATAU ');
}

// ---------------------------------------------------------------------------
// Pernyataan
// ---------------------------------------------------------------------------

sealed class PsStmt {
  const PsStmt();
}

final class PsAssign extends PsStmt {
  const PsAssign(this.name, this.value);

  final String name;
  final PsExpr value;
}

final class PsShow extends PsStmt {
  const PsShow(this.value);

  final PsExpr value;
}

final class PsIf extends PsStmt {
  const PsIf(this.cond, this.then, [this.otherwise = const []]);

  final PsCond cond;
  final List<PsStmt> then;
  final List<PsStmt> otherwise;
}

final class PsWhile extends PsStmt {
  const PsWhile(this.cond, this.body);

  final PsCond cond;
  final List<PsStmt> body;
}

final class PsFor extends PsStmt {
  const PsFor(this.name, this.from, this.to, this.body);

  final String name;
  final PsExpr from;
  final PsExpr to;
  final List<PsStmt> body;
}

typedef PsProgram = List<PsStmt>;

/// Baris kode program, satu per pernyataan atau kepala blok, dengan
/// indentasi dua spasi per tingkat.
List<String> psRenderProgram(PsProgram program) {
  final out = <String>[];
  void block(List<PsStmt> stmts, int depth) {
    final pad = '  ' * depth;
    for (final s in stmts) {
      switch (s) {
        case PsAssign():
          out.add('$pad${s.name} := ${s.value.render()}');
        case PsShow():
          out.add('${pad}TAMPILKAN ${s.value.render()}');
        case PsIf():
          out.add('${pad}JIKA ${s.cond.render()} MAKA');
          block(s.then, depth + 1);
          if (s.otherwise.isNotEmpty) {
            out.add('${pad}LAINNYA');
            block(s.otherwise, depth + 1);
          }
        case PsWhile():
          out.add('${pad}SELAMA ${s.cond.render()} LAKUKAN');
          block(s.body, depth + 1);
        case PsFor():
          out.add('${pad}ULANGI ${s.name} DARI ${s.from.render()} '
              'SAMPAI ${s.to.render()}');
          block(s.body, depth + 1);
      }
    }
  }

  block(program, 0);
  return out;
}

/// Teks satu pernyataan sederhana atau kepala blok (tanpa indentasi), untuk
/// pertanyaan "berapa kali baris ... dijalankan".
String psStmtHead(PsStmt s) => switch (s) {
      PsAssign() => '${s.name} := ${s.value.render()}',
      PsShow() => 'TAMPILKAN ${s.value.render()}',
      PsIf() => 'JIKA ${s.cond.render()} MAKA',
      PsWhile() => 'SELAMA ${s.cond.render()} LAKUKAN',
      PsFor() => 'ULANGI ${s.name} DARI ${s.from.render()} '
          'SAMPAI ${s.to.render()}',
    };

// ---------------------------------------------------------------------------
// Pengurai
// ---------------------------------------------------------------------------

final RegExp _token = RegExp(
  r'\s*(?:(\d+)|([A-Za-z_][A-Za-z_0-9]*)|(:=|!=|<=|>=|[-+*()=<>]))',
);

final class _Tokens {
  _Tokens(String text) {
    var pos = 0;
    final t = text.trimRight();
    while (pos < t.length) {
      final m = _token.matchAsPrefix(t, pos);
      if (m == null || m.end == pos) {
        throw PseudoError('karakter tak dikenal di "$text"');
      }
      pos = m.end;
      items.add(m.group(1) ?? m.group(2) ?? m.group(3)!);
    }
  }

  final List<String> items = [];
  int i = 0;

  bool get done => i >= items.length;
  String? get peek => done ? null : items[i];

  String next() {
    if (done) throw const PseudoError('ekspresi terpotong');
    return items[i++];
  }

  bool take(String t) {
    if (peek == t) {
      i++;
      return true;
    }
    return false;
  }

  void expect(String t) {
    if (!take(t)) {
      throw PseudoError('mengharapkan "$t", dapat "${peek ?? 'akhir'}"');
    }
  }
}

const Set<String> _keywords = {
  'JIKA',
  'MAKA',
  'LAINNYA',
  'SELAMA',
  'LAKUKAN',
  'ULANGI',
  'DARI',
  'SAMPAI',
  'TAMPILKAN',
  'DAN',
  'ATAU',
  'DIV',
  'MOD',
};

PsExpr _parseExpr(_Tokens t) {
  var left = _parseTerm(t);
  while (t.peek == '+' || t.peek == '-') {
    final op = t.next();
    left = PsBin(op, left, _parseTerm(t));
  }
  return left;
}

PsExpr _parseTerm(_Tokens t) {
  var left = _parseFactor(t);
  while (t.peek == '*' || t.peek == 'DIV' || t.peek == 'MOD') {
    final op = t.next();
    left = PsBin(op, left, _parseFactor(t));
  }
  return left;
}

PsExpr _parseFactor(_Tokens t) {
  final tok = t.next();
  if (tok == '(') {
    final e = _parseExpr(t);
    t.expect(')');
    return e;
  }
  if (tok == '-') {
    final f = _parseFactor(t);
    return f is PsNum ? PsNum(-f.value) : PsBin('-', const PsNum(0), f);
  }
  final n = int.tryParse(tok);
  if (n != null) return PsNum(n);
  if (_keywords.contains(tok) || !RegExp(r'^[A-Za-z_]').hasMatch(tok)) {
    throw PseudoError('tidak bisa dibaca sebagai nilai: "$tok"');
  }
  return PsVar(tok);
}

PsCond _parseCond(_Tokens t) {
  final ors = <PsCond>[_parseAnd(t)];
  while (t.take('ATAU')) {
    ors.add(_parseAnd(t));
  }
  return ors.length == 1 ? ors.single : PsOrCond(ors);
}

PsCond _parseAnd(_Tokens t) {
  final ands = <PsCond>[_parseCmp(t)];
  while (t.take('DAN')) {
    ands.add(_parseCmp(t));
  }
  return ands.length == 1 ? ands.single : PsAndCond(ands);
}

const Set<String> _cmpOps = {'=', '!=', '<', '>', '<=', '>='};

PsCond _parseCmp(_Tokens t) {
  final left = _parseExpr(t);
  final op = t.next();
  if (!_cmpOps.contains(op)) throw PseudoError('operator banding salah: "$op"');
  return PsCmp(op, left, _parseExpr(t));
}

/// Ekspresi dari teks; melempar [PseudoError] bila bukan ekspresi utuh.
PsExpr psParseExpr(String text) {
  final t = _Tokens(text);
  final e = _parseExpr(t);
  if (!t.done) throw PseudoError('sisa teks setelah ekspresi: "${t.peek}"');
  return e;
}

/// Kondisi dari teks; melempar [PseudoError] bila bukan kondisi utuh.
PsCond psParseCond(String text) {
  final t = _Tokens(text);
  final c = _parseCond(t);
  if (!t.done) throw PseudoError('sisa teks setelah kondisi: "${t.peek}"');
  return c;
}

/// Program dari baris-baris berindentasi dua spasi.
PsProgram psParseProgram(List<String> lines) {
  final src = [
    for (final l in lines)
      if (l.trim().isNotEmpty) l.trimRight(),
  ];
  var pos = 0;

  int depthOf(String line) {
    var spaces = 0;
    while (spaces < line.length && line[spaces] == ' ') {
      spaces++;
    }
    if (spaces.isOdd) throw PseudoError('indentasi ganjil: "$line"');
    return spaces ~/ 2;
  }

  late final PsStmt Function(String text, int depth) statement;

  List<PsStmt> block(int depth) {
    final out = <PsStmt>[];
    while (pos < src.length) {
      final line = src[pos];
      final d = depthOf(line);
      if (d < depth) break;
      if (d > depth) throw PseudoError('indentasi tak terduga: "$line"');
      final text = line.trim();
      pos++;
      out.add(statement(text, depth));
    }
    return out;
  }

  List<PsStmt> child(int depth, String head) {
    final body = block(depth + 1);
    if (body.isEmpty) throw PseudoError('blok kosong setelah "$head"');
    return body;
  }

  statement = (String text, int depth) {
    if (text.startsWith('JIKA ')) {
      if (!text.endsWith(' MAKA')) {
        throw PseudoError('JIKA tanpa MAKA: "$text"');
      }
      final cond = psParseCond(text.substring(5, text.length - 5));
      final then = child(depth, text);
      var otherwise = const <PsStmt>[];
      if (pos < src.length &&
          depthOf(src[pos]) == depth &&
          src[pos].trim() == 'LAINNYA') {
        pos++;
        otherwise = child(depth, 'LAINNYA');
      }
      return PsIf(cond, then, otherwise);
    }
    if (text.startsWith('SELAMA ')) {
      if (!text.endsWith(' LAKUKAN')) {
        throw PseudoError('SELAMA tanpa LAKUKAN: "$text"');
      }
      final cond = psParseCond(text.substring(7, text.length - 8));
      return PsWhile(cond, child(depth, text));
    }
    if (text.startsWith('ULANGI ')) {
      final m =
          RegExp(r'^ULANGI ([A-Za-z_][A-Za-z_0-9]*) DARI (.+) SAMPAI (.+)$')
              .firstMatch(text);
      if (m == null) throw PseudoError('ULANGI salah bentuk: "$text"');
      return PsFor(m.group(1)!, psParseExpr(m.group(2)!),
          psParseExpr(m.group(3)!), child(depth, text));
    }
    if (text.startsWith('TAMPILKAN ')) {
      return PsShow(psParseExpr(text.substring(10)));
    }
    final m = RegExp(r'^([A-Za-z_][A-Za-z_0-9]*) := (.+)$').firstMatch(text);
    if (m == null || _keywords.contains(m.group(1))) {
      throw PseudoError('pernyataan tak dikenal: "$text"');
    }
    return PsAssign(m.group(1)!, psParseExpr(m.group(2)!));
  };

  final program = block(0);
  if (pos != src.length) throw PseudoError('baris tak terbaca: "${src[pos]}"');
  return program;
}

// ---------------------------------------------------------------------------
// Interpreter
// ---------------------------------------------------------------------------

/// Hasil menjalankan program.
final class PseudoRun {
  PseudoRun(this.variables, this.output, this.steps, this.executions);

  /// Nilai akhir tiap variabel.
  final Map<String, int> variables;

  /// Nilai yang ditampilkan, berurutan.
  final List<int> output;

  /// Banyak langkah yang dipakai.
  final int steps;

  /// Berapa kali pernyataan dengan [psStmtHead] tertentu dijalankan. Kepala
  /// `JIKA` dan `SELAMA` dihitung tiap kali kondisinya diperiksa; `ULANGI`
  /// dihitung sekali per masuk loop (bukan per putaran).
  final Map<String, int> executions;
}

int _checked(int v) {
  if (v.abs() > PseudoLimits.maxMagnitude) {
    throw const PseudoError('nilai terlalu besar');
  }
  return v;
}

/// Nilai ekspresi dengan isi variabel [vars]. Melempar [PseudoError].
int psEval(PsExpr e, Map<String, int> vars) => switch (e) {
      PsNum() => e.value,
      PsVar() => vars[e.name] ?? (throw PseudoError('${e.name} belum diisi')),
      PsBin() =>
        _apply(e.op, psEval(e.left, vars), psEval(e.right, vars), _checked),
    };

/// Nilai kebenaran kondisi dengan isi variabel [vars].
bool psTest(PsCond c, Map<String, int> vars) => switch (c) {
      PsCmp() => _compare(c.op, psEval(c.left, vars), psEval(c.right, vars)),
      PsAndCond() => c.parts.every((p) => psTest(p, vars)),
      PsOrCond() => c.parts.any((p) => psTest(p, vars)),
    };

/// Menjalankan [program]. Melempar [PseudoError] atau [StepLimitExceeded].
PseudoRun psRunProgram(PsProgram program) {
  final vars = <String, int>{};
  final output = <int>[];
  final executions = <String, int>{};
  var steps = 0;

  void tick() {
    if (++steps > PseudoLimits.maxSteps) throw const StepLimitExceeded();
  }

  int checked(int v) => _checked(v);
  int eval(PsExpr e) => psEval(e, vars);
  bool test(PsCond c) => psTest(c, vars);

  void count(PsStmt s) {
    final k = psStmtHead(s);
    executions[k] = (executions[k] ?? 0) + 1;
  }

  void exec(List<PsStmt> stmts) {
    for (final s in stmts) {
      tick();
      count(s);
      switch (s) {
        case PsAssign():
          vars[s.name] = checked(eval(s.value));
        case PsShow():
          output.add(eval(s.value));
        case PsIf():
          exec(test(s.cond) ? s.then : s.otherwise);
        case PsWhile():
          while (test(s.cond)) {
            exec(s.body);
            tick();
            // Pemeriksaan kondisi berikutnya dihitung sebagai eksekusi
            // kepala SELAMA yang sama.
            count(s);
          }
        case PsFor():
          final from = eval(s.from);
          final to = eval(s.to);
          for (var v = from; v <= to; v++) {
            vars[s.name] = v;
            tick();
            exec(s.body);
          }
      }
    }
  }

  exec(program);
  return PseudoRun(vars, output, steps, executions);
}

int _apply(String op, int a, int b, int Function(int) checked) {
  switch (op) {
    case '+':
      return checked(a + b);
    case '-':
      return checked(a - b);
    case '*':
      return checked(a * b);
    case 'DIV':
    case 'MOD':
      if (a < 0 || b <= 0) {
        throw PseudoError('$op hanya untuk pembilang >= 0 dan penyebut > 0');
      }
      return op == 'DIV' ? a ~/ b : a % b;
  }
  throw PseudoError('operator tak dikenal: $op');
}

bool _compare(String op, int a, int b) => switch (op) {
      '=' => a == b,
      '!=' => a != b,
      '<' => a < b,
      '>' => a > b,
      '<=' => a <= b,
      '>=' => a >= b,
      _ => throw PseudoError('operator banding tak dikenal: $op'),
    };
