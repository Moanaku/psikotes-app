import 'dart:convert';

import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = NumWordGenerator();
const _solver = NumWordSolver();

List<String> numWordBounds(Question q) {
  final issues = <String>[];
  final figure = q.stem.figure;
  if (figure is! TableFigure) return ['stem tanpa tabel'];
  final table = WordTable.from(figure);
  if (table == null) return ['tabel tidak terbaca'];
  final lines = (q.stem.text ?? '').split('\n');
  if (lines.length != 2) issues.add('teks soal bukan konteks + pertanyaan');
  final op = WordOp.parse(lines.last, table);
  if (op == null) return [...issues, 'pertanyaan tidak terurai: ${lines.last}'];
  // Pertanyaan tercetak ulang persis dari operasinya.
  if (op.question != lines.last) {
    issues.add('pertanyaan tidak kanonik: ${op.question}');
  }
  final value = op.evaluate(table);
  if (value == null || value.isNegative || value.isZero) {
    issues.add('nilai tidak wajar: $value');
  } else if (value.toDecimal() == null) {
    issues.add('jawaban lebih dari 2 desimal');
  }
  if (q.options.length != NumWordGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  for (final o in q.options) {
    final v = parseWordAnswer(o.content.text ?? '');
    if (v == null) issues.add('opsi bukan bilangan: ${o.content.text}');
    if (op.isPercent != (o.content.text ?? '').endsWith('%')) {
      issues.add('tanda % tidak sesuai: ${o.content.text}');
    }
  }
  if (table.labels.length < 4) issues.add('baris tabel kurang dari 4');
  if (!q.tags.single.startsWith('rule:num-word:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  return issues;
}

TableFigure _table() => TableFigure(
      headers: ['Modul', 'Ditemukan', 'Diperbaiki'],
      rows: [
        ['Login', '40', '30'],
        ['Pembayaran', '25', '20'],
        ['Laporan', '15', '5'],
        ['Profil', '20', '10'],
      ],
    );

Question _question(String line, List<String> options, {TableFigure? table}) =>
    Question(
      type: QuestionType.numWord,
      seed: 1,
      difficulty: Difficulty.easy,
      stem: QuestionContent(text: 'Konteks.\n$line', figure: table ?? _table()),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i), content: QuestionContent(text: options[i])),
      ],
      correctIndex: 0,
      explanation: 'uji',
      estimatedSeconds: 10,
    );

String? _eval(WordOp op) => op.evaluate(WordTable.from(_table())!)?.toString();

void main() {
  PropertyHarness(_generator, _solver, bounds: numWordBounds).register();

  group('operasi pada tabel', () {
    test('nilai dari isi tabel', () {
      expect(_eval(const SumOp('Ditemukan', ['Login', 'Laporan'])), '55');
      expect(_eval(const DiffOp('Ditemukan', 'Laporan', 'Login')), '25');
      expect(_eval(const MeanOp('Diperbaiki', ['Login', 'Laporan', 'Profil'])),
          '15');
      expect(
          _eval(const ProductOp('Login', 'Ditemukan', 'Diperbaiki')), '1200');
      expect(
          _eval(const SumProductOp(
              ['Login', 'Profil'], 'Ditemukan', 'Diperbaiki')),
          '1400');
      expect(
          _eval(const DiffProductOp(
              'Login', 'Profil', 'Ditemukan', 'Diperbaiki')),
          '1000');
      expect(
          _eval(const RemainingOp('Login', 'Ditemukan', 'Diperbaiki')), '10');
      expect(
          _eval(const SumRemainingOp(
              ['Login', 'Laporan'], 'Ditemukan', 'Diperbaiki')),
          '20');
      // (30 + 20 + 5 + 10) / (40 + 25 + 15 + 20) * 100 = 65%.
      expect(_eval(const PercentOp('Ditemukan', 'Diperbaiki')), '65');
    });

    test('rujukan yang tidak ada di tabel memberi null', () {
      expect(_eval(const SumOp('Ditemukan', ['Login', 'Tidak ada'])), isNull);
      expect(_eval(const SumOp('Kolom lain', ['Login'])), isNull);
    });

    test('cetak lalu urai memberi operasi yang sama', () {
      final table = WordTable.from(_table())!;
      const ops = <WordOp>[
        SumOp('Ditemukan', ['Login', 'Laporan']),
        SumOp('Diperbaiki', ['Login', 'Laporan', 'Profil']),
        DiffOp('Ditemukan', 'Laporan', 'Login'),
        MeanOp('Diperbaiki', ['Login', 'Laporan', 'Profil']),
        ProductOp('Login', 'Ditemukan', 'Diperbaiki'),
        SumProductOp(['Login', 'Profil'], 'Ditemukan', 'Diperbaiki'),
        DiffProductOp('Login', 'Profil', 'Ditemukan', 'Diperbaiki'),
        RemainingOp('Login', 'Ditemukan', 'Diperbaiki'),
        SumRemainingOp(['Login', 'Laporan'], 'Ditemukan', 'Diperbaiki'),
        PercentOp('Ditemukan', 'Diperbaiki'),
      ];
      for (final op in ops) {
        final parsed = WordOp.parse(op.question, table);
        expect(parsed, isNotNull, reason: op.question);
        expect(parsed.runtimeType, op.runtimeType, reason: op.question);
        expect(parsed!.question, op.question);
        expect(parsed.evaluate(table)!.equals(op.evaluate(table)!), isTrue);
      }
    });

    test('kalimat yang tidak dikenal ditolak', () {
      final table = WordTable.from(_table())!;
      expect(WordOp.parse('Berapa total semuanya?', table), isNull);
      expect(WordOp.parse('Berapa jumlah Ditemukan pada Mars?', table), isNull);
    });
  });

  group('tabel', () {
    test('JSON bolak-balik dan validasi', () {
      final back =
          FigureSpec.fromJson(jsonDecode(jsonEncode(_table().toJson())));
      expect(back, isA<TableFigure>());
      expect(jsonEncode(back.toJson()), jsonEncode(_table().toJson()));
      expect(_table().validate('t'), isEmpty);
      expect(
          TableFigure(headers: [
            'A'
          ], rows: [
            ['x'],
            ['y']
          ]).validate('t'),
          isNotEmpty);
      expect(
          TableFigure(headers: [
            'A',
            'B'
          ], rows: [
            ['x', '1'],
            ['y'],
          ]).validate('t'),
          isNotEmpty);
      expect(
          TableFigure(headers: [
            'A',
            'B'
          ], rows: [
            ['x', ''],
            ['y', '2'],
          ]).validate('t'),
          isNotEmpty);
    });

    test('tabel dengan label kembar atau sel bukan angka tidak terbaca', () {
      expect(
          WordTable.from(TableFigure(headers: [
            'A',
            'B'
          ], rows: [
            ['x', '1'],
            ['x', '2'],
          ])),
          isNull);
      expect(
          WordTable.from(TableFigure(headers: [
            'A',
            'B'
          ], rows: [
            ['x', 'satu'],
            ['y', '2'],
          ])),
          isNull);
    });
  });

  group('solver', () {
    test('menghitung dari tabel, bukan dari teks', () {
      final q = _question('Berapa jumlah Ditemukan pada Login dan Laporan?',
          ['55', '70', '40']);
      expect(_solver.validOptions(q), [0]);
    });

    test('data pengalih: kolom lain dan baris lain tidak valid', () {
      final q = _question('Berapa jumlah Ditemukan pada Login dan Laporan?',
          ['55', '35', '65', '70']);
      expect(_solver.validOptions(q), [0]);
    });

    test('jawaban persen memakai tanda %', () {
      final q = _question(
          'Berapa persen jumlah Diperbaiki dari jumlah Ditemukan pada seluruh baris?',
          ['65%', '35%', '0,65%']);
      expect(_solver.validOptions(q), [0]);
    });

    test('titik ribuan pada opsi', () {
      final big = TableFigure(headers: [
        'Produk',
        'Harga',
        'Terjual'
      ], rows: [
        ['Buku', '12.500', '40'],
        ['Pulpen', '3.000', '10'],
      ]);
      final q = _question(
          'Berapa hasil Harga dikali Terjual pada Buku?', ['500.000', '50.000'],
          table: big);
      expect(_solver.validOptions(q), [0]);
    });

    test('rujukan tidak ada atau tanpa tabel tidak punya opsi valid', () {
      expect(
          _solver.validOptions(
              _question('Berapa jumlah Ditemukan pada Mars dan Login?', ['1'])),
          isEmpty);
      final noTable = Question(
        type: QuestionType.numWord,
        seed: 1,
        difficulty: Difficulty.easy,
        stem: const QuestionContent(text: 'x\nBerapa jumlah A pada B dan C?'),
        options: const [Option(id: 'A', content: QuestionContent(text: '1'))],
        correctIndex: 0,
        explanation: 'x',
        estimatedSeconds: 10,
      );
      expect(_solver.validOptions(noTable), isEmpty);
    });
  });

  group('keluaran generator', () {
    test('semua operasi muncul', () {
      final tags = <String>{};
      for (var s = 0; s < 600; s++) {
        for (final d in Difficulty.values) {
          tags.addAll(_generator.generate(s, d).tags);
        }
      }
      expect(tags, {
        for (final n in [
          'sum',
          'sum3',
          'diff',
          'mean',
          'product',
          'sumproduct',
          'diffproduct',
          'remaining',
          'sumremaining',
          'percent',
        ])
          'rule:num-word:$n',
      });
    });

    test('tabel memuat baris pengalih yang tidak ditanyakan', () {
      var withDecoy = 0;
      for (var s = 0; s < 200; s++) {
        final q = _generator.generate(s, Difficulty.easy);
        final table = WordTable.from(q.stem.figure)!;
        final line = q.stem.text!.split('\n').last;
        final unused = table.labels.where((l) => !line.contains(l));
        if (unused.isNotEmpty) withDecoy++;
      }
      expect(withDecoy, greaterThan(150));
    });
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:num-word:product']);
      expect(q.correctIndex, 2);
      expect(
          q.stem.text,
          'Sebuah toko alat tulis mencatat penjualan satu hari.\nBerapa '
          'hasil Harga (Rp) dikali Terjual (unit) pada Stapler?');
      expect(
          q.explanation,
          'Kalikan Harga (Rp) dan Terjual (unit) pada Stapler: 25.000 × '
          '6 = 150.000. Baris yang tidak disebut dalam pertanyaan tidak '
          'dipakai. Jadi jawabannya 150.000.');
    });
  });
}
