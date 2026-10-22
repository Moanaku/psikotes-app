import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = LogSylGenerator();
const _solver = LogSylSolver();

List<String> logSylBounds(Question q) {
  final issues = <String>[];
  final lines = (q.stem.text ?? '').split('\n');
  final premises = lines.where((l) => l.startsWith('Premis ')).length;
  final want = switch (q.difficulty) {
    Difficulty.easy => [2],
    Difficulty.medium => [2, 3],
    Difficulty.hard => [3],
  };
  if (!want.contains(premises)) {
    issues.add('$premises premis tidak sesuai ${q.difficulty.code}');
  }
  if (lines.last != 'Kesimpulan mana yang pasti benar?') {
    issues.add('baris pertanyaan salah: ${lines.last}');
  }
  if (q.options.length != LogSylGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  final terms = <String>[];
  for (final l in lines.where((l) => l.startsWith('Premis '))) {
    if (parseStatement(l.substring(l.indexOf(': ') + 2), terms) == null) {
      issues.add('premis tidak terurai: $l');
    }
  }
  if (terms.length != 3) issues.add('istilah ${terms.length}, seharusnya 3');
  // Pilihan lain tidak pasti benar, dan jawaban butuh sedikitnya dua premis.
  final prem = [
    for (final l in lines.where((l) => l.startsWith('Premis ')))
      parseStatement(l.substring(l.indexOf(': ') + 2), terms)!,
  ];
  final answer =
      parseStatement(q.options[q.correctIndex].content.text!, terms)!;
  if (prem.any((p) => entailed(modelsOf([p]), answer))) {
    issues.add('kesimpulan sudah mengikuti dari satu premis');
  }
  if (prem.any(answer.sameAs)) issues.add('kesimpulan sama dengan premis');
  for (var i = 0; i < q.options.length; i++) {
    if (i == q.correctIndex) continue;
    final s = parseStatement(q.options[i].content.text!, terms)!;
    if (prem.any(s.sameAs)) issues.add('pengecoh $i sama dengan premis');
  }
  // Tak ada istilah yang dipaksa kosong oleh premis.
  final models = modelsOf(prem);
  for (var t = 0; t < 3; t++) {
    if (!models.any((m) => [
          for (var k = 0; k < 8; k++)
            if (m & (1 << k) != 0 && k & (1 << t) != 0) k,
        ].isNotEmpty)) {
      issues.add('istilah $t dipaksa kosong');
    }
  }
  for (final letter in [
    for (var i = 0; i < q.options.length; i++)
      if (i != q.correctIndex) Option.idFor(i),
  ]) {
    if (!q.explanation.contains('Pilihan $letter belum pasti')) {
      issues.add('pembahasan tanpa pilihan $letter');
    }
  }
  if (!q.explanation
      .contains('Pilihan ${Option.idFor(q.correctIndex)} pasti benar')) {
    issues.add('pembahasan tanpa kunci');
  }
  return issues;
}

Statement s(Quant q, int x, int y) => Statement(q, x, y);

/// Pembanding bebas: struktur nyata dengan paling banyak [maxSize] anggota,
/// tiap anggota punya jenis 0..7, dan kuantor dievaluasi per anggota.
bool holdsIn(Statement st, List<int> members) {
  final xb = 1 << st.x;
  final yb = 1 << st.y;
  switch (st.quant) {
    case Quant.all:
      return members.every((t) => t & xb == 0 || t & yb != 0);
    case Quant.none:
      return members.every((t) => t & xb == 0 || t & yb == 0);
    case Quant.some:
      return members.any((t) => t & xb != 0 && t & yb != 0);
    case Quant.someNot:
      return members.any((t) => t & xb != 0 && t & yb == 0);
  }
}

List<List<int>> structures(int maxSize) {
  final out = <List<int>>[[]];
  var layer = <List<int>>[[]];
  for (var size = 1; size <= maxSize; size++) {
    layer = [
      for (final base in layer)
        for (var t = 0; t < 8; t++) [...base, t],
    ];
    out.addAll(layer);
  }
  return out;
}

void main() {
  PropertyHarness(_generator, _solver, bounds: logSylBounds).register();

  group('model himpunan', () {
    List<int> models(List<Statement> p) => modelsOf(p);

    test('Barbara: Semua A B, Semua B C maka Semua A C', () {
      final m = models([s(Quant.all, 0, 1), s(Quant.all, 1, 2)]);
      expect(entailed(m, s(Quant.all, 0, 2)), isTrue);
    });

    test('tanpa anggapan istilah tidak kosong: bukan Sebagian A C', () {
      final m = models([s(Quant.all, 0, 1), s(Quant.all, 1, 2)]);
      expect(entailed(m, s(Quant.some, 0, 2)), isFalse);
    });

    test('Darii: Semua B C, Sebagian A B maka Sebagian A C', () {
      final m = models([s(Quant.all, 1, 2), s(Quant.some, 0, 1)]);
      expect(entailed(m, s(Quant.some, 0, 2)), isTrue);
    });

    test('Celarent: Tidak ada B C, Semua A B maka Tidak ada A C', () {
      final m = models([s(Quant.none, 1, 2), s(Quant.all, 0, 1)]);
      expect(entailed(m, s(Quant.none, 0, 2)), isTrue);
    });

    test('Ferio: Tidak ada B C, Sebagian A B maka Sebagian A bukan C', () {
      final m = models([s(Quant.none, 1, 2), s(Quant.some, 0, 1)]);
      expect(entailed(m, s(Quant.someNot, 0, 2)), isTrue);
    });

    test('kekeliruan umum bukan kesimpulan pasti', () {
      // Semua A B, Semua C B: tidak berarti Semua A C.
      final m = models([s(Quant.all, 0, 1), s(Quant.all, 2, 1)]);
      expect(entailed(m, s(Quant.all, 0, 2)), isFalse);
      // Sebagian A B, Sebagian B C: tidak berarti Sebagian A C.
      final n = models([s(Quant.some, 0, 1), s(Quant.some, 1, 2)]);
      expect(entailed(n, s(Quant.some, 0, 2)), isFalse);
      // Semua A B tidak berarti Semua B A.
      expect(
          entailed(models([s(Quant.all, 0, 1)]), s(Quant.all, 1, 0)), isFalse);
    });

    test('premis yang saling bertentangan tidak punya model', () {
      final m = models([s(Quant.all, 0, 1), s(Quant.someNot, 0, 1)]);
      expect(m, isEmpty);
      expect(entailed(m, s(Quant.all, 0, 2)), isFalse);
    });

    test('negasi tepat', () {
      for (var model = 0; model < 256; model++) {
        for (final st in LogSylGenerator.allStatements) {
          expect(st.holds(model), isNot(st.negated.holds(model)),
              reason: '${st.quant.name} ${st.x} ${st.y} model $model');
        }
      }
    });

    test('sama dengan pembanding struktur nyata untuk semua pasangan premis',
        () {
      final all = LogSylGenerator.allStatements;
      final real = structures(3);
      for (final p1 in all) {
        for (final p2 in all) {
          final m = modelsOf([p1, p2]);
          final realModels = [
            for (final st in real)
              if (holdsIn(p1, st) && holdsIn(p2, st)) st,
          ];
          expect(realModels.isNotEmpty, m.isNotEmpty,
              reason: 'satisfiable ${p1.quant.name}/${p2.quant.name}');
          for (final c in all) {
            final viaRegions = entailed(m, c);
            final viaReal = realModels.isNotEmpty &&
                realModels.every((st) => holdsIn(c, st));
            expect(viaRegions, viaReal,
                reason: '${p1.quant.name}${p1.x}${p1.y}, '
                    '${p2.quant.name}${p2.x}${p2.y} => '
                    '${c.quant.name}${c.x}${c.y}');
          }
        }
      }
    });

    test('tiga premis acak sama dengan pembanding struktur nyata', () {
      final all = LogSylGenerator.allStatements;
      final real = structures(4);
      final rng = Rng(7);
      for (var i = 0; i < 40; i++) {
        final ps = [for (var k = 0; k < 3; k++) rng.pick(all)];
        final m = modelsOf(ps);
        final realModels = [
          for (final st in real)
            if (ps.every((p) => holdsIn(p, st))) st,
        ];
        expect(realModels.isNotEmpty, m.isNotEmpty);
        for (final c in all) {
          final viaReal =
              realModels.isNotEmpty && realModels.every((st) => holdsIn(c, st));
          expect(entailed(m, c), viaReal);
        }
      }
    });
  });

  group('parser kalimat', () {
    test('empat bentuk dan urutan istilah', () {
      final terms = <String>[];
      final a = parseStatement('Semua programmer adalah tester.', terms)!;
      final b =
          parseStatement('Tidak ada tester yang merupakan analis.', terms)!;
      final c = parseStatement('Sebagian analis bukan programmer.', terms)!;
      final d = parseStatement('Sebagian programmer adalah analis.', terms)!;
      expect(terms, ['programmer', 'tester', 'analis']);
      expect([a.quant, b.quant, c.quant, d.quant],
          [Quant.all, Quant.none, Quant.someNot, Quant.some]);
      expect([a.x, a.y, b.x, b.y], [0, 1, 1, 2]);
      expect(a.render(terms), 'Semua programmer adalah tester.');
      expect(b.render(terms), 'Tidak ada tester yang merupakan analis.');
      expect(c.render(terms), 'Sebagian analis bukan programmer.');
      expect(d.render(terms), 'Sebagian programmer adalah analis.');
    });

    test('istilah dengan kata "yang" tetap terurai', () {
      final terms = <String>[];
      final st =
          parseStatement('Semua orang yang teliti adalah tester.', terms)!;
      expect(terms, ['orang yang teliti', 'tester']);
      expect(st.quant, Quant.all);
    });

    test('bentuk lain ditolak', () {
      final terms = <String>[];
      for (final bad in [
        'Semua programmer tester.',
        'Mungkin semua programmer adalah tester.',
        'Semua programmer adalah programmer.',
        'Semua programmer adalah tester',
      ]) {
        expect(parseStatement(bad, terms), isNull, reason: bad);
      }
    });
  });

  group('solver', () {
    Question make(List<String> premises, List<String> options,
            {String last = 'Kesimpulan mana yang pasti benar?'}) =>
        Question(
          type: QuestionType.logSyl,
          seed: 1,
          difficulty: Difficulty.easy,
          stem: QuestionContent(
              text: [
            for (var i = 0; i < premises.length; i++)
              'Premis ${i + 1}: ${premises[i]}',
            last,
          ].join('\n')),
          options: [
            for (var i = 0; i < options.length; i++)
              Option(
                  id: Option.idFor(i),
                  content: QuestionContent(text: options[i])),
          ],
          correctIndex: 0,
          explanation: 'uji',
          estimatedSeconds: 10,
        );

    test('memilih kesimpulan yang pasti', () {
      final q = make([
        'Semua programmer adalah tester.',
        'Semua tester adalah analis.',
      ], [
        'Semua programmer adalah analis.',
        'Semua analis adalah programmer.',
        'Sebagian analis bukan tester.',
        'Sebagian programmer adalah analis.',
      ]);
      expect(_solver.validOptions(q), [0]);
    });

    test('premis yang bertentangan tidak punya opsi valid', () {
      final q = make([
        'Semua programmer adalah tester.',
        'Sebagian programmer bukan tester.',
      ], [
        'Semua tester adalah programmer.',
      ]);
      expect(_solver.validOptions(q), isEmpty);
    });

    test('lebih dari tiga istilah atau format salah tidak didukung', () {
      expect(
          _solver.validOptions(make([
            'Semua a adalah b.',
            'Semua c adalah d.',
          ], [
            'Semua a adalah d.',
          ])),
          isEmpty);
      expect(
          _solver.validOptions(
              make(['Semua a adalah b.'], ['Semua a adalah b.'], last: 'Apa?')),
          isEmpty);
    });
  });

  group('keluaran generator', () {
    test('semua kuantor dan jumlah premis muncul', () {
      final tags = <String>{};
      for (var seed = 0; seed < 400; seed++) {
        for (final d in Difficulty.values) {
          tags.addAll(_generator.generate(seed, d).tags);
        }
      }
      expect(
          tags,
          containsAll([
            'rule:log-syl:2-premis',
            'rule:log-syl:3-premis',
            'quant:all',
            'quant:none',
            'quant:some',
            'quant:someNot',
          ]));
    });

    test('easy hanya memakai semua dan sebagian', () {
      final tags = {
        for (var seed = 0; seed < 300; seed++)
          ..._generator.generate(seed, Difficulty.easy).tags,
      };
      expect(tags.contains('quant:none'), isFalse);
      expect(tags.contains('quant:someNot'), isFalse);
    });
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:log-syl:2-premis', 'quant:some', 'quant:none']);
      expect(q.correctIndex, 0);
      expect(
          q.stem.text,
          'Premis 1: Sebagian peserta pelatihan adalah '
          'programmer.\nPremis 2: Tidak ada mahasiswa yang merupakan '
          'programmer.\nKesimpulan mana yang pasti benar?');
      expect(
          q.explanation,
          'Pilihan A pasti benar: gabungan Premis 1 dan 2 membuatnya '
          'benar di setiap keadaan yang mungkin. Pilihan B belum pasti: '
          'bisa terjadi keadaan ketika ada yang termasuk peserta '
          'pelatihan dan programmer tetapi bukan mahasiswa dan ada yang '
          'termasuk peserta pelatihan dan mahasiswa tetapi bukan '
          'programmer, semua premis tetap benar tetapi pilihan ini '
          'salah. Pilihan C belum pasti: bisa terjadi keadaan ketika '
          'ada yang termasuk peserta pelatihan dan programmer tetapi '
          'bukan mahasiswa, semua premis tetap benar tetapi pilihan ini '
          'salah. Pilihan D belum pasti: bisa terjadi keadaan ketika '
          'ada yang termasuk peserta pelatihan dan programmer tetapi '
          'bukan mahasiswa, semua premis tetap benar tetapi pilihan ini '
          'salah. Pilihan E belum pasti: bisa terjadi keadaan ketika '
          'ada yang termasuk peserta pelatihan dan programmer tetapi '
          'bukan mahasiswa, semua premis tetap benar tetapi pilihan ini '
          'salah.');
    });
  });
}
