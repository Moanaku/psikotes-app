/// Generator NUM-WORD (soal cerita dan tabel), docs/06-bank-konten.md,
/// "Spesifikasi ringkas tipe lain".
///
/// Stem: kalimat konteks, satu pertanyaan, dan tabel data ([TableFigure]).
/// Tabel memuat baris dan kolom pengalih yang tidak ditanyakan. Solver
/// membaca operasi dari kalimat pertanyaan (tata bahasa tetap di [WordOp]) dan
/// menghitung dari isi tabel, bukan dari angka di teks.
///
/// Pengecoh: memakai data yang salah (baris atau kolom pengalih, operasi yang
/// keliru, satu langkah terlewat).
library;

import '../../figure_spec.dart';
import '../../fraction.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';

/// Data tabel yang bisa dibaca: label baris ke nilai tiap kolom.
final class WordTable {
  WordTable._(this.headers, this.labels, this.values);

  final List<String> headers;
  final List<String> labels;

  /// `values[baris][kolom - 1]`.
  final List<List<Fraction>> values;

  static WordTable? from(FigureSpec? figure) {
    if (figure is! TableFigure) return null;
    final labels = <String>[];
    final values = <List<Fraction>>[];
    for (final row in figure.rows) {
      final cells = <Fraction>[];
      for (final c in row.skip(1)) {
        final v = parseDisplayNumber(c);
        if (v == null) return null;
        cells.add(v);
      }
      labels.add(row.first);
      values.add(cells);
    }
    if (labels.toSet().length != labels.length) return null;
    if (figure.headers.toSet().length != figure.headers.length) return null;
    return WordTable._(figure.headers, labels, values);
  }

  int? row(String label) {
    final i = labels.indexOf(label);
    return i < 0 ? null : i;
  }

  /// Indeks kolom data (1 dan seterusnya di tabel; 0 di [values]).
  int? column(String header) {
    final i = headers.indexOf(header);
    return i < 1 ? null : i - 1;
  }

  Fraction at(int row, int column) => values[row][column];
}

String _joinNames(List<String> items) => switch (items.length) {
      1 => items.single,
      2 => '${items[0]} dan ${items[1]}',
      _ => '${items.sublist(0, items.length - 1).join(', ')}, dan '
          '${items.last}',
    };

List<String> _splitNames(String text) =>
    text.replaceAll(', dan ', ', ').replaceAll(' dan ', ', ').split(', ');

/// Operasi pada tabel. [render] dan [parse] saling berlawanan.
sealed class WordOp {
  const WordOp();

  /// Kalimat pertanyaan yang tampil di soal.
  String get question;

  /// Nilai dari isi tabel; null bila rujukan tidak ada di tabel.
  Fraction? evaluate(WordTable t);

  /// Jawaban ditulis dengan tanda persen.
  bool get isPercent => false;

  /// Langkah hitung untuk pembahasan (nilai sudah terformat).
  String explain(WordTable t);

  /// Operasi dari kalimat pertanyaan. Beberapa pola saling mirip ("jumlah X
  /// pada ..." dan "jumlah hasil X dikali Y pada ..."), jadi hanya pola yang
  /// rujukannya ada di [table] yang dipakai.
  static WordOp? parse(String question, WordTable table) {
    for (final p in _parsers) {
      final op = p(question);
      if (op != null && op.evaluate(table) != null) return op;
    }
    return null;
  }

  static final List<WordOp? Function(String)> _parsers = [
    SumOp.parse,
    DiffOp.parse,
    MeanOp.parse,
    ProductOp.parse,
    SumProductOp.parse,
    DiffProductOp.parse,
    RemainingOp.parse,
    SumRemainingOp.parse,
    PercentOp.parse,
  ];
}

String _fmt(Fraction f) => f.toDecimal(maxPlaces: 3) ?? f.toString();

Fraction? _cell(WordTable t, String row, String col) {
  final r = t.row(row);
  final c = t.column(col);
  return r == null || c == null ? null : t.at(r, c);
}

final class SumOp extends WordOp {
  const SumOp(this.column, this.rows);

  final String column;
  final List<String> rows;

  @override
  String get question => 'Berapa jumlah $column pada ${_joinNames(rows)}?';

  @override
  Fraction? evaluate(WordTable t) {
    var sum = Fraction.zero;
    for (final r in rows) {
      final v = _cell(t, r, column);
      if (v == null) return null;
      sum = sum + v;
    }
    return sum;
  }

  @override
  String explain(WordTable t) {
    final vs = [for (final r in rows) _fmt(_cell(t, r, column)!)];
    return 'Jumlahkan $column pada ${_joinNames(rows)}: ${vs.join(' + ')} = '
        '${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(r'^Berapa jumlah (.+) pada (.+)\?$').firstMatch(q);
    return m == null ? null : SumOp(m.group(1)!, _splitNames(m.group(2)!));
  }
}

final class DiffOp extends WordOp {
  const DiffOp(this.column, this.rowA, this.rowB);

  final String column;
  final String rowA;
  final String rowB;

  @override
  String get question => 'Berapa selisih $column antara $rowA dan $rowB?';

  @override
  Fraction? evaluate(WordTable t) {
    final a = _cell(t, rowA, column);
    final b = _cell(t, rowB, column);
    if (a == null || b == null) return null;
    return a > b ? a - b : b - a;
  }

  @override
  String explain(WordTable t) {
    final a = _cell(t, rowA, column)!;
    final b = _cell(t, rowB, column)!;
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    return 'Kurangi yang besar dengan yang kecil: ${_fmt(hi)} - ${_fmt(lo)} = '
        '${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m =
        RegExp(r'^Berapa selisih (.+) antara (.+) dan (.+)\?$').firstMatch(q);
    return m == null ? null : DiffOp(m.group(1)!, m.group(2)!, m.group(3)!);
  }
}

final class MeanOp extends WordOp {
  const MeanOp(this.column, this.rows);

  final String column;
  final List<String> rows;

  @override
  String get question => 'Berapa rata-rata $column pada ${_joinNames(rows)}?';

  @override
  Fraction? evaluate(WordTable t) {
    final sum = SumOp(column, rows).evaluate(t);
    return sum == null ? null : sum / Fraction(rows.length);
  }

  @override
  String explain(WordTable t) {
    final vs = [for (final r in rows) _fmt(_cell(t, r, column)!)];
    return 'Rata-rata adalah jumlah dibagi banyak data: (${vs.join(' + ')}) ÷ '
        '${rows.length} = ${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(r'^Berapa rata-rata (.+) pada (.+)\?$').firstMatch(q);
    return m == null ? null : MeanOp(m.group(1)!, _splitNames(m.group(2)!));
  }
}

final class ProductOp extends WordOp {
  const ProductOp(this.row, this.x, this.y);

  final String row;
  final String x;
  final String y;

  @override
  String get question => 'Berapa hasil $x dikali $y pada $row?';

  @override
  Fraction? evaluate(WordTable t) {
    final a = _cell(t, row, x);
    final b = _cell(t, row, y);
    return a == null || b == null ? null : a * b;
  }

  @override
  String explain(WordTable t) => 'Kalikan $x dan $y pada $row: '
      '${_fmt(_cell(t, row, x)!)} × ${_fmt(_cell(t, row, y)!)} = '
      '${_fmt(evaluate(t)!)}.';

  static WordOp? parse(String q) {
    final m =
        RegExp(r'^Berapa hasil (.+) dikali (.+) pada (.+)\?$').firstMatch(q);
    return m == null ? null : ProductOp(m.group(3)!, m.group(1)!, m.group(2)!);
  }
}

final class SumProductOp extends WordOp {
  const SumProductOp(this.rows, this.x, this.y);

  final List<String> rows;
  final String x;
  final String y;

  @override
  String get question =>
      'Berapa jumlah hasil $x dikali $y pada ${_joinNames(rows)}?';

  @override
  Fraction? evaluate(WordTable t) {
    var sum = Fraction.zero;
    for (final r in rows) {
      final p = ProductOp(r, x, y).evaluate(t);
      if (p == null) return null;
      sum = sum + p;
    }
    return sum;
  }

  @override
  String explain(WordTable t) {
    final parts = [
      for (final r in rows) '$r ${_fmt(ProductOp(r, x, y).evaluate(t)!)}',
    ];
    return 'Hitung $x × $y tiap baris: ${parts.join(', ')}. Jumlahnya '
        '${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(r'^Berapa jumlah hasil (.+) dikali (.+) pada (.+)\?$')
        .firstMatch(q);
    return m == null
        ? null
        : SumProductOp(_splitNames(m.group(3)!), m.group(1)!, m.group(2)!);
  }
}

final class DiffProductOp extends WordOp {
  const DiffProductOp(this.a, this.b, this.x, this.y);

  final String a;
  final String b;
  final String x;
  final String y;

  @override
  String get question => 'Berapa selisih hasil $x dikali $y antara $a dan $b?';

  @override
  Fraction? evaluate(WordTable t) {
    final pa = ProductOp(a, x, y).evaluate(t);
    final pb = ProductOp(b, x, y).evaluate(t);
    if (pa == null || pb == null) return null;
    return pa > pb ? pa - pb : pb - pa;
  }

  @override
  String explain(WordTable t) {
    final pa = ProductOp(a, x, y).evaluate(t)!;
    final pb = ProductOp(b, x, y).evaluate(t)!;
    final hi = pa > pb ? pa : pb;
    final lo = pa > pb ? pb : pa;
    return 'Hitung $x × $y: $a ${_fmt(pa)}, $b ${_fmt(pb)}. Selisihnya '
        '${_fmt(hi)} - ${_fmt(lo)} = ${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(
            r'^Berapa selisih hasil (.+) dikali (.+) antara (.+) dan (.+)\?$')
        .firstMatch(q);
    return m == null
        ? null
        : DiffProductOp(m.group(3)!, m.group(4)!, m.group(1)!, m.group(2)!);
  }
}

final class RemainingOp extends WordOp {
  const RemainingOp(this.row, this.x, this.y);

  final String row;
  final String x;
  final String y;

  @override
  String get question => 'Berapa hasil $x dikurangi $y pada $row?';

  @override
  Fraction? evaluate(WordTable t) {
    final a = _cell(t, row, x);
    final b = _cell(t, row, y);
    return a == null || b == null ? null : a - b;
  }

  @override
  String explain(WordTable t) => 'Kurangi $x dengan $y pada $row: '
      '${_fmt(_cell(t, row, x)!)} - ${_fmt(_cell(t, row, y)!)} = '
      '${_fmt(evaluate(t)!)}.';

  static WordOp? parse(String q) {
    final m =
        RegExp(r'^Berapa hasil (.+) dikurangi (.+) pada (.+)\?$').firstMatch(q);
    return m == null
        ? null
        : RemainingOp(m.group(3)!, m.group(1)!, m.group(2)!);
  }
}

final class SumRemainingOp extends WordOp {
  const SumRemainingOp(this.rows, this.x, this.y);

  final List<String> rows;
  final String x;
  final String y;

  @override
  String get question =>
      'Berapa jumlah hasil $x dikurangi $y pada ${_joinNames(rows)}?';

  @override
  Fraction? evaluate(WordTable t) {
    var sum = Fraction.zero;
    for (final r in rows) {
      final p = RemainingOp(r, x, y).evaluate(t);
      if (p == null) return null;
      sum = sum + p;
    }
    return sum;
  }

  @override
  String explain(WordTable t) {
    final parts = [
      for (final r in rows) '$r ${_fmt(RemainingOp(r, x, y).evaluate(t)!)}',
    ];
    return 'Hitung $x - $y tiap baris: ${parts.join(', ')}. Jumlahnya '
        '${_fmt(evaluate(t)!)}.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(r'^Berapa jumlah hasil (.+) dikurangi (.+) pada (.+)\?$')
        .firstMatch(q);
    return m == null
        ? null
        : SumRemainingOp(_splitNames(m.group(3)!), m.group(1)!, m.group(2)!);
  }
}

final class PercentOp extends WordOp {
  const PercentOp(this.x, this.y);

  /// Kolom pembanding (seratus persen) dan kolom bagian.
  final String x;
  final String y;

  @override
  bool get isPercent => true;

  @override
  String get question =>
      'Berapa persen jumlah $y dari jumlah $x pada seluruh baris?';

  @override
  Fraction? evaluate(WordTable t) {
    final cx = t.column(x);
    final cy = t.column(y);
    if (cx == null || cy == null) return null;
    var sx = Fraction.zero;
    var sy = Fraction.zero;
    for (var r = 0; r < t.labels.length; r++) {
      sx = sx + t.at(r, cx);
      sy = sy + t.at(r, cy);
    }
    if (sx.isZero) return null;
    return sy / sx * Fraction(100);
  }

  @override
  String explain(WordTable t) {
    final cx = t.column(x)!;
    final cy = t.column(y)!;
    var sx = Fraction.zero;
    var sy = Fraction.zero;
    for (var r = 0; r < t.labels.length; r++) {
      sx = sx + t.at(r, cx);
      sy = sy + t.at(r, cy);
    }
    return 'Jumlah $y ${_fmt(sy)}, jumlah $x ${_fmt(sx)}. Persennya '
        '${_fmt(sy)} ÷ ${_fmt(sx)} × 100 = ${_fmt(evaluate(t)!)}%.';
  }

  static WordOp? parse(String q) {
    final m = RegExp(
            r'^Berapa persen jumlah (.+) dari jumlah (.+) pada seluruh baris\?$')
        .firstMatch(q);
    return m == null ? null : PercentOp(m.group(2)!, m.group(1)!);
  }
}

/// Jawaban dari teks opsi; tanda "%" di belakang diabaikan.
Fraction? parseWordAnswer(String text) {
  final t = text.trim();
  return parseDisplayNumber(t.endsWith('%') ? t.substring(0, t.length - 1) : t);
}

final class NumWordSolver implements QuestionSolver {
  const NumWordSolver();

  @override
  List<int> validOptions(Question question) {
    final table = WordTable.from(question.stem.figure);
    final text = question.stem.text ?? '';
    final line = text.split('\n').last;
    if (table == null) return const [];
    final op = WordOp.parse(line, table);
    if (op == null) return const [];
    try {
      final value = op.evaluate(table);
      if (value == null) return const [];
      return [
        for (var i = 0; i < question.options.length; i++)
          if (parseWordAnswer(question.options[i].content.text ?? '')
              case final v? when v.equals(value))
            i,
      ];
    } on FractionOverflow {
      return const [];
    }
  }
}

/// Bahan satu konteks cerita.
final class _Context {
  const _Context({
    required this.intro,
    required this.headers,
    required this.labels,
    required this.firstRange,
    required this.secondRange,
    required this.secondBelowFirst,
    required this.ops,
  });

  final String intro;
  final List<String> headers;
  final List<String> labels;
  final (int, int, int) firstRange; // awal, akhir, kelipatan
  final (int, int, int) secondRange;

  /// Kolom kedua tidak melebihi kolom pertama (diperbaiki dari ditemukan).
  final bool secondBelowFirst;
  final List<String> ops;
}

const List<_Context> _contexts = [
  _Context(
    intro: 'Sebuah toko alat tulis mencatat penjualan satu hari.',
    headers: ['Produk', 'Harga (Rp)', 'Terjual (unit)'],
    labels: ['Buku', 'Pulpen', 'Penggaris', 'Map', 'Stapler', 'Lem'],
    firstRange: (1500, 25000, 500),
    secondRange: (4, 60, 1),
    secondBelowFirst: false,
    ops: ['sum', 'diff', 'mean', 'product', 'sumproduct', 'diffproduct'],
  ),
  _Context(
    intro: 'Tim QA mencatat bug per modul pada satu sprint.',
    headers: ['Modul', 'Ditemukan', 'Diperbaiki'],
    labels: [
      'Login',
      'Pembayaran',
      'Laporan',
      'Profil',
      'Notifikasi',
      'Pencarian'
    ],
    firstRange: (8, 80, 1),
    secondRange: (2, 80, 1),
    secondBelowFirst: true,
    ops: ['sum', 'diff', 'mean', 'remaining', 'sumremaining', 'percent'],
  ),
  _Context(
    intro: 'Tim produk memantau tiap versi aplikasi mobile selama sebulan.',
    headers: ['Versi', 'Unduhan (ribu)', 'Pengguna aktif (ribu)'],
    labels: ['1.0', '1.1', '1.2', '2.0', '2.1', '3.0'],
    firstRange: (20, 400, 5),
    secondRange: (5, 400, 5),
    secondBelowFirst: true,
    ops: ['sum', 'diff', 'mean', 'remaining', 'sumremaining', 'percent'],
  ),
];

class NumWordGenerator extends RetryingGenerator {
  const NumWordGenerator();

  static const int optionCount = 5;

  /// Pengambilan data tabel per percobaan sampai jawaban rapi.
  static const int dataTries = 100;

  @override
  QuestionType get type => QuestionType.numWord;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const NumWordSolver();

  /// Operasi menurut kesulitan (jumlah langkah).
  static List<String> opsFor(Difficulty d) => switch (d) {
        Difficulty.easy => const ['sum', 'diff'],
        Difficulty.medium => const [
            'mean',
            'product',
            'remaining',
            'sum3',
          ],
        Difficulty.hard => const [
            'sumproduct',
            'diffproduct',
            'sumremaining',
            'percent',
          ],
      };

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final wanted = opsFor(difficulty);
    final candidates = [
      for (final c in _contexts)
        for (final o in wanted)
          if (c.ops.contains(o == 'sum3' ? 'sum' : o)) (c, o),
    ];
    final (ctx, opName) = rng.pick(candidates);

    final rowCount = 4 + rng.nextInt(3);
    final labels = rng.shuffle(ctx.labels).take(rowCount).toList();
    final secondaryHeader = ctx.headers[2];
    final primaryHeader = ctx.headers[1];

    for (var t = 0; t < dataTries; t++) {
      final data = _data(rng, ctx, rowCount);
      final table = TableFigure(
        headers: ctx.headers,
        rows: [
          for (var r = 0; r < rowCount; r++)
            [
              labels[r],
              Fraction(data[r].$1).toDecimal()!,
              Fraction(data[r].$2).toDecimal()!,
            ],
        ],
      );
      final parsed = WordTable.from(table);
      if (parsed == null) continue;

      final op =
          _makeOp(rng, opName, labels, primaryHeader, secondaryHeader, parsed);
      if (op == null) continue;
      final value = op.evaluate(parsed);
      if (value == null || value.isNegative || value.isZero) continue;
      final answerText = _format(value, op.isPercent);
      if (answerText == null) continue;

      final foils = _foils(rng, op, parsed, labels, ctx.headers, value);
      if (foils.length < optionCount - 1) continue;
      final distractors = foils.take(optionCount - 1).toList();

      final assembled = assembleOptions(
        rng,
        QuestionContent(text: answerText),
        [for (final d in distractors) QuestionContent(text: d)],
      );
      final used = _usedRows(op);
      final unusedNote = used.length < labels.length
          ? ' Baris yang tidak disebut dalam pertanyaan tidak dipakai.'
          : '';
      return Question(
        type: type,
        seed: seed,
        difficulty: difficulty,
        stem: QuestionContent(
          text: '${ctx.intro}\n${op.question}',
          figure: table,
        ),
        options: assembled.options,
        correctIndex: assembled.correctIndex,
        explanation: '${op.explain(parsed)}$unusedNote Jadi jawabannya '
            '$answerText.',
        estimatedSeconds: switch (difficulty) {
          Difficulty.easy => 30,
          Difficulty.medium => 50,
          Difficulty.hard => 75,
        },
        tags: ['rule:num-word:$opName'],
      );
    }
    return null;
  }

  static List<(int, int)> _data(Rng rng, _Context ctx, int rows) {
    int draw((int, int, int) r) =>
        r.$1 + rng.nextInt((r.$2 - r.$1) ~/ r.$3 + 1) * r.$3;
    return [
      for (var i = 0; i < rows; i++)
        () {
          final first = draw(ctx.firstRange);
          var second = draw(ctx.secondRange);
          if (ctx.secondBelowFirst) {
            // Kolom kedua tidak melebihi kolom pertama.
            final cap = ctx.secondRange.$3;
            second =
                cap * (1 + rng.nextInt(first ~/ cap < 1 ? 1 : first ~/ cap));
          }
          return (first, second);
        }(),
    ];
  }

  static List<String> _usedRows(WordOp op) => switch (op) {
        SumOp(:final rows) ||
        MeanOp(:final rows) ||
        SumProductOp(:final rows) ||
        SumRemainingOp(:final rows) =>
          rows,
        DiffOp(:final rowA, :final rowB) => [rowA, rowB],
        DiffProductOp(:final a, :final b) => [a, b],
        ProductOp(:final row) || RemainingOp(:final row) => [row],
        PercentOp() => const [],
      };

  static WordOp? _makeOp(Rng rng, String name, List<String> labels,
      String first, String second, WordTable table) {
    List<String> some(int n) => rng.shuffle(labels).take(n).toList();
    switch (name) {
      case 'sum':
        return SumOp(first, some(2));
      case 'sum3':
        return SumOp(rng.nextBool() ? first : second, some(3));
      case 'diff':
        final pair = some(2);
        return DiffOp(first, pair[0], pair[1]);
      case 'mean':
        return MeanOp(first, some(3));
      case 'product':
        return ProductOp(rng.pick(labels), first, second);
      case 'sumproduct':
        return SumProductOp(some(2), first, second);
      case 'diffproduct':
        final two = some(2);
        return DiffProductOp(two[0], two[1], first, second);
      case 'remaining':
        return RemainingOp(rng.pick(labels), first, second);
      case 'sumremaining':
        return SumRemainingOp(some(2), first, second);
      case 'percent':
        return PercentOp(first, second);
    }
    return null;
  }

  /// Jawaban dengan paling banyak dua desimal; persen diberi tanda %.
  static String? _format(Fraction v, bool percent) {
    final s = v.toDecimal();
    if (s == null) return null;
    return percent ? '$s%' : s;
  }

  /// Pengecoh dengan data yang salah, lalu angka di dekat jawaban.
  static List<String> _foils(Rng rng, WordOp op, WordTable table,
      List<String> labels, List<String> headers, Fraction answer) {
    final used = _usedRows(op);
    final unused = [
      for (final l in labels)
        if (!used.contains(l)) l
    ];
    final dataHeaders = headers.skip(1).toList();
    final seen = {_format(answer, op.isPercent)};
    final out = <String>[];
    void add(Fraction? v) {
      if (v == null || v.isNegative) return;
      final s = _format(v, op.isPercent);
      if (s != null && seen.add(s)) out.add(s);
    }

    Fraction? eval(WordOp o) {
      try {
        return o.evaluate(table);
      } on FractionOverflow {
        return null;
      }
    }

    String otherHeader(String h) => dataHeaders.firstWhere((x) => x != h);
    String? decoy() => unused.isEmpty ? null : rng.pick(unused);
    List<String> swapOne(List<String> rows) {
      final d = decoy();
      if (d == null) return rows;
      final i = rng.nextInt(rows.length);
      return [...rows]..[i] = d;
    }

    final plausible = <Fraction?>[];
    switch (op) {
      case SumOp(:final column, :final rows):
        plausible
          ..add(eval(SumOp(otherHeader(column), rows)))
          ..add(eval(SumOp(column, swapOne(rows))))
          ..add(eval(MeanOp(column, rows)));
      case DiffOp(:final column, :final rowA, :final rowB):
        plausible
          ..add(eval(SumOp(column, [rowA, rowB])))
          ..add(eval(DiffOp(otherHeader(column), rowA, rowB)))
          ..add(eval(DiffOp(column, decoy() ?? rowA, rowB)));
      case MeanOp(:final column, :final rows):
        final sum = eval(SumOp(column, rows));
        plausible
          ..add(sum)
          ..add(sum == null ? null : sum / Fraction(rows.length + 1))
          ..add(eval(MeanOp(otherHeader(column), rows)))
          ..add(eval(MeanOp(column, swapOne(rows))));
      case ProductOp(:final row, :final x, :final y):
        plausible
          ..add(eval(SumOp(x, [row])))
          ..add(eval(SumOp(y, [row])))
          ..add(decoy() == null ? null : eval(ProductOp(decoy()!, x, y)))
          ..add(_safe(() => (_cell(table, row, x)! + _cell(table, row, y)!)));
      case SumProductOp(:final rows, :final x, :final y):
        plausible
          ..add(eval(ProductOp(rows.first, x, y)))
          ..add(eval(SumProductOp(swapOne(rows), x, y)))
          ..add(_safe(() => eval(SumOp(x, rows))! * eval(SumOp(y, rows))!));
      case DiffProductOp(:final a, :final b, :final x, :final y):
        plausible
          ..add(eval(SumProductOp([a, b], x, y)))
          ..add(eval(DiffOp(x, a, b)))
          ..add(
              decoy() == null ? null : eval(DiffProductOp(a, decoy()!, x, y)));
      case RemainingOp(:final row, :final x, :final y):
        plausible
          ..add(eval(SumOp(x, [row])))
          ..add(_safe(() => _cell(table, row, x)! + _cell(table, row, y)!))
          ..add(decoy() == null ? null : eval(RemainingOp(decoy()!, x, y)));
      case SumRemainingOp(:final rows, :final x, :final y):
        plausible
          ..add(eval(RemainingOp(rows.first, x, y)))
          ..add(eval(SumRemainingOp(swapOne(rows), x, y)))
          ..add(eval(SumOp(x, rows)));
      case PercentOp(:final x, :final y):
        plausible
          ..add(_safe(() => answer / Fraction(100)))
          ..add(eval(PercentOp(y, x)))
          ..add(_safe(() => Fraction(100) - answer));
    }
    for (final v in rng.shuffle(plausible)) {
      add(v);
    }
    // Pelengkap: angka di dekat jawaban.
    final unit = answer.isInteger ? Fraction(1) : Fraction(1, 10);
    for (final k in rng.shuffle([1, -1, 2, -2, 5, 10, -5, 20])) {
      add(_safe(() => answer + unit * Fraction(k)));
    }
    return out;
  }

  static Fraction? _safe(Fraction Function() f) {
    try {
      return f();
    } on FractionOverflow {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
