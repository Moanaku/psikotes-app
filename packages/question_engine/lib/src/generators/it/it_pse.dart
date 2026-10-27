/// Generator IT-PSE (trace pseudocode), docs/06-bank-konten.md.
///
/// Stem: tiga paragraf yang dipisah baris kosong: kalimat pengantar, kode
/// (indentasi dua spasi), dan satu pertanyaan bertata bahasa tetap
/// ([PseCommand]). Solver mengurai kode dari stem dan menjalankannya dengan
/// interpreter di `pseudo.dart`; kunci tidak dibaca dari tempat lain.
///
/// Pengecoh: hasil program yang diubah satu bagian (batas loop plus-minus
/// satu, kondisi `<` jadi `<=`, operator tertukar, konstanta bergeser), yaitu
/// kesalahan trace yang paling sering. Bila kurang dari tiga yang berbeda,
/// sisanya bilangan di sekitar kunci.
library;

import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'pseudo.dart';

/// Kalimat pengantar tetap; solver memisahkan stem menurut baris kosong.
const String pseIntro = 'Pseudocode berikut dijalankan dari atas ke bawah.';

/// Pertanyaan yang dikenali. [render] dan [parse] saling berlawanan.
sealed class PseQuestion {
  const PseQuestion();

  String render();

  /// Nilai jawaban dari hasil menjalankan program; null bila tidak terdefinisi.
  int? answer(PseudoRun run);

  static PseQuestion? parse(String text) {
    var m = RegExp(r'^Berapa nilai yang ditampilkan\?$').firstMatch(text);
    if (m != null) return const PseShown();
    m = RegExp(r'^Berapa nilai ([A-Za-z_][A-Za-z_0-9]*) setelah program '
            r'selesai\?$')
        .firstMatch(text);
    if (m != null) return PseFinal(m.group(1)!);
    m = RegExp(r'^Berapa kali baris "(.+)" dijalankan\?$').firstMatch(text);
    if (m != null) return PseCount(m.group(1)!);
    return null;
  }
}

final class PseShown extends PseQuestion {
  const PseShown();

  @override
  String render() => 'Berapa nilai yang ditampilkan?';

  @override
  int? answer(PseudoRun run) =>
      run.output.length == 1 ? run.output.single : null;
}

final class PseFinal extends PseQuestion {
  const PseFinal(this.name);

  final String name;

  @override
  String render() => 'Berapa nilai $name setelah program selesai?';

  @override
  int? answer(PseudoRun run) => run.variables[name];
}

final class PseCount extends PseQuestion {
  const PseCount(this.head);

  /// Teks pernyataan persis seperti di kode, tanpa indentasi.
  final String head;

  @override
  String render() => 'Berapa kali baris "$head" dijalankan?';

  @override
  int? answer(PseudoRun run) => run.executions[head];
}

/// Stem terurai: program dan pertanyaannya.
final class PseStem {
  const PseStem(this.program, this.question);

  final PsProgram program;
  final PseQuestion question;

  /// Null bila teks bukan stem IT-PSE yang sah.
  static PseStem? parse(String? text) {
    if (text == null) return null;
    final parts = text.split('\n\n');
    if (parts.length != 3 || parts.first != pseIntro) return null;
    final question = PseQuestion.parse(parts[2]);
    if (question == null) return null;
    try {
      return PseStem(psParseProgram(parts[1].split('\n')), question);
    } on PseudoError {
      return null;
    }
  }

  static String compose(PsProgram program, PseQuestion question) =>
      '$pseIntro\n\n${psRenderProgram(program).join('\n')}\n\n${question.render()}';
}

final class ItPseSolver implements QuestionSolver {
  const ItPseSolver();

  /// Jawaban benar menurut interpreter, atau null bila stem/program tidak sah.
  static int? answerOf(Question q) {
    final stem = PseStem.parse(q.stem.text);
    if (stem == null) return null;
    try {
      return stem.question.answer(psRunProgram(stem.program));
    } on PseudoError {
      return null;
    }
  }

  @override
  List<int> validOptions(Question question) {
    final answer = answerOf(question);
    if (answer == null) return const [];
    return [
      for (var i = 0; i < question.options.length; i++)
        if (question.options[i].content.text?.trim() == '$answer') i,
    ];
  }
}

// ---------------------------------------------------------------------------
// Perubahan satu bagian (pengecoh)
// ---------------------------------------------------------------------------

/// Semua program yang berbeda satu bagian dari [program].
List<PsProgram> pseMutants(PsProgram program) {
  final out = <PsProgram>[];
  final counter = _Mutator(-1, 0)..run(program);
  for (var site = 0; site < counter.seen; site++) {
    for (var variant = 0; variant < 2; variant++) {
      final m = _Mutator(site, variant);
      final mutated = m.run(program);
      if (m.applied) out.add(mutated);
    }
  }
  return out;
}

final class _Mutator {
  _Mutator(this.target, this.variant);

  final int target;
  final int variant;
  int seen = 0;
  bool applied = false;

  bool _hit() {
    final hit = seen == target;
    seen++;
    return hit;
  }

  PsProgram run(PsProgram p) => _stmts(p);

  List<PsStmt> _stmts(List<PsStmt> list) => [for (final s in list) _stmt(s)];

  PsStmt _stmt(PsStmt s) => switch (s) {
        PsAssign() => PsAssign(s.name, _expr(s.value)),
        PsShow() => PsShow(_expr(s.value)),
        PsIf() => PsIf(_cond(s.cond), _stmts(s.then), _stmts(s.otherwise)),
        PsWhile() => PsWhile(_cond(s.cond), _stmts(s.body)),
        PsFor() => PsFor(s.name, _expr(s.from), _expr(s.to), _stmts(s.body)),
      };

  PsCond _cond(PsCond c) => switch (c) {
        PsCmp() => _cmp(c),
        PsAndCond() => PsAndCond([for (final p in c.parts) _cond(p)]),
        PsOrCond() => PsOrCond([for (final p in c.parts) _cond(p)]),
      };

  PsCond _cmp(PsCmp c) {
    final left = _expr(c.left);
    final right = _expr(c.right);
    var op = c.op;
    if (_hit() && variant == 0) {
      op = switch (c.op) {
        '<' => '<=',
        '<=' => '<',
        '>' => '>=',
        '>=' => '>',
        '=' => '!=',
        _ => '=',
      };
      applied = true;
    }
    return PsCmp(op, left, right);
  }

  PsExpr _expr(PsExpr e) {
    switch (e) {
      case PsNum():
        if (_hit()) {
          applied = true;
          return PsNum(variant == 0 ? e.value + 1 : e.value - 1);
        }
        return e;
      case PsVar():
        return e;
      case PsBin():
        final left = _expr(e.left);
        final right = _expr(e.right);
        var op = e.op;
        if (_hit() && variant == 0) {
          op = switch (e.op) {
            '+' => '-',
            '-' => '+',
            '*' => '+',
            _ => e.op,
          };
          applied = op != e.op;
        }
        return PsBin(op, left, right);
    }
  }
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

PsExpr _n(int v) => PsNum(v);
PsExpr _v(String name) => PsVar(name);
PsExpr _add(PsExpr a, PsExpr b) => PsBin('+', a, b);
PsExpr _sub(PsExpr a, PsExpr b) => PsBin('-', a, b);
PsExpr _mul(PsExpr a, PsExpr b) => PsBin('*', a, b);
PsExpr _div(PsExpr a, PsExpr b) => PsBin('DIV', a, b);
PsExpr _mod(PsExpr a, PsExpr b) => PsBin('MOD', a, b);
PsStmt _set(String name, PsExpr e) => PsAssign(name, e);

int _between(Rng rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

/// Satu program siap tanya: [program] dan nama templatnya untuk tag.
final class _Draft {
  const _Draft(this.template, this.program, this.loopVars);

  final String template;
  final PsProgram program;

  /// Variabel kendali ULANGI; nilai akhirnya tidak ditanyakan.
  final Set<String> loopVars;
}

final class ItPseGenerator extends RetryingGenerator {
  const ItPseGenerator();

  @override
  QuestionType get type => QuestionType.itPse;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const ItPseSolver();

  static const int optionCount = 4;

  /// Batas langkah per soal; di bawah batas interpreter supaya soal tetap
  /// bisa ditelusuri tangan.
  static const int maxSteps = 400;

  static const int maxCodeLines = 12;

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final draft = _draft(rng, difficulty);
    final PseudoRun run;
    try {
      run = psRunProgram(draft.program);
    } on PseudoError {
      return null;
    }
    if (run.steps > maxSteps) return null;
    final code = psRenderProgram(draft.program);
    if (code.length > maxCodeLines) return null;

    final candidates = _questions(rng, draft, run);
    if (candidates.isEmpty) return null;
    final question = candidates[rng.nextInt(candidates.length)];
    final answer = question.answer(run);
    if (answer == null) return null;

    final distractors = _distractors(rng, draft.program, question, answer);
    if (distractors == null) return null;
    final assembled = assembleOptions(
      rng,
      QuestionContent(text: '$answer'),
      [for (final d in distractors) QuestionContent(text: '$d')],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(text: PseStem.compose(draft.program, question)),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(run, question, answer),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 45,
        Difficulty.medium => 80,
        Difficulty.hard => 120,
      },
      tags: ['rule:it-pse:${draft.template}'],
    );
  }

  List<PseQuestion> _questions(Rng rng, _Draft draft, PseudoRun run) {
    final out = <PseQuestion>[];
    if (run.output.length == 1) {
      out
        ..add(const PseShown())
        ..add(const PseShown());
    }
    final names = run.variables.keys
        .where((k) => !draft.loopVars.contains(k))
        .toList()
      ..sort();
    for (final n in names) {
      out.add(PseFinal(n));
    }
    // Baris yang dihitung: pernyataan sederhana dengan teks unik di kode.
    final heads = <String>[];
    void collect(List<PsStmt> stmts) {
      for (final s in stmts) {
        switch (s) {
          case PsAssign() || PsShow():
            heads.add(psStmtHead(s));
          case PsIf():
            collect(s.then);
            collect(s.otherwise);
          case PsWhile():
            collect(s.body);
          case PsFor():
            collect(s.body);
        }
      }
    }

    collect(draft.program);
    for (final h in heads) {
      if (heads.where((x) => x == h).length == 1 &&
          (run.executions[h] ?? 0) >= 2) {
        out.add(PseCount(h));
      }
    }
    return out;
  }

  List<int>? _distractors(
    Rng rng,
    PsProgram program,
    PseQuestion question,
    int answer,
  ) {
    final pool = <int>{};
    for (final m in rng.shuffle(pseMutants(program))) {
      final PseudoRun run;
      try {
        run = psRunProgram(m);
      } on PseudoError {
        continue;
      }
      final v = question.answer(run);
      if (v != null && v != answer) pool.add(v);
    }
    final picked = rng.shuffle(pool.toList()).take(optionCount - 1).toList();
    if (picked.length < optionCount - 1) {
      final spare = <int>[
        for (var d = 1; d <= 4; d++) ...[answer + d, answer - d],
      ].where((v) => v != answer && !picked.contains(v)).toList();
      for (final v in rng.shuffle(spare)) {
        if (picked.length == optionCount - 1) break;
        picked.add(v);
      }
    }
    return picked.length == optionCount - 1 ? picked : null;
  }

  String _explain(PseudoRun run, PseQuestion question, int answer) {
    final names = run.variables.keys.toList()..sort();
    final finals = names.map((k) => '$k = ${run.variables[k]}').join(', ');
    final head = switch (question) {
      PseShown() => 'Nilai yang ditampilkan adalah $answer.',
      PseFinal(:final name) => 'Nilai $name di akhir adalah $answer.',
      PseCount(:final head) => 'Baris "$head" dijalankan $answer kali.',
    };
    return '$head Telusuri dari atas dan catat nilai tiap variabel setelah '
        'tiap baris; perhatikan batas perulangan dan arah perbandingan. '
        'Nilai akhir: $finals.';
  }

  // -------------------------------------------------------------------------
  // Templat program
  // -------------------------------------------------------------------------

  _Draft _draft(Rng rng, Difficulty d) {
    final templates = switch (d) {
      Difficulty.easy => [_branch, _sumLoop, _divMod],
      Difficulty.medium => [_loopIf, _countdown, _growth],
      Difficulty.hard => [_nested, _digits, _twoCounters],
    };
    return templates[rng.nextInt(templates.length)](rng);
  }

  static const _cmpOps = ['<', '>', '<=', '>=', '!='];

  _Draft _branch(Rng rng) {
    final a = _between(rng, 2, 20);
    final b = _between(rng, 2, 20);
    final op = rng.pick(_cmpOps);
    PsExpr pickExpr() => rng.pick<PsExpr>([
          _add(_v('a'), _v('b')),
          _sub(_v('a'), _v('b')),
          _mul(_v('a'), _n(_between(rng, 2, 4))),
          _sub(_v('b'), _n(_between(rng, 1, 5))),
        ]);
    final program = <PsStmt>[
      _set('a', _n(a)),
      _set('b', _n(b)),
      PsIf(PsCmp(op, _v('a'), _v('b')), [_set('c', pickExpr())],
          [_set('c', pickExpr())]),
      PsShow(_v('c')),
    ];
    return _Draft('cabang', program, const {});
  }

  _Draft _sumLoop(Rng rng) {
    final lo = _between(rng, 1, 3);
    final hi = lo + _between(rng, 3, 6);
    final k = _between(rng, 2, 4);
    final body = rng.pick<PsExpr>([
      _add(_v('s'), _v('i')),
      _add(_v('s'), _mul(_v('i'), _n(k))),
      _add(_v('s'), _add(_v('i'), _n(k))),
    ]);
    final program = <PsStmt>[
      _set('s', _n(_between(rng, 0, 5))),
      PsFor('i', _n(lo), _n(hi), [_set('s', body)]),
      PsShow(_v('s')),
    ];
    return _Draft('jumlah-ulangi', program, const {'i'});
  }

  _Draft _divMod(Rng rng) {
    final d = _between(rng, 3, 9);
    final n = _between(rng, 20, 90);
    final program = <PsStmt>[
      _set('n', _n(n)),
      _set('q', _div(_v('n'), _n(d))),
      _set('r', _mod(_v('n'), _n(d))),
      _set('t',
          rng.nextBool() ? _add(_v('q'), _v('r')) : _sub(_v('q'), _v('r'))),
      PsShow(_v('t')),
    ];
    return _Draft('div-mod', program, const {});
  }

  _Draft _loopIf(Rng rng) {
    final n = _between(rng, 6, 12);
    final m = _between(rng, 2, 4);
    final r = rng.nextInt(m);
    final withElse = rng.nextBool();
    final program = <PsStmt>[
      _set('s', _n(0)),
      PsFor('i', _n(1), _n(n), [
        PsIf(
          PsCmp('=', _mod(_v('i'), _n(m)), _n(r)),
          [_set('s', _add(_v('s'), _v('i')))],
          withElse ? [_set('s', _sub(_v('s'), _n(1)))] : const [],
        ),
      ]),
      PsShow(_v('s')),
    ];
    return _Draft('ulangi-jika', program, const {'i'});
  }

  _Draft _countdown(Rng rng) {
    final step = _between(rng, 2, 5);
    final limit = _between(rng, 0, 6);
    final start =
        limit + step * _between(rng, 3, 7) + _between(rng, 0, step - 1);
    final op = rng.pick(['>', '>=']);
    final program = <PsStmt>[
      _set('x', _n(start)),
      _set('c', _n(0)),
      PsWhile(PsCmp(op, _v('x'), _n(limit)), [
        _set('x', _sub(_v('x'), _n(step))),
        _set('c', _add(_v('c'), _n(1))),
      ]),
      PsShow(rng.nextBool() ? _v('c') : _v('x')),
    ];
    return _Draft('selama-turun', program, const {});
  }

  _Draft _growth(Rng rng) {
    final m = _between(rng, 2, 3);
    final limit = _between(rng, 20, 90);
    final program = <PsStmt>[
      _set('p', _n(1)),
      _set('k', _n(0)),
      PsWhile(PsCmp(rng.pick(['<', '<=']), _v('p'), _n(limit)), [
        _set('p', _mul(_v('p'), _n(m))),
        _set('k', _add(_v('k'), _n(1))),
      ]),
      PsShow(rng.nextBool() ? _v('k') : _v('p')),
    ];
    return _Draft('selama-tumbuh', program, const {});
  }

  _Draft _nested(Rng rng) {
    final n = _between(rng, 3, 5);
    final triangular = rng.nextBool();
    final parity = rng.nextInt(2);
    final extra = rng.nextBool();
    final inner = PsCmp('=', _mod(_add(_v('i'), _v('j')), _n(2)), _n(parity));
    final cond = extra ? PsAndCond([inner, PsCmp('>', _v('j'), _n(1))]) : inner;
    final program = <PsStmt>[
      _set('c', _n(0)),
      PsFor('i', _n(1), _n(n), [
        PsFor('j', _n(1), triangular ? _v('i') : _n(_between(rng, 2, 4)), [
          PsIf(cond, [_set('c', _add(_v('c'), _n(1)))]),
        ]),
      ]),
      PsShow(_v('c')),
    ];
    return _Draft('ulangi-bersarang', program, const {'i', 'j'});
  }

  _Draft _digits(Rng rng) {
    final n = _between(rng, 100, 9999);
    final reverse = rng.nextBool();
    final program = <PsStmt>[
      _set('n', _n(n)),
      _set(reverse ? 'r' : 's', _n(0)),
      PsWhile(PsCmp('>', _v('n'), _n(0)), [
        if (reverse)
          _set('r', _add(_mul(_v('r'), _n(10)), _mod(_v('n'), _n(10))))
        else
          _set('s', _add(_v('s'), _mod(_v('n'), _n(10)))),
        _set('n', _div(_v('n'), _n(10))),
      ]),
      PsShow(_v(reverse ? 'r' : 's')),
    ];
    return _Draft('digit', program, const {});
  }

  _Draft _twoCounters(Rng rng) {
    final a = _between(rng, 1, 6);
    final b = _between(rng, 10, 20);
    final p = _between(rng, 1, 3);
    final q = _between(rng, 0, p);
    final lim = _between(rng, 4, 9);
    final useOr = rng.nextBool();
    final cond = useOr
        ? PsOrCond([
            PsCmp('<', _v('a'), _v('b')),
            PsCmp('<', _v('t'), _n(2)),
          ])
        : PsAndCond([
            PsCmp('<', _v('a'), _v('b')),
            PsCmp('<', _v('t'), _n(lim)),
          ]);
    final program = <PsStmt>[
      _set('a', _n(a)),
      _set('b', _n(b)),
      _set('t', _n(0)),
      PsWhile(cond, [
        _set('a', _add(_v('a'), _n(p + 1))),
        _set('b', _add(_v('b'), _n(q))),
        _set('t', _add(_v('t'), _n(1))),
      ]),
      PsShow(rng.pick([_v('t'), _v('a'), _v('b')])),
    ];
    return _Draft('selama-dua-syarat', program, const {});
  }
}
