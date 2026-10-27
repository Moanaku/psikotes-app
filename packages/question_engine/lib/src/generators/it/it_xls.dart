/// Generator IT-XLS (rumus Excel), docs/06-bank-konten.md.
///
/// Stem: tabel lembar kerja ([Sheet], kolom A sampai C, baris 1 berisi judul
/// data) dan tiga baris teks: pengantar tetap, rumus di sel E1, pertanyaan
/// tetap. Solver mengurai rumus dan menghitungnya dari isi tabel dengan
/// aritmetika pecahan eksak (`sheet.dart`).
///
/// Pengecoh: rumus yang diubah satu bagian, terutama rentang sel yang salah
/// (ujung rentang bergeser satu baris, kolom tertukar), batas kriteria
/// (">=" jadi ">"), dan nomor kolom VLOOKUP yang meleset.
library;

import '../../fraction.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'sheet.dart';

const String xlsIntro = 'Tabel berikut adalah lembar kerja Excel. Sel E1 '
    'berisi rumus:';

const String xlsQuestion = 'Berapa hasil yang tampil di E1?';

final class ItXlsSolver implements QuestionSolver {
  const ItXlsSolver();

  /// Teks hasil rumus; null bila stem tidak sah.
  static String? answerOf(Question q) {
    final sheet = Sheet.fromTable(q.stem.figure);
    final lines = (q.stem.text ?? '').split('\n');
    if (sheet == null ||
        lines.length != 3 ||
        lines[0] != xlsIntro ||
        lines[2] != xlsQuestion) {
      return null;
    }
    try {
      return evalFormula(parseFormula(lines[1]), sheet).display();
    } on XlsSyntaxError {
      return null;
    } on FractionOverflow {
      return null;
    }
  }

  @override
  List<int> validOptions(Question question) {
    final answer = answerOf(question);
    if (answer == null) return const [];
    return [
      for (var i = 0; i < question.options.length; i++)
        if (question.options[i].content.text?.trim() == answer) i,
    ];
  }
}

// ---------------------------------------------------------------------------
// Perubahan satu bagian (pengecoh)
// ---------------------------------------------------------------------------

/// Semua rumus yang berbeda satu bagian dari [e].
List<XlsExpr> xlsMutants(XlsExpr e) {
  final out = <XlsExpr>[];
  final counter = _XlsMutator(-1, 0)..apply(e);
  for (var site = 0; site < counter.seen; site++) {
    for (var variant = 0; variant < 4; variant++) {
      final m = _XlsMutator(site, variant);
      final mutated = m.apply(e);
      if (m.applied) out.add(mutated);
    }
  }
  return out;
}

final class _XlsMutator {
  _XlsMutator(this.target, this.variant);

  final int target;
  final int variant;
  int seen = 0;
  bool applied = false;

  bool _hit() => seen++ == target;

  static String _shift(String op) => switch (op) {
        '<' => '<=',
        '<=' => '<',
        '>' => '>=',
        '>=' => '>',
        '=' => '<>',
        '<>' => '=',
        _ => op,
      };

  XlsExpr apply(XlsExpr e) {
    switch (e) {
      case XlsNum():
        if (_hit() && variant < 2) {
          applied = true;
          return XlsNum(e.value + (variant == 0 ? 1 : -1));
        }
        return e;
      case XlsStr():
        // Kriteria COUNTIF: batas bergeser (">=70" jadi ">70").
        final m = RegExp(r'^(<=|>=|<|>)(\d+)$').firstMatch(e.value);
        if (_hit() && m != null && variant == 0) {
          applied = true;
          return XlsStr('${_shift(m.group(1)!)}${m.group(2)}');
        }
        return e;
      case XlsFalse():
        return e;
      case XlsRef():
        if (_hit()) {
          applied = true;
          return switch (variant) {
            0 => XlsRef(e.col, e.row + 1),
            1 => XlsRef(e.col, e.row - 1),
            2 => XlsRef(e.col == 1 ? 2 : 1, e.row),
            _ => (applied = false, e).$2,
          };
        }
        return e;
      case XlsRange():
        if (_hit()) {
          applied = true;
          // Rentang sel salah: satu ujung bergeser, atau kolom tertukar.
          return switch (variant) {
            0 => XlsRange(e.col1, e.row1 + 1, e.col2, e.row2),
            1 => XlsRange(e.col1, e.row1, e.col2, e.row2 - 1),
            2 => XlsRange(e.col1, e.row1, e.col2, e.row2 + 1),
            _ => e.col1 == e.col2 && e.col1 > 0
                ? XlsRange(
                    e.col1 == 1 ? 2 : 1, e.row1, e.col2 == 1 ? 2 : 1, e.row2)
                : (applied = false, e).$2,
          };
        }
        return e;
      case XlsBin():
        final left = apply(e.left);
        final right = apply(e.right);
        var op = e.op;
        if (_hit() && variant == 0 && XlsBin.isCompare(op)) {
          op = _shift(op);
          applied = true;
        }
        return XlsBin(op, left, right);
      case XlsCall():
        return XlsCall(e.name, [for (final a in e.args) apply(a)]);
    }
  }
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

int _between(Rng rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

XlsExpr _ref(int col, int row) => XlsRef(col, row);
XlsExpr _range(int col, int r1, int r2) => XlsRange(col, r1, col, r2);
XlsExpr _call(String name, List<XlsExpr> args) => XlsCall(name, args);
XlsExpr _bin(String op, XlsExpr a, XlsExpr b) => XlsBin(op, a, b);

/// Data lembar kerja: judul kolom A, B, C dan isi baris 2 dan seterusnya.
final class _Data {
  const _Data(this.sheet, this.dataRows, this.labels);

  final Sheet sheet;

  /// Banyak baris data (baris 2 sampai dataRows + 1).
  final int dataRows;

  /// Label kolom A berurutan, untuk kunci VLOOKUP.
  final List<String> labels;

  int get last => dataRows + 1;
}

final class _XlsDraft {
  const _XlsDraft(this.template, this.data, this.formula, {this.labels});

  final String template;
  final _Data data;
  final XlsExpr formula;

  /// Untuk jawaban teks: semua label yang mungkin dihasilkan rumus.
  final List<String>? labels;
}

final class ItXlsGenerator extends RetryingGenerator {
  const ItXlsGenerator();

  @override
  QuestionType get type => QuestionType.itXls;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const ItXlsSolver();

  static const int optionCount = 4;

  static const List<String> _names = [
    'Ani', 'Budi', 'Citra', 'Dewi', 'Eka', 'Fajar', 'Gita', 'Hadi', //
  ];
  static const List<String> _products = [
    'Kabel',
    'Mouse',
    'Router',
    'Webcam',
    'Headset',
    'Monitor',
    'Printer',
  ];
  static const List<String> _modules = [
    'Login',
    'Profil',
    'Bayar',
    'Laporan',
    'Cari',
    'Admin',
    'Notifikasi',
  ];

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final draft = _draft(rng, difficulty);
    final sheet = draft.data.sheet;
    final XlsValue value;
    try {
      value = evalFormula(draft.formula, sheet);
    } on FractionOverflow {
      return null;
    }
    final String answer;
    switch (value) {
      case XlsNumber(value: final v):
        if (v.isNegative || v.toDecimal() == null) return null;
        answer = value.display();
      case XlsText():
        answer = value.display();
      default:
        return null;
    }

    final distractors = draft.labels != null
        ? _textDistractors(rng, draft.labels!, answer)
        : _numberDistractors(rng, draft, value as XlsNumber);
    if (distractors == null) return null;
    final assembled = assembleOptions(
      rng,
      QuestionContent(text: answer),
      [for (final d in distractors) QuestionContent(text: d)],
    );
    final formula = renderFormula(draft.formula);
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(
        text: '$xlsIntro\n$formula\n$xlsQuestion',
        figure: sheet.toTable(),
      ),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: '$formula menghasilkan $answer. ${_explain(draft)}',
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 45,
        Difficulty.medium => 75,
        Difficulty.hard => 110,
      },
      tags: ['rule:it-xls:${draft.template}'],
    );
  }

  List<String>? _textDistractors(Rng rng, List<String> labels, String answer) {
    final others = [
      for (final l in labels)
        if (l != answer) l,
      XlsError.na.code,
    ];
    final picked = rng.shuffle(others).take(optionCount - 1).toList();
    return picked.length == optionCount - 1 ? picked : null;
  }

  List<String>? _numberDistractors(Rng rng, _XlsDraft draft, XlsNumber value) {
    final answer = value.display();
    final pool = <String>{};
    for (final m in rng.shuffle(xlsMutants(draft.formula))) {
      final XlsValue v;
      try {
        v = evalFormula(m, draft.data.sheet);
      } on FractionOverflow {
        continue;
      }
      if (v is XlsNumber &&
          !v.value.isNegative &&
          v.value.toDecimal() != null) {
        pool.add(v.display());
      }
    }
    pool.remove(answer);
    final picked = rng.shuffle(pool.toList()).take(optionCount - 1).toList();
    if (picked.length < optionCount - 1) {
      final step = value.value.isInteger ? Fraction.one : Fraction(1, 2);
      final spare = <String>[];
      for (var k = 1; k <= 4; k++) {
        for (final sign in [1, -1]) {
          final v = value.value + step * Fraction(sign * k);
          if (!v.isNegative) spare.add(XlsNumber(v).display());
        }
      }
      for (final s in rng.shuffle(spare)) {
        if (picked.length == optionCount - 1) break;
        if (s != answer && !picked.contains(s)) picked.add(s);
      }
    }
    return picked.length == optionCount - 1 ? picked : null;
  }

  String _explain(_XlsDraft draft) => switch (draft.template) {
        'sum' => 'SUM menjumlahkan semua angka di rentang, termasuk sel '
            'pertama dan terakhir.',
        'countif' => 'COUNTIF menghitung sel di rentang yang memenuhi '
            'kriteria; perhatikan beda ">" dan ">=".',
        'if' => 'IF memeriksa kondisinya lebih dulu, lalu mengambil nilai '
            'kedua bila benar atau nilai ketiga bila salah.',
        'vlookup' => 'VLOOKUP mencari baris dengan kunci yang sama di kolom '
            'pertama rentang, lalu mengambil kolom ke-n dari rentang itu.',
        'rata-rata' => 'Jumlahkan rentangnya dulu, baru bagi.',
        'countif-teks' => 'COUNTIF dengan teks menghitung sel yang isinya sama '
            'persis, tanpa membedakan huruf besar.',
        'kali-silang' => 'Kali dulu tiap pasangan sel, baru jumlahkan.',
        'if-sum' => 'Hitung kedua SUM dulu, lalu bandingkan untuk memilih '
            'cabang IF.',
        'vlookup-kali' => 'Ambil kedua nilai dengan VLOOKUP pada baris yang '
            'sama, lalu kalikan.',
        _ => 'Kerjakan VLOOKUP lebih dulu, lalu periksa kondisi IF dari luar '
            'ke dalam.',
      };

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  /// Tabel nilai: Nama, Nilai (50-100), Hadir (6-16) atau Status.
  _Data _scores(Rng rng, {bool status = false, int? rows}) {
    final n = rows ?? _between(rng, 4, 7);
    final names = rng.shuffle(_names).take(n).toList();
    final pass = _between(rng, 65, 75);
    final cells = <String, String>{
      'A1': 'Nama',
      'B1': 'Nilai',
      'C1': status ? 'Status' : 'Hadir',
    };
    for (var i = 0; i < n; i++) {
      final score = _between(rng, 50, 100);
      cells['A${i + 2}'] = names[i];
      cells['B${i + 2}'] = '$score';
      cells['C${i + 2}'] = status
          ? (score >= pass ? 'Lulus' : 'Remedial')
          : '${_between(rng, 6, 16)}';
    }
    return _Data(Sheet(cells), n, names);
  }

  /// Tabel penjualan: Produk, Harga (ribu rupiah, kadang ,5), Terjual.
  _Data _sales(Rng rng, {bool decimals = false}) {
    final n = _between(rng, 4, 7);
    final items = rng.shuffle(_products).take(n).toList();
    final cells = <String, String>{
      'A1': 'Produk',
      'B1': 'Harga',
      'C1': 'Terjual',
    };
    for (var i = 0; i < n; i++) {
      final half = decimals && rng.nextBool();
      cells['A${i + 2}'] = items[i];
      cells['B${i + 2}'] = '${_between(rng, 5, 95)}${half ? ',5' : ''}';
      cells['C${i + 2}'] = '${_between(rng, 1, 30)}';
    }
    return _Data(Sheet(cells), n, items);
  }

  /// Tabel bug: Modul, Bug, Selesai.
  _Data _bugs(Rng rng) {
    final n = _between(rng, 4, 7);
    final mods = rng.shuffle(_modules).take(n).toList();
    final cells = <String, String>{'A1': 'Modul', 'B1': 'Bug', 'C1': 'Selesai'};
    for (var i = 0; i < n; i++) {
      final bugs = _between(rng, 2, 20);
      cells['A${i + 2}'] = mods[i];
      cells['B${i + 2}'] = '$bugs';
      cells['C${i + 2}'] = '${_between(rng, 0, bugs)}';
    }
    return _Data(Sheet(cells), n, mods);
  }

  _Data _anyNumeric(Rng rng) => switch (rng.nextInt(3)) {
        0 => _scores(rng),
        1 => _sales(rng),
        _ => _bugs(rng),
      };

  /// Nilai numerik sel (kolom 1 atau 2, baris data).
  Fraction _num(_Data d, int col, int row) =>
      (d.sheet.at(col, row)! as XlsNumber).value;

  // -------------------------------------------------------------------------
  // Templat rumus
  // -------------------------------------------------------------------------

  _XlsDraft _draft(Rng rng, Difficulty d) {
    final templates = switch (d) {
      Difficulty.easy => [_sum, _countIf, _if],
      Difficulty.medium => [_vlookup, _average, _countText, _crossProduct],
      Difficulty.hard => [_ifSum, _vlookupProduct, _nestedIf],
    };
    return templates[rng.nextInt(templates.length)](rng);
  }

  /// Rentang sebagian atau seluruh baris data di satu kolom.
  (int, int) _span(Rng rng, _Data d, {int min = 2}) {
    final r1 = _between(rng, 2, d.last - min + 1);
    final r2 = _between(rng, r1 + min - 1, d.last);
    return (r1, r2);
  }

  _XlsDraft _sum(Rng rng) {
    final d = _anyNumeric(rng);
    final (r1, r2) = _span(rng, d, min: 3);
    final col = _between(rng, 1, 2);
    return _XlsDraft('sum', d, _call('SUM', [_range(col, r1, r2)]));
  }

  _XlsDraft _countIf(Rng rng) {
    final d = _anyNumeric(rng);
    final col = _between(rng, 1, 2);
    // Ambang sama dengan salah satu nilai di rentang, supaya ">" dan ">="
    // memberi hasil berbeda.
    final pivot = _num(d, col, _between(rng, 2, d.last));
    if (!pivot.isInteger) return _sum(rng);
    final op = rng.pick(['>=', '>', '<', '<=']);
    return _XlsDraft(
      'countif',
      d,
      _call('COUNTIF', [_range(col, 2, d.last), XlsStr('$op${pivot.num}')]),
    );
  }

  _XlsDraft _if(Rng rng) {
    final d = _scores(rng);
    final row = _between(rng, 2, d.last);
    final limit = _between(rng, 60, 85);
    final bonus = _between(rng, 2, 10);
    return _XlsDraft(
      'if',
      d,
      _call('IF', [
        _bin(rng.pick(['>=', '>', '<']), _ref(1, row), XlsNum(limit)),
        _bin('+', _ref(1, row), XlsNum(bonus)),
        _bin('-', _ref(1, row), XlsNum(bonus)),
      ]),
    );
  }

  XlsExpr _lookup(_Data d, String key, int col) => _call('VLOOKUP', [
        XlsStr(key),
        XlsRange(0, 2, 2, d.last),
        XlsNum(col),
        const XlsFalse(),
      ]);

  _XlsDraft _vlookup(Rng rng) {
    final d = _anyNumeric(rng);
    final key = rng.pick(d.labels);
    return _XlsDraft('vlookup', d, _lookup(d, key, _between(rng, 2, 3)));
  }

  _XlsDraft _average(Rng rng) {
    final d = _sales(rng, decimals: true);
    // Pembagi 2, 4, atau 5: rata-rata harga berakhiran ,5 tetap paling
    // banyak dua angka di belakang koma.
    final count = rng.pick([
      for (final c in const [2, 4, 5])
        if (c <= d.dataRows) c,
    ]);
    final r1 = _between(rng, 2, d.last - count + 1);
    final r2 = r1 + count - 1;
    final col = _between(rng, 1, 2);
    return _XlsDraft(
      'rata-rata',
      d,
      _bin('/', _call('SUM', [_range(col, r1, r2)]), XlsNum(count)),
    );
  }

  _XlsDraft _countText(Rng rng) {
    final d = _scores(rng, status: true);
    final what = rng.pick(['Lulus', 'Remedial']);
    return _XlsDraft(
      'countif-teks',
      d,
      _call('COUNTIF', [_range(2, 2, d.last), XlsStr(what)]),
    );
  }

  _XlsDraft _crossProduct(Rng rng) {
    final d = _sales(rng);
    final rows = rng.shuffle([for (var r = 2; r <= d.last; r++) r]);
    return _XlsDraft(
      'kali-silang',
      d,
      _bin(
        '+',
        _bin('*', _ref(1, rows[0]), _ref(2, rows[0])),
        _bin('*', _ref(1, rows[1]), _ref(2, rows[1])),
      ),
    );
  }

  _XlsDraft _ifSum(Rng rng) {
    final d = _scores(rng, rows: _between(rng, 6, 7));
    final mid = d.last ~/ 2 + 1;
    final first = _call('SUM', [_range(1, 2, mid)]);
    final second = _call('SUM', [_range(1, mid + 1, d.last)]);
    // Cabang benar selalu mengurangkan yang lebih besar: hasil tidak negatif.
    final greater = rng.nextBool();
    return _XlsDraft(
      'if-sum',
      d,
      _call('IF', [
        _bin(greater ? '>' : '<', first, second),
        greater ? _bin('-', first, second) : _bin('-', second, first),
        greater ? _bin('-', second, first) : _bin('-', first, second),
      ]),
    );
  }

  _XlsDraft _vlookupProduct(Rng rng) {
    final d = _sales(rng);
    final key = rng.pick(d.labels);
    return _XlsDraft(
      'vlookup-kali',
      d,
      _bin('*', _lookup(d, key, 2), _lookup(d, key, 3)),
    );
  }

  _XlsDraft _nestedIf(Rng rng) {
    final d = _scores(rng);
    final key = rng.pick(d.labels);
    final high = _between(rng, 78, 88);
    final low = high - _between(rng, 10, 18);
    const labels = ['Baik', 'Cukup', 'Kurang'];
    return _XlsDraft(
      'if-bertingkat',
      d,
      _call('IF', [
        _bin('>=', _lookup(d, key, 2), XlsNum(high)),
        const XlsStr('Baik'),
        _call('IF', [
          _bin('>=', _lookup(d, key, 2), XlsNum(low)),
          const XlsStr('Cukup'),
          const XlsStr('Kurang'),
        ]),
      ]),
      labels: labels,
    );
  }
}
