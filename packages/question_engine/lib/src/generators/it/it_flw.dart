/// Generator IT-FLW (logika flowchart), docs/06-bank-konten.md.
///
/// Flowchart ditulis sebagai tabel kotak ([TableFigure]) dengan kolom No,
/// Kotak, dan Lanjut ke. Eksekusi mulai dari kotak 1. Isi kotak: proses
/// (`x := e`), keputusan (`kondisi ?` dengan lanjutan `Ya: m, Tidak: n`), atau
/// keluaran (`TAMPILKAN e`). Lanjutan `SELESAI` mengakhiri flowchart. Ekspresi
/// dan kondisi memakai tata bahasa pseudocode IT-PSE (`pseudo.dart`).
///
/// Stem: satu kalimat pengantar tetap dan satu pertanyaan ([FlwQuestion]).
/// Solver membaca tabel dan pertanyaan, lalu menjalankan flowchart.
///
/// Pengecoh: jalur cabang lain (satu keputusan diambil ke arah sebaliknya)
/// dan batas kondisi yang bergeser (`>` jadi `>=`).
library;

import '../../figure_spec.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';
import 'pseudo.dart';

const String flwIntro = 'Flowchart berikut ditulis sebagai tabel kotak. '
    'Mulai dari kotak 1, lalu ikuti kolom Lanjut ke.';

const List<String> flwHeaders = ['No', 'Kotak', 'Lanjut ke'];

/// Lanjutan `SELESAI`.
const int flwEnd = 0;

sealed class FlwNode {
  const FlwNode();

  String get content;

  String get nextText;
}

final class FlwProcess extends FlwNode {
  const FlwProcess(this.name, this.value, this.next);

  final String name;
  final PsExpr value;
  final int next;

  @override
  String get content => '$name := ${value.render()}';

  @override
  String get nextText => _target(next);
}

final class FlwShow extends FlwNode {
  const FlwShow(this.value, this.next);

  final PsExpr value;
  final int next;

  @override
  String get content => 'TAMPILKAN ${value.render()}';

  @override
  String get nextText => _target(next);
}

final class FlwDecision extends FlwNode {
  const FlwDecision(this.cond, this.yes, this.no);

  final PsCond cond;
  final int yes;
  final int no;

  @override
  String get content => '${cond.render()} ?';

  @override
  String get nextText => 'Ya: ${_target(yes)}, Tidak: ${_target(no)}';
}

int _checkedFlw(int v) => v.abs() > PseudoLimits.maxMagnitude
    ? throw const PseudoError('nilai terlalu besar')
    : v;

String _target(int n) => n == flwEnd ? 'SELESAI' : '$n';

int? _parseTarget(String s) => s == 'SELESAI'
    ? flwEnd
    : (RegExp(r'^[1-9]\d*$').hasMatch(s) ? int.parse(s) : null);

/// Hasil menjalankan flowchart.
final class FlwRun {
  FlwRun(this.path, this.output, this.variables);

  /// Nomor kotak yang dilewati, berurutan.
  final List<int> path;
  final List<int> output;
  final Map<String, int> variables;

  int visits(int node) => path.where((n) => n == node).length;
}

final class Flowchart {
  Flowchart(Iterable<FlwNode> nodes) : nodes = List.unmodifiable(nodes);

  /// `nodes[i]` adalah kotak nomor i + 1.
  final List<FlwNode> nodes;

  /// Batas kunjungan kotak; lebih dari ini dianggap tidak berhenti.
  static const int maxVisits = 200;

  TableFigure toTable() => TableFigure(
        headers: flwHeaders,
        rows: [
          for (var i = 0; i < nodes.length; i++)
            ['${i + 1}', nodes[i].content, nodes[i].nextText],
        ],
      );

  /// Null bila tabel bukan flowchart IT-FLW yang sah.
  static Flowchart? fromTable(FigureSpec? figure) {
    if (figure is! TableFigure) return null;
    if (figure.headers.join('|') != flwHeaders.join('|')) return null;
    final nodes = <FlwNode>[];
    try {
      for (var i = 0; i < figure.rows.length; i++) {
        final row = figure.rows[i];
        if (row[0] != '${i + 1}') return null;
        final node = _node(row[1], row[2]);
        if (node == null) return null;
        nodes.add(node);
      }
    } on PseudoError {
      return null;
    }
    final chart = Flowchart(nodes);
    return chart.targetsValid ? chart : null;
  }

  static FlwNode? _node(String content, String next) {
    if (content.endsWith(' ?')) {
      final m = RegExp(r'^Ya: (\w+), Tidak: (\w+)$').firstMatch(next);
      if (m == null) return null;
      final yes = _parseTarget(m.group(1)!);
      final no = _parseTarget(m.group(2)!);
      if (yes == null || no == null) return null;
      return FlwDecision(
          psParseCond(content.substring(0, content.length - 2)), yes, no);
    }
    final target = _parseTarget(next);
    if (target == null) return null;
    if (content.startsWith('TAMPILKAN ')) {
      return FlwShow(psParseExpr(content.substring(10)), target);
    }
    final m = RegExp(r'^([a-z][a-z0-9]*) := (.+)$').firstMatch(content);
    if (m == null) return null;
    return FlwProcess(m.group(1)!, psParseExpr(m.group(2)!), target);
  }

  bool get targetsValid {
    bool ok(int t) => t == flwEnd || (t >= 1 && t <= nodes.length);
    return nodes.every((n) => switch (n) {
          FlwProcess() => ok(n.next),
          FlwShow() => ok(n.next),
          FlwDecision() => ok(n.yes) && ok(n.no),
        });
  }

  /// Menjalankan dari kotak 1. [flipAt] membalik keputusan ke-[flipAt]
  /// (mulai 0) yang dilewati, untuk pengecoh "jalur cabang lain". Melempar
  /// [PseudoError] bila tidak berhenti atau ekspresi tidak terdefinisi.
  FlwRun run({int? flipAt}) {
    final path = <int>[];
    final output = <int>[];
    final vars = <String, int>{};
    var decisions = 0;
    var current = 1;
    while (current != flwEnd) {
      if (path.length >= maxVisits) throw const StepLimitExceeded();
      path.add(current);
      final node = nodes[current - 1];
      switch (node) {
        case FlwProcess():
          vars[node.name] = _checkedFlw(psEval(node.value, vars));
          current = node.next;
        case FlwShow():
          output.add(psEval(node.value, vars));
          current = node.next;
        case FlwDecision():
          var yes = psTest(node.cond, vars);
          if (decisions == flipAt) yes = !yes;
          decisions++;
          current = yes ? node.yes : node.no;
      }
    }
    return FlwRun(path, output, vars);
  }

  /// Kotak yang tercapai dari kotak 1 menurut panah, tanpa menjalankan.
  Set<int> get reachable {
    final seen = <int>{};
    final todo = [1];
    while (todo.isNotEmpty) {
      final n = todo.removeLast();
      if (n == flwEnd || !seen.add(n)) continue;
      switch (nodes[n - 1]) {
        case FlwProcess(:final next) || FlwShow(:final next):
          todo.add(next);
        case FlwDecision(:final yes, :final no):
          todo
            ..add(yes)
            ..add(no);
      }
    }
    return seen;
  }

  /// Ada panah ke kotak bernomor sama atau lebih kecil (perulangan).
  bool get hasLoop {
    for (var i = 0; i < nodes.length; i++) {
      final targets = switch (nodes[i]) {
        FlwProcess(:final next) || FlwShow(:final next) => [next],
        FlwDecision(:final yes, :final no) => [yes, no],
      };
      if (targets.any((t) => t != flwEnd && t <= i + 1)) return true;
    }
    return false;
  }
}

/// Pertanyaan yang dikenali. [render] dan [parse] saling berlawanan.
sealed class FlwQuestion {
  const FlwQuestion();

  String render();

  static FlwQuestion? parse(String text) {
    if (text == FlwShown.text) return const FlwShown();
    if (text == FlwPath.text) return const FlwPath();
    final m =
        RegExp(r'^Berapa kali kotak ([1-9]\d*) dijalankan\?$').firstMatch(text);
    return m == null ? null : FlwVisits(int.parse(m.group(1)!));
  }

  /// Jawaban sebagai teks opsi; null bila tidak terdefinisi.
  String? answer(FlwRun run);
}

final class FlwShown extends FlwQuestion {
  const FlwShown();

  static const String text = 'Berapa nilai yang ditampilkan?';

  @override
  String render() => text;

  @override
  String? answer(FlwRun run) =>
      run.output.length == 1 ? '${run.output.single}' : null;
}

final class FlwPath extends FlwQuestion {
  const FlwPath();

  static const String text = 'Urutan kotak mana yang dilewati?';

  @override
  String render() => text;

  @override
  String? answer(FlwRun run) => run.path.join(', ');
}

final class FlwVisits extends FlwQuestion {
  const FlwVisits(this.node);

  final int node;

  @override
  String render() => 'Berapa kali kotak $node dijalankan?';

  @override
  String? answer(FlwRun run) => '${run.visits(node)}';
}

final class ItFlwSolver implements QuestionSolver {
  const ItFlwSolver();

  static String? answerOf(Question q) {
    final chart = Flowchart.fromTable(q.stem.figure);
    final lines = (q.stem.text ?? '').split('\n');
    if (chart == null || lines.length != 2 || lines.first != flwIntro) {
      return null;
    }
    final question = FlwQuestion.parse(lines.last);
    if (question == null) return null;
    if (question is FlwVisits && question.node > chart.nodes.length) {
      return null;
    }
    try {
      return question.answer(chart.run());
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
        if (question.options[i].content.text?.trim() == answer) i,
    ];
  }
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

PsExpr _n(int v) => PsNum(v);
PsExpr _v(String name) => PsVar(name);
PsExpr _bin(String op, PsExpr a, PsExpr b) => PsBin(op, a, b);
PsCond _cmp(String op, PsExpr a, PsExpr b) => PsCmp(op, a, b);

int _between(Rng rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

PsCond _shiftBoundary(PsCond c) => switch (c) {
      PsCmp() => PsCmp(
          switch (c.op) {
            '<' => '<=',
            '<=' => '<',
            '>' => '>=',
            '>=' => '>',
            '=' => '!=',
            _ => '=',
          },
          c.left,
          c.right),
      PsAndCond() =>
        PsAndCond([_shiftBoundary(c.parts.first), ...c.parts.skip(1)]),
      PsOrCond() =>
        PsOrCond([_shiftBoundary(c.parts.first), ...c.parts.skip(1)]),
    };

final class _FlwDraft {
  const _FlwDraft(this.template, this.chart);

  final String template;
  final Flowchart chart;
}

final class ItFlwGenerator extends RetryingGenerator {
  const ItFlwGenerator();

  @override
  QuestionType get type => QuestionType.itFlw;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const ItFlwSolver();

  static const int optionCount = 4;

  /// Kunjungan kotak terbanyak dalam satu soal, agar bisa ditelusuri tangan.
  static const int maxPath = 60;

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final draft = _draft(rng, difficulty);
    final chart = draft.chart;
    if (chart.reachable.length != chart.nodes.length) return null;
    final FlwRun run;
    try {
      run = chart.run();
    } on PseudoError {
      return null;
    }
    if (run.path.length > maxPath) return null;

    final questions = <FlwQuestion>[
      if (run.output.length == 1) const FlwShown(),
      if (!chart.hasLoop) const FlwPath(),
      if (chart.hasLoop)
        for (var n = 1; n <= chart.nodes.length; n++)
          if (run.visits(n) >= 2 && chart.nodes[n - 1] is FlwProcess)
            FlwVisits(n),
    ];
    if (questions.isEmpty) return null;
    final question = questions[rng.nextInt(questions.length)];
    final answer = question.answer(run);
    if (answer == null) return null;

    final distractors = _distractors(rng, chart, question, answer);
    if (distractors == null) return null;
    final assembled = assembleOptions(
      rng,
      QuestionContent(text: answer),
      [for (final d in distractors) QuestionContent(text: d)],
    );
    return Question(
      type: type,
      seed: seed,
      difficulty: difficulty,
      stem: QuestionContent(
        text: '$flwIntro\n${question.render()}',
        figure: chart.toTable(),
      ),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: _explain(run, question, answer),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 40,
        Difficulty.medium => 70,
        Difficulty.hard => 110,
      },
      tags: ['rule:it-flw:${draft.template}'],
    );
  }

  List<String>? _distractors(
    Rng rng,
    Flowchart chart,
    FlwQuestion question,
    String answer,
  ) {
    final runs = <FlwRun>[];
    // Jalur cabang lain: tiap keputusan yang dilewati dibalik sekali.
    for (var k = 0; k < 12; k++) {
      try {
        runs.add(chart.run(flipAt: k));
      } on PseudoError {
        continue;
      }
    }
    // Batas kondisi bergeser pada satu kotak keputusan.
    for (var i = 0; i < chart.nodes.length; i++) {
      final node = chart.nodes[i];
      if (node is! FlwDecision) continue;
      final shifted = Flowchart([
        for (var j = 0; j < chart.nodes.length; j++)
          j == i
              ? FlwDecision(_shiftBoundary(node.cond), node.yes, node.no)
              : chart.nodes[j],
      ]);
      try {
        runs.add(shifted.run());
      } on PseudoError {
        continue;
      }
    }
    final pool = <String>{
      for (final r in runs)
        if (question.answer(r) case final a?) a,
    }..remove(answer);
    final picked = rng.shuffle(pool.toList()).take(optionCount - 1).toList();
    if (picked.length < optionCount - 1 && question is! FlwPath) {
      final base = int.parse(answer);
      final spare = [
        for (var d = 1; d <= 4; d++) ...[base + d, base - d],
      ]
          .where((v) => question is! FlwVisits || v >= 0)
          .map((v) => '$v')
          .where((v) => v != answer && !picked.contains(v))
          .toList();
      for (final v in rng.shuffle(spare)) {
        if (picked.length == optionCount - 1) break;
        picked.add(v);
      }
    }
    if (picked.length < optionCount - 1 && question is FlwPath) {
      // Jalur yang berhenti satu kotak lebih awal: lupa kotak terakhir.
      final parts = answer.split(', ');
      for (var cut = parts.length - 1; cut >= 2; cut--) {
        final v = parts.take(cut).join(', ');
        if (picked.length == optionCount - 1) break;
        if (!picked.contains(v)) picked.add(v);
      }
    }
    return picked.length == optionCount - 1 ? picked : null;
  }

  String _explain(FlwRun run, FlwQuestion question, String answer) {
    final head = switch (question) {
      FlwShown() => 'Nilai yang ditampilkan adalah $answer.',
      FlwPath() => 'Kotak yang dilewati: $answer.',
      FlwVisits(:final node) => 'Kotak $node dijalankan $answer kali.',
    };
    final names = run.variables.keys.toList()..sort();
    final finals = names.map((k) => '$k = ${run.variables[k]}').join(', ');
    return '$head Jalur dari kotak 1: ${run.path.join(', ')}. Di tiap '
        'keputusan, hitung kondisinya dengan nilai saat itu lalu ambil Ya '
        'atau Tidak. Nilai akhir: $finals.';
  }

  // -------------------------------------------------------------------------
  // Templat flowchart
  // -------------------------------------------------------------------------

  _FlwDraft _draft(Rng rng, Difficulty d) {
    final templates = switch (d) {
      Difficulty.easy => [_oneBranch, _threshold],
      Difficulty.medium => [_twoStep, _grade],
      Difficulty.hard => [_loopSum, _loopCount],
    };
    return templates[rng.nextInt(templates.length)](rng);
  }

  static const _ops = ['<', '>', '<=', '>='];

  PsExpr _mix(Rng rng, String a, String b) => rng.pick<PsExpr>([
        _bin('+', _v(a), _v(b)),
        _bin('-', _v(a), _v(b)),
        _bin('*', _v(a), _n(_between(rng, 2, 3))),
        _bin('+', _v(b), _n(_between(rng, 1, 9))),
      ]);

  /// Satu keputusan, dua proses, satu keluaran.
  _FlwDraft _oneBranch(Rng rng) {
    final chart = Flowchart([
      FlwProcess('x', _n(_between(rng, 2, 20)), 2),
      FlwProcess('y', _n(_between(rng, 2, 20)), 3),
      FlwDecision(_cmp(rng.pick(_ops), _v('x'), _v('y')), 4, 5),
      FlwProcess('z', _mix(rng, 'x', 'y'), 6),
      FlwProcess('z', _mix(rng, 'y', 'x'), 6),
      FlwShow(_v('z'), flwEnd),
    ]);
    return _FlwDraft('satu-cabang', chart);
  }

  /// Keputusan terhadap konstanta; satu cabang langsung ke keluaran.
  _FlwDraft _threshold(Rng rng) {
    final limit = _between(rng, 10, 30);
    final chart = Flowchart([
      FlwProcess('n', _n(limit + _between(rng, -6, 6)), 2),
      FlwDecision(_cmp(rng.pick(_ops), _v('n'), _n(limit)), 3, 4),
      FlwProcess('n', _bin('*', _v('n'), _n(_between(rng, 2, 3))), 4),
      FlwProcess('n', _bin('-', _v('n'), _n(_between(rng, 1, 5))), 5),
      FlwShow(_v('n'), flwEnd),
    ]);
    return _FlwDraft('ambang', chart);
  }

  /// Dua keputusan berurutan: selisih lalu genap atau ganjil.
  _FlwDraft _twoStep(Rng rng) {
    // Cabang Ya selalu mengurangkan yang lebih besar, jadi c tidak negatif
    // dan MOD terdefinisi.
    final op = rng.pick(_ops);
    final aBigger = op == '>' || op == '>=';
    final chart = Flowchart([
      FlwProcess('a', _n(_between(rng, 3, 30)), 2),
      FlwProcess('b', _n(_between(rng, 3, 30)), 3),
      FlwDecision(_cmp(op, _v('a'), _v('b')), 4, 5),
      FlwProcess(
          'c',
          aBigger ? _bin('-', _v('a'), _v('b')) : _bin('-', _v('b'), _v('a')),
          6),
      FlwProcess(
          'c',
          aBigger ? _bin('-', _v('b'), _v('a')) : _bin('-', _v('a'), _v('b')),
          6),
      FlwDecision(
          _cmp('=', _bin('MOD', _v('c'), _n(2)), _n(rng.nextInt(2))), 7, 8),
      FlwShow(_bin('+', _v('c'), _n(_between(rng, 1, 9))), flwEnd),
      FlwShow(_bin('*', _v('c'), _n(_between(rng, 2, 3))), flwEnd),
    ]);
    return _FlwDraft('dua-keputusan', chart);
  }

  /// Keputusan bertingkat seperti penentuan nilai huruf.
  _FlwDraft _grade(Rng rng) {
    final high = _between(rng, 75, 90);
    final low = high - _between(rng, 10, 20);
    final score = _between(rng, low - 10, high + 10);
    final gradeHigh = _between(rng, 3, 4);
    final chart = Flowchart([
      FlwProcess('n', _n(score), 2),
      FlwDecision(_cmp(rng.pick(['>', '>=']), _v('n'), _n(high)), 3, 4),
      FlwProcess('g', _n(gradeHigh), 7),
      FlwDecision(_cmp(rng.pick(['>', '>=']), _v('n'), _n(low)), 5, 6),
      FlwProcess('g', _n(gradeHigh - 1), 7),
      FlwProcess('g', _n(gradeHigh - 2), 7),
      FlwShow(_bin('*', _v('g'), _n(10)), flwEnd),
    ]);
    return _FlwDraft('bertingkat', chart);
  }

  /// Perulangan dengan penghitung dan keputusan di dalamnya.
  _FlwDraft _loopSum(Rng rng) {
    final n = _between(rng, 4, 7);
    final m = _between(rng, 2, 3);
    final chart = Flowchart([
      FlwProcess('s', _n(0), 2),
      FlwProcess('i', _n(1), 3),
      FlwDecision(_cmp(rng.pick(['<', '<=']), _v('i'), _n(n)), 4, 7),
      FlwDecision(
          _cmp('=', _bin('MOD', _v('i'), _n(m)), _n(rng.nextInt(m))), 5, 6),
      FlwProcess('s', _bin('+', _v('s'), _v('i')), 6),
      FlwProcess('i', _bin('+', _v('i'), _n(1)), 3),
      FlwShow(_v('s'), flwEnd),
    ]);
    return _FlwDraft('ulang-jumlah', chart);
  }

  /// Perulangan yang mengurangi nilai sampai melewati batas.
  _FlwDraft _loopCount(Rng rng) {
    final step = _between(rng, 2, 5);
    final start = _between(rng, 15, 40);
    final chart = Flowchart([
      FlwProcess('x', _n(start), 2),
      FlwProcess('k', _n(0), 3),
      FlwDecision(
          _cmp(rng.pick(['>', '>=']), _v('x'), _n(_between(rng, 0, 9))), 4, 6),
      FlwProcess('x', _bin('-', _v('x'), _n(step)), 5),
      FlwProcess('k', _bin('+', _v('k'), _n(1)), 3),
      FlwShow(rng.nextBool() ? _v('k') : _v('x'), flwEnd),
    ]);
    return _FlwDraft('ulang-hitung', chart);
  }
}
