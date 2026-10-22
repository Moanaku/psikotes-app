import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

import 'support/property_harness.dart';

const _generator = NumSeqGenerator();
const _solver = NumSeqSolver();

List<String> numSeqBounds(Question q) {
  final issues = <String>[];
  final shown = parseSeqStem(q.stem.text);
  if (shown == null) return ['teks soal tidak terbaca: ${q.stem.text}'];
  final (lo, hi) = NumSeqGenerator.shownRange(q.difficulty);
  if (shown.length < lo || shown.length > hi) {
    issues.add('${shown.length} suku terlihat di luar $lo..$hi');
  }
  if (shown.length < 5 || shown.length > 8) {
    issues.add('panjang deret ${shown.length} di luar 5..8');
  }
  final limit = NumSeqGenerator.magnitudeLimit(q.difficulty);
  for (final v in shown) {
    if (v < 1 || v > limit) issues.add('suku $v di luar 1..$limit');
  }
  if (q.options.length != NumSeqGenerator.optionCount) {
    issues.add('jumlah opsi ${q.options.length}');
  }
  for (final o in q.options) {
    final v = int.tryParse(o.content.text ?? '');
    if (v == null || v < 1 || v > limit * 10) {
      issues.add('opsi bukan bilangan wajar: ${o.content.text}');
    }
  }
  if (q.tags.length != 1 || !q.tags.single.startsWith('rule:num-seq:')) {
    issues.add('tag aturan salah: ${q.tags}');
  }
  if (!q.explanation.toLowerCase().contains('suku berikutnya')) {
    issues.add('pembahasan tanpa suku berikutnya');
  }
  return issues;
}

void main() {
  PropertyHarness(_generator, _solver, bounds: numSeqBounds).register();

  Set<String> next(List<int> t) => predictNext(t);

  group('predictNext', () {
    test('aritmetika', () {
      expect(next([2, 4, 6, 8, 10]), {'12'});
      expect(next([30, 25, 20, 15, 10]), {'5'});
    });

    test('geometri', () {
      expect(next([2, 4, 8, 16, 32]), {'64'});
    });

    test('geometri dengan penambah', () {
      // kali 2 tambah 1: 3, 7, 15, 31, 63
      expect(next([3, 7, 15, 31, 63]), {'127'});
    });

    test('bertingkat: selisih naik tetap', () {
      // 1, 2, 4, 7, 11, 16 (selisih 1, 2, 3, 4, 5)
      expect(next([1, 2, 4, 7, 11, 16]), {'22'});
    });

    test('selang-seling dua deret aritmetika', () {
      expect(next([24, 7, 31, 8, 38, 9, 45]), {'10'});
      expect(next([24, 7, 31, 8, 38, 9]), {'45'});
    });

    test('selang-seling aritmetika dan geometri', () {
      expect(next([5, 2, 9, 4, 13, 8, 17]), {'16'});
    });

    test('jumlah dua suku sebelumnya', () {
      expect(next([1, 1, 2, 3, 5, 8]), contains('13'));
    });

    test('deret yang tidak punya pola yang dikenal tidak diramal', () {
      expect(next([3, 9, 2, 17, 5, 11]), isEmpty);
    });

    test('beberapa hipotesis yang cocok memberi ramalan yang sama', () {
      expect(next([1, 2, 4, 8, 16, 32]), {'64'});
      expect(next([1, 2, 4, 7, 11]), {'16'});
    });

    test('kurang dari empat suku tidak diramal', () {
      expect(next([1, 2, 3]), isEmpty);
    });
  });

  group('parser teks soal', () {
    test('bolak-balik', () {
      final text = seqStemText([3, 7, 11, 15, 19]);
      expect(text, 'Angka berikutnya dalam deret: 3, 7, 11, 15, 19, ?');
      expect(parseSeqStem(text), [3, 7, 11, 15, 19]);
    });

    test('bentuk lain ditolak', () {
      expect(parseSeqStem(null), isNull);
      expect(parseSeqStem('Lanjutkan 1, 2, ?'), isNull);
      expect(parseSeqStem('Angka berikutnya dalam deret: 1, a, 3, ?'), isNull);
    });
  });

  group('solver', () {
    Question make(List<int> shown, List<String> options) => Question(
          type: QuestionType.numSeq,
          seed: 1,
          difficulty: Difficulty.easy,
          stem: QuestionContent(text: seqStemText(shown)),
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

    test('memilih suku berikutnya', () {
      expect(_solver.validOptions(make([2, 4, 6, 8, 10], ['12', '11', '14'])),
          [0]);
    });

    test('deret bertingkat memilih selisih berikutnya', () {
      // 1, 2, 4, 7, 11, 16: selisih 1, 2, 3, 4, 5 -> suku berikutnya 22.
      final q = make([1, 2, 4, 7, 11, 16], ['22', '21', '23']);
      expect(_solver.validOptions(q), [0]);
    });

    test('teks opsi bukan bilangan tidak valid', () {
      expect(_solver.validOptions(make([2, 4, 6, 8, 10], ['dua belas', 'x'])),
          isEmpty);
    });
  });

  group('keluaran generator', () {
    test('semua jenis pola muncul', () {
      final tags = <String>{};
      for (var s = 0; s < 400; s++) {
        for (final d in Difficulty.values) {
          tags.addAll(_generator.generate(s, d).tags);
        }
      }
      expect(tags, {
        for (final f in SeqFamily.values) 'rule:num-seq:${f.code}',
      });
    });

    test('easy hanya aritmetika dan geometri', () {
      final tags = {
        for (var s = 0; s < 300; s++)
          ..._generator.generate(s, Difficulty.easy).tags,
      };
      expect(tags, {'rule:num-seq:arithmetic', 'rule:num-seq:geometric'});
    });
  });

  group('nilai emas lintas platform', () {
    test('seed 20481 medium', () {
      final q = _generator.generate(20481, Difficulty.medium);
      expect(q.tags, ['rule:num-seq:affine']);
      expect(q.correctIndex, 1);
      expect(
          q.stem.text,
          'Angka berikutnya dalam deret: 3, 10, 24, 52, 108, 220, 444, '
          '?');
      expect(
          q.explanation,
          'Aturan: kalikan 2 lalu tambah 4 (3 → 10 → 24, ...). Suku '
          'berikutnya: 444 × 2 + 4 = 892.');
    });
  });
}
