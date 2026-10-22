/// Generator NUM-SEQ (deret angka), docs/06-bank-konten.md, "Spesifikasi
/// ringkas tipe lain".
///
/// Jenis pola: aritmetika, geometri, geometri dengan penambah (kali r lalu
/// tambah c), selang-seling dua deret, dan bertingkat (selisih membentuk deret
/// aritmetika). Deret terlihat 5 sampai 8 suku; soal meminta suku berikutnya.
///
/// Solver menyimpulkan suku berikutnya dari deret yang tertulis di teks soal,
/// dengan pecahan eksak, dan mengumpulkan ramalan dari semua hipotesis yang
/// cocok dengan seluruh deret. Generator hanya menerima deret yang ramalannya
/// tepat satu nilai.
library;

import '../../fraction.dart';
import '../../generator.dart';
import '../../models.dart';
import '../../rng.dart';

enum SeqFamily {
  arithmetic('arithmetic'),
  geometric('geometric'),
  affine('affine'),
  alternating('alternating'),
  secondOrder('second-order');

  const SeqFamily(this.code);

  final String code;
}

const String _stemPrefix = 'Angka berikutnya dalam deret: ';

/// Suku deret ke dalam teks soal, diakhiri tanda tanya.
String seqStemText(List<int> shown) => '$_stemPrefix${shown.join(', ')}, ?';

/// Deret dari teks soal; null bila bentuknya tidak dikenal.
List<int>? parseSeqStem(String? text) {
  if (text == null || !text.startsWith(_stemPrefix) || !text.endsWith(', ?')) {
    return null;
  }
  final body = text.substring(_stemPrefix.length, text.length - 3);
  final out = <int>[];
  for (final part in body.split(', ')) {
    final v = int.tryParse(part);
    if (v == null) return null;
    out.add(v);
  }
  return out;
}

/// Semua ramalan suku berikutnya dari hipotesis yang cocok dengan [t].
Set<String> predictNext(List<int> t) {
  final out = <String>{};
  final n = t.length;
  if (n < 4) return out;
  void add(Fraction? f) {
    if (f != null) out.add(f.toString());
  }

  Fraction? safe(Fraction Function() f) {
    try {
      return f();
    } on FractionOverflow {
      return null;
    }
  }

  final f = [for (final v in t) Fraction(v)];

  // Aritmetika.
  if (_arithmetic(f)) add(f[n - 1] + (f[1] - f[0]));

  // Geometri dan geometri dengan penambah: t[i+1] = r * t[i] + c.
  final affine = _affine(f);
  if (affine != null) add(safe(() => affine.$1 * f[n - 1] + affine.$2));

  // Bertingkat: selisih membentuk deret aritmetika.
  final diffs = [for (var i = 1; i < n; i++) f[i] - f[i - 1]];
  if (_arithmetic(diffs)) {
    add(f[n - 1] + diffs.last + (diffs[1] - diffs[0]));
  }

  // Selisih membentuk deret geometri.
  final diffAffine = _affine(diffs);
  if (diffAffine != null && diffAffine.$2.isZero) {
    add(safe(() => f[n - 1] + diffAffine.$1 * diffs.last));
  }

  // Jumlah dua suku sebelumnya.
  var fib = true;
  for (var i = 2; i < n; i++) {
    if (!(f[i - 2] + f[i - 1]).equals(f[i])) fib = false;
  }
  if (fib) add(f[n - 1] + f[n - 2]);

  // Selang-seling: dua deret dari suku bernomor genap dan ganjil, masing-masing
  // aritmetika atau geometri. Suku berikutnya ikut deret yang memuatnya.
  final evens = [for (var i = 0; i < n; i += 2) f[i]];
  final odds = [for (var i = 1; i < n; i += 2) f[i]];
  if (evens.length >= 3 && odds.length >= 3) {
    final nextEven = _subsequenceNext(evens);
    final nextOdd = _subsequenceNext(odds);
    if (nextEven != null && nextOdd != null) {
      add(n.isEven ? nextEven : nextOdd);
    }
  }
  return out;
}

/// Suku berikutnya dari deret aritmetika atau geometri; null bila bukan
/// keduanya.
Fraction? _subsequenceNext(List<Fraction> s) {
  if (_arithmetic(s)) return s.last + (s[1] - s[0]);
  final a = _affine(s);
  if (a != null && a.$2.isZero) {
    try {
      return a.$1 * s.last;
    } on FractionOverflow {
      return null;
    }
  }
  return null;
}

bool _arithmetic(List<Fraction> s) {
  if (s.length < 3) return false;
  final d = s[1] - s[0];
  for (var i = 2; i < s.length; i++) {
    if (!(s[i] - s[i - 1]).equals(d)) return false;
  }
  return true;
}

/// (r, c) dengan s[i+1] = r * s[i] + c untuk semua i; null bila tidak ada
/// atau tidak tunggal (butuh sedikitnya tiga suku dan s[1] != s[0]).
(Fraction, Fraction)? _affine(List<Fraction> s) {
  if (s.length < 3) return null;
  final d0 = s[1] - s[0];
  if (d0.isZero) return null;
  try {
    final r = (s[2] - s[1]) / d0;
    final c = s[1] - r * s[0];
    for (var i = 0; i + 1 < s.length; i++) {
      if (!(r * s[i] + c).equals(s[i + 1])) return null;
    }
    return (r, c);
  } on FractionOverflow {
    return null;
  }
}

final class NumSeqSolver implements QuestionSolver {
  const NumSeqSolver();

  @override
  List<int> validOptions(Question question) {
    final shown = parseSeqStem(question.stem.text);
    if (shown == null) return const [];
    final predicted = predictNext(shown);
    return [
      for (var i = 0; i < question.options.length; i++)
        if (parseDisplayNumber(question.options[i].content.text ?? '')
            case final v? when predicted.contains(v.toString()))
          i,
    ];
  }
}

class NumSeqGenerator extends RetryingGenerator {
  const NumSeqGenerator();

  static const int optionCount = 5;

  /// Pengambilan parameter deret per percobaan.
  static const int paramTries = 10;

  @override
  QuestionType get type => QuestionType.numSeq;

  @override
  int get version => 1;

  @override
  QuestionSolver get solver => const NumSeqSolver();

  /// Batas mutlak suku menurut kesulitan ("besar angka").
  static int magnitudeLimit(Difficulty d) => switch (d) {
        Difficulty.easy => 200,
        Difficulty.medium => 2000,
        Difficulty.hard => 20000,
      };

  /// Jumlah suku terlihat: easy 5-6, medium 6-7, hard 7-8.
  static (int, int) shownRange(Difficulty d) => switch (d) {
        Difficulty.easy => (5, 6),
        Difficulty.medium => (6, 7),
        Difficulty.hard => (7, 8),
      };

  static List<SeqFamily> families(Difficulty d) => switch (d) {
        Difficulty.easy => const [SeqFamily.arithmetic, SeqFamily.geometric],
        Difficulty.medium => const [
            SeqFamily.affine,
            SeqFamily.alternating,
            SeqFamily.secondOrder,
          ],
        Difficulty.hard => const [
            SeqFamily.affine,
            SeqFamily.alternating,
            SeqFamily.secondOrder,
          ],
      };

  @override
  Question? build(Rng rng, int seed, Difficulty difficulty) {
    final (lo, hi) = shownRange(difficulty);
    final shownCount = lo + rng.nextInt(hi - lo + 1);
    final family = rng.pick(families(difficulty));
    final limit = magnitudeLimit(difficulty);

    // Resampling parameter di dalam satu percobaan: deret yang melampaui
    // batas besar angka atau punya dua ramalan berbeda dibuang.
    _Made? made;
    for (var t = 0; t < paramTries && made == null; t++) {
      final candidate = _make(rng, family, difficulty, shownCount + 1);
      if (candidate == null) continue;
      final ts = candidate.terms;
      if (ts.length != shownCount + 1 || ts.any((v) => v < 1 || v > limit)) {
        continue;
      }
      final predicted = predictNext(ts.take(shownCount).toList());
      if (predicted.length == 1 && predicted.single == '${ts[shownCount]}') {
        made = candidate;
      }
    }
    if (made == null) return null;
    final terms = made.terms;
    final shown = terms.take(shownCount).toList();
    final answer = terms[shownCount];

    final distractors = _distractors(rng, terms, shownCount, family);
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
      stem: QuestionContent(text: seqStemText(shown)),
      options: assembled.options,
      correctIndex: assembled.correctIndex,
      explanation: made.explain(shown, answer),
      estimatedSeconds: switch (difficulty) {
        Difficulty.easy => 30,
        Difficulty.medium => 45,
        Difficulty.hard => 60,
      },
      tags: ['rule:num-seq:${family.code}'],
    );
  }

  static _Made? _make(Rng rng, SeqFamily family, Difficulty d, int count) {
    switch (family) {
      case SeqFamily.arithmetic:
        final a = 1 + rng.nextInt(40);
        var step = 2 + rng.nextInt(8);
        // Menurun hanya bila semua suku tetap positif.
        if (rng.nextBool() && a - step * (count - 1) >= 1) step = -step;
        return _Made(
          [for (var i = 0; i < count; i++) a + step * i],
          (shown, answer) => 'Selisih tetap ${_signed(step)} tiap suku '
              '(${shown.take(3).join(', ')}, ...). Suku berikutnya: '
              '${shown.last} ${step < 0 ? '-' : '+'} ${step.abs()} = $answer.',
        );
      case SeqFamily.geometric:
        final a = 1 + rng.nextInt(d == Difficulty.easy ? 3 : 6);
        final r = d == Difficulty.easy ? 2 : 2 + rng.nextInt(2);
        return _Made(
          _recurrence(a, count, (t) => t * r),
          (shown, answer) => 'Setiap suku dikali $r '
              '(${shown.take(3).join(', ')}, ...). Suku berikutnya: '
              '${shown.last} × $r = $answer.',
        );
      case SeqFamily.affine:
        final a = 1 + rng.nextInt(6);
        final r = 2 + rng.nextInt(d == Difficulty.hard ? 3 : 2);
        var c = 1 + rng.nextInt(5);
        if (rng.nextBool()) c = -c;
        return _Made(
          _recurrence(a, count, (t) => t * r + c),
          (shown, answer) =>
              'Aturan: kalikan $r lalu ${c < 0 ? 'kurangi' : 'tambah'} '
              '${c.abs()} '
              '(${shown[0]} → ${shown[1]} → ${shown[2]}, ...). Suku berikutnya: '
              '${shown.last} × $r ${c < 0 ? '-' : '+'} ${c.abs()} = $answer.',
        );
      case SeqFamily.alternating:
        return _alternating(rng, d, count);
      case SeqFamily.secondOrder:
        final a = 1 + rng.nextInt(20);
        final e = 1 + rng.nextInt(d == Difficulty.hard ? 4 : 3);
        final d0 = 1 + rng.nextInt(5);
        final terms = <int>[a];
        for (var i = 1; i < count; i++) {
          terms.add(terms.last + d0 + e * (i - 1));
        }
        return _Made(
          terms,
          (shown, answer) {
            final diffs = [
              for (var i = 1; i < shown.length; i++) shown[i] - shown[i - 1],
            ];
            final next = diffs.last + e;
            return 'Selisih antar suku: ${diffs.join(', ')} (naik $e tiap '
                'langkah). Selisih berikutnya $next, jadi suku berikutnya: '
                '${shown.last} + $next = $answer.';
          },
        );
    }
  }

  static List<int> _recurrence(int a, int count, int Function(int) next) {
    final out = <int>[a];
    while (out.length < count) {
      out.add(next(out.last));
      if (out.last.abs() > 1000000) break;
    }
    return out;
  }

  /// Dua deret berselang: aritmetika dan aritmetika (medium), atau aritmetika
  /// dan geometri (hard). Setiap deret punya sedikitnya tiga suku terlihat.
  static _Made? _alternating(Rng rng, Difficulty d, int count) {
    if (count < 7) return null; // 6 suku terlihat: tiga per deret
    final a1 = 1 + rng.nextInt(30);
    final d1 = 1 + rng.nextInt(9);
    final up1 = rng.nextBool();
    final a2 = 1 + rng.nextInt(30);
    final geometric = d == Difficulty.hard && rng.nextBool();
    final d2 = 1 + rng.nextInt(9);
    final r2 = 2;
    final firstOf = [for (var k = 0; k < count; k++) a1 + (up1 ? d1 : -d1) * k];
    final secondOf = [
      for (var k = 0; k < count; k++)
        geometric ? a2 * _pow(r2, k) : a2 + d2 * k,
    ];
    final terms = [
      for (var i = 0; i < count; i++)
        i.isEven ? firstOf[i ~/ 2] : secondOf[i ~/ 2],
    ];
    return _Made(terms, (shown, answer) {
      final evens = [for (var i = 0; i < shown.length; i += 2) shown[i]];
      final odds = [for (var i = 1; i < shown.length; i += 2) shown[i]];
      final firstRule = '${up1 ? 'naik' : 'turun'} $d1';
      final secondRule = geometric ? 'dikali $r2' : 'naik $d2';
      final nextIsFirst = shown.length.isEven;
      final own = nextIsFirst ? evens : odds;
      final ownRule = nextIsFirst ? firstRule : secondRule;
      final op = nextIsFirst ? (up1 ? '+' : '-') : (geometric ? '×' : '+');
      final amount = nextIsFirst ? d1 : (geometric ? r2 : d2);
      return 'Deret selang-seling. Suku ke-1, 3, 5, ...: ${evens.join(', ')} '
          '($firstRule tiap langkah). Suku ke-2, 4, 6, ...: ${odds.join(', ')} '
          '($secondRule tiap langkah). Suku berikutnya ada di deret '
          '${nextIsFirst ? 'pertama' : 'kedua'} ($ownRule): '
          '${own.last} $op $amount = $answer.';
    });
  }

  static int _pow(int base, int exp) {
    var v = 1;
    for (var i = 0; i < exp; i++) {
      v *= base;
    }
    return v;
  }

  static String _signed(int v) => v < 0 ? '-${v.abs()}' : '+$v';

  /// Pengecoh: hasil pola yang hampir benar (melanjutkan dengan aturan lebih
  /// sederhana, selisih meleset satu), lalu angka di dekat jawaban.
  static List<int>? _distractors(
      Rng rng, List<int> terms, int shownCount, SeqFamily family) {
    final answer = terms[shownCount];
    final last = terms[shownCount - 1];
    final prev = terms[shownCount - 2];
    final lastDiff = last - prev;
    final step = answer - last;
    final patternFoils = <int>[
      last + lastDiff, // melanjutkan selisih terakhir (aritmetika)
      if (prev != 0 && last % prev == 0) last * (last ~/ prev),
      last + lastDiff + (lastDiff - (prev - terms[shownCount - 3])),
      answer + 1,
      answer - 1,
      last + step + 1, // selisih meleset satu
      last + step - 1,
      terms[shownCount - 2] + (last - terms[shownCount - 3]),
    ];
    final fillers = [
      answer + (step.abs() > 1 ? step.abs() ~/ 2 : 2),
      answer * 2 - last,
      answer + 2,
      answer - 2,
      answer + 3,
      answer - 3,
      answer + 5,
      answer + 10,
    ];
    final picked = <int>[];
    final seen = {answer};
    for (final v in [...rng.shuffle(patternFoils), ...fillers]) {
      if (picked.length == optionCount - 1) break;
      if (v >= 1 && seen.add(v)) picked.add(v);
    }
    return picked.length == optionCount - 1 ? picked : null;
  }
}

final class _Made {
  const _Made(this.terms, this.explain);

  final List<int> terms;
  final String Function(List<int> shown, int answer) explain;
}
