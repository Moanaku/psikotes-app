/// Generator LOG-SYL (silogisme dan logika), docs/06-bank-konten.md,
/// "Spesifikasi ringkas tipe lain".
///
/// 2 sampai 3 premis dengan kuantor (semua, tidak ada, sebagian, sebagian
/// bukan) atas tiga istilah. Pertanyaan: kesimpulan mana yang pasti benar.
///
/// Pemeriksa model himpunan: tiga istilah membagi anggota menjadi 8 jenis
/// (A, B, C masing-masing ya atau tidak). Sebuah model adalah himpunan jenis
/// yang berpenghuni (2^8 = 256 model). Kuantor universal benar pada model
/// yang tidak berpenghuni jenis terlarang (tanpa anggapan bahwa istilah tidak
/// kosong), kuantor "sebagian" butuh penghuni. Kesimpulan pasti benar bila
/// benar di semua model yang memenuhi semua premis, dan premisnya sendiri
/// memenuhi sedikitnya satu model.
library;

import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';

enum Quant {
  all('Semua'),
  none('Tidak ada'),
  some('Sebagian'),
  someNot('Sebagian bukan');

  const Quant(this.label);

  final String label;

  /// Negasi tepat: semua lawan sebagian bukan, tidak ada lawan sebagian.
  Quant get negation => switch (this) {
        Quant.all => Quant.someNot,
        Quant.someNot => Quant.all,
        Quant.none => Quant.some,
        Quant.some => Quant.none,
      };
}

/// Pernyataan atas dua istilah (indeks 0 sampai 2).
final class Statement {
  const Statement(this.quant, this.x, this.y);

  final Quant quant;
  final int x;
  final int y;

  Statement get negated => Statement(quant.negation, x, y);

  bool sameAs(Statement o) => quant == o.quant && x == o.x && y == o.y;

  String render(List<String> terms) => switch (quant) {
        Quant.all => 'Semua ${terms[x]} adalah ${terms[y]}.',
        Quant.none => 'Tidak ada ${terms[x]} yang merupakan ${terms[y]}.',
        Quant.some => 'Sebagian ${terms[x]} adalah ${terms[y]}.',
        Quant.someNot => 'Sebagian ${terms[x]} bukan ${terms[y]}.',
      };

  /// Benar di [model] (bitmask atas 8 jenis).
  bool holds(int model) {
    final xb = 1 << x;
    final yb = 1 << y;
    switch (quant) {
      case Quant.all:
        for (var t = 0; t < 8; t++) {
          if (model & (1 << t) != 0 && t & xb != 0 && t & yb == 0) return false;
        }
        return true;
      case Quant.none:
        for (var t = 0; t < 8; t++) {
          if (model & (1 << t) != 0 && t & xb != 0 && t & yb != 0) return false;
        }
        return true;
      case Quant.some:
        for (var t = 0; t < 8; t++) {
          if (model & (1 << t) != 0 && t & xb != 0 && t & yb != 0) return true;
        }
        return false;
      case Quant.someNot:
        for (var t = 0; t < 8; t++) {
          if (model & (1 << t) != 0 && t & xb != 0 && t & yb == 0) return true;
        }
        return false;
    }
  }
}

/// Pernyataan dari satu kalimat; istilah dicatat di [terms] sesuai urutan
/// kemunculan. Null bila bukan salah satu dari empat bentuk.
Statement? parseStatement(String line, List<String> terms) {
  final forms = <(RegExp, Quant)>[
    (RegExp(r'^Semua (.+) adalah (.+)\.$'), Quant.all),
    (RegExp(r'^Tidak ada (.+) yang merupakan (.+)\.$'), Quant.none),
    (RegExp(r'^Sebagian (.+) bukan (.+)\.$'), Quant.someNot),
    (RegExp(r'^Sebagian (.+) adalah (.+)\.$'), Quant.some),
  ];
  for (final (re, quant) in forms) {
    final m = re.firstMatch(line.trim());
    if (m == null) continue;
    int index(String term) {
      var i = terms.indexOf(term);
      if (i < 0) {
        terms.add(term);
        i = terms.length - 1;
      }
      return i;
    }

    final x = index(m.group(1)!);
    final y = index(m.group(2)!);
    return x == y ? null : Statement(quant, x, y);
  }
  return null;
}

/// Semua model (bitmask 0 sampai 255) yang memenuhi semua [premises].
List<int> modelsOf(List<Statement> premises) => [
      for (var m = 0; m < 256; m++)
        if (premises.every((p) => p.holds(m))) m,
    ];

/// Pasti benar: premis terpenuhi oleh sedikitnya satu model dan [s] benar di
/// semuanya.
bool entailed(List<int> models, Statement s) =>
    models.isNotEmpty && models.every(s.holds);

const String _questionLine = 'Kesimpulan mana yang pasti benar?';

final class LogSylSolver implements QuestionSolver {
  const LogSylSolver();

  @override
  List<int> validOptions(Question question) {
    final terms = <String>[];
    final premises = <Statement>[];
    final lines = (question.stem.text ?? '').split('\n');
    if (lines.isEmpty || lines.last != _questionLine) return const [];
    for (var i = 0; i < lines.length - 1; i++) {
      final prefix = 'Premis ${i + 1}: ';
      if (!lines[i].startsWith(prefix)) return const [];
      final s = parseStatement(lines[i].substring(prefix.length), terms);
      if (s == null) return const [];
      premises.add(s);
    }
    final options = <Statement>[];
    for (final o in question.options) {
      final s = parseStatement(o.content.text ?? '', terms);
      if (s == null) return const [];
      options.add(s);
    }
    if (terms.length > 3 || premises.isEmpty) return const [];
    final models = modelsOf(premises);
    return [
      for (var i = 0; i < options.length; i++)
        if (entailed(models, options[i])) i,
    ];
  }
}

class LogSylGenerator extends RetryingGenerator {
  const LogSylGenerator();

  static const int optionCount = 5;

  /// Pengambilan premis acak per percobaan sampai ada kesimpulan yang sah.
  static const int premiseTries = 40;

  static const List<String> termPool = [
    'programmer',
    'tester',
    'analis sistem',
    'desainer',
    'mahasiswa',
    'karyawan kontrak',
    'orang yang teliti',
    'pengguna aplikasi',
    'anggota tim',
    'peserta pelatihan',
    'admin jaringan',
    'manajer proyek',
  ];

  @override
  QuestionType get type => QuestionType.logSyl;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const LogSylSolver();

  static int premiseCount(Rng rng, Difficulty d) => switch (d) {
        Difficulty.easy => 2,
        Difficulty.medium => 2 + rng.nextInt(2),
        Difficulty.hard => 3,
      };

  static List<Quant> premiseQuants(Difficulty d) => switch (d) {
        Difficulty.easy => const [Quant.all, Quant.some],
        _ => Quant.values,
      };

  /// Semua pernyataan atas tiga istilah: 4 kuantor kali 6 pasangan berurutan.
  static final List<Statement> allStatements = [
    for (final q in Quant.values)
      for (var x = 0; x < 3; x++)
        for (var y = 0; y < 3; y++)
          if (x != y) Statement(q, x, y),
  ];

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final terms = rng.shuffle(termPool).take(3).toList();
    final count = premiseCount(rng, difficulty);
    final quants = premiseQuants(difficulty);

    for (var t = 0; t < premiseTries; t++) {
      final premises = <Statement>[];
      while (premises.length < count) {
        final x = rng.nextInt(3);
        final y = (x + 1 + rng.nextInt(2)) % 3;
        final s = Statement(rng.pick(quants), x, y);
        if (!premises.any(s.sameAs)) premises.add(s);
      }
      final models = modelsOf(premises);
      if (models.isEmpty || !_noTermForcedEmpty(models)) continue;

      // Kesimpulan yang butuh sedikitnya dua premis sekaligus.
      final correct = <Statement>[];
      final undetermined = <Statement>[];
      final contradicted = <Statement>[];
      for (final s in allStatements) {
        if (premises.any(s.sameAs)) continue;
        if (entailed(models, s)) {
          final alone = premises.any((p) => entailed(modelsOf([p]), s));
          if (!alone) correct.add(s);
        } else if (entailed(models, s.negated)) {
          contradicted.add(s);
        } else {
          undetermined.add(s);
        }
      }
      if (correct.isEmpty) continue;
      final pool = [...rng.shuffle(undetermined), ...rng.shuffle(contradicted)];
      if (pool.length < optionCount - 1) continue;

      final answer = rng.pick(correct);
      final distractors = pool.take(optionCount - 1).toList();
      final assembled = assembleOptions(
        rng,
        QuestionContent(text: answer.render(terms)),
        [for (final d in distractors) QuestionContent(text: d.render(terms))],
      );
      final letterOf = <String, String>{
        for (final o in assembled.options) o.content.text!: o.id,
      };
      return Question(
        type: type,
        seed: seed,
        difficulty: difficulty,
        stem: QuestionContent(
          text: [
            for (var i = 0; i < premises.length; i++)
              'Premis ${i + 1}: ${premises[i].render(terms)}',
            _questionLine,
          ].join('\n'),
        ),
        options: assembled.options,
        correctIndex: assembled.correctIndex,
        explanation: _explain(terms, premises, models, answer, distractors,
            letterOf, assembled.options[assembled.correctIndex].id),
        estimatedSeconds: switch (difficulty) {
          Difficulty.easy => 40,
          Difficulty.medium => 60,
          Difficulty.hard => 90,
        },
        tags: [
          'rule:log-syl:${premises.length}-premis',
          for (final q in {for (final p in premises) p.quant})
            'quant:${q.name}',
        ],
      );
    }
    return null;
  }

  /// Tiap istilah punya anggota di sedikitnya satu model; premis yang memaksa
  /// sebuah istilah kosong (misalnya "Semua A adalah B" dengan "Tidak ada A
  /// yang merupakan B") menghasilkan kesimpulan yang benar secara hampa dan
  /// dibuang.
  static bool _noTermForcedEmpty(List<int> models) {
    for (var term = 0; term < 3; term++) {
      var inhabited = false;
      for (final m in models) {
        for (var t = 0; t < 8; t++) {
          if (m & (1 << t) != 0 && t & (1 << term) != 0) inhabited = true;
        }
      }
      if (!inhabited) return false;
    }
    return true;
  }

  static String _explain(
    List<String> terms,
    List<Statement> premises,
    List<int> models,
    Statement answer,
    List<Statement> distractors,
    Map<String, String> letterOf,
    String answerLetter,
  ) {
    // Himpunan premis terkecil yang sudah cukup untuk kesimpulan.
    List<int>? needed;
    for (var size = 2; size <= premises.length && needed == null; size++) {
      for (final subset in _subsets(premises.length, size)) {
        final ms = modelsOf([for (final i in subset) premises[i]]);
        if (entailed(ms, answer)) {
          needed = subset;
          break;
        }
      }
    }
    final which = (needed ?? [for (var i = 0; i < premises.length; i++) i])
        .map((i) => '${i + 1}')
        .toList();
    final parts = <String>[
      'Pilihan $answerLetter pasti benar: gabungan Premis ${_and(which)} '
          'membuatnya benar di setiap keadaan yang mungkin.',
    ];
    final byLetter = {
      for (final d in distractors) letterOf[d.render(terms)]!: d,
    };
    for (final letter in byLetter.keys.toList()..sort()) {
      final counter = _counterModel(models, byLetter[letter]!);
      parts.add(
          'Pilihan $letter belum pasti: ${_describeModel(terms, counter)}, '
          'semua premis tetap benar tetapi pilihan ini salah.');
    }
    return parts.join(' ');
  }

  /// Model dengan penghuni paling sedikit yang memenuhi premis dan membuat
  /// [s] salah.
  static int _counterModel(List<int> models, Statement s) {
    var best = -1;
    var bestSize = 99;
    for (final m in models) {
      if (s.holds(m)) continue;
      final size = _bitCount(m);
      if (size < bestSize) {
        best = m;
        bestSize = size;
      }
    }
    return best;
  }

  static int _bitCount(int v) {
    var n = 0;
    for (var t = 0; t < 8; t++) {
      if (v & (1 << t) != 0) n++;
    }
    return n;
  }

  static String _describeModel(List<String> terms, int model) {
    if (model == 0) return 'bisa saja tidak ada anggota sama sekali';
    final kinds = <String>[];
    for (var t = 0; t < 8; t++) {
      if (model & (1 << t) == 0) continue;
      final inside = [
        for (var i = 0; i < 3; i++)
          if (t & (1 << i) != 0) terms[i]
      ];
      final outside = [
        for (var i = 0; i < 3; i++)
          if (t & (1 << i) == 0) terms[i]
      ];
      final ins = _and(inside);
      final outs = outside.length < 2
          ? outside.join()
          : '${outside.sublist(0, outside.length - 1).join(', ')} maupun '
              '${outside.last}';
      kinds.add(inside.isEmpty
          ? 'ada yang bukan $outs'
          : outside.isEmpty
              ? 'ada yang termasuk $ins'
              : 'ada yang termasuk $ins tetapi bukan $outs');
    }
    return 'bisa terjadi keadaan ketika ${_and(kinds)}';
  }

  static String _and(List<String> items) => switch (items.length) {
        1 => items.single,
        2 => '${items[0]} dan ${items[1]}',
        _ => '${items.sublist(0, items.length - 1).join(', ')}, dan '
            '${items.last}',
      };

  static Iterable<List<int>> _subsets(int n, int size) sync* {
    final idx = List.generate(size, (i) => i);
    while (true) {
      yield List.of(idx);
      var i = size - 1;
      while (i >= 0 && idx[i] == n - size + i) {
        i--;
      }
      if (i < 0) return;
      idx[i]++;
      for (var j = i + 1; j < size; j++) {
        idx[j] = idx[j - 1] + 1;
      }
    }
  }
}
