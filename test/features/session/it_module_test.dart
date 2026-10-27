import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';

import '../../support/fixtures.dart';
import '../../support/text_fit.dart';
import 'session_screen_test.dart' show openSession, tapButton, tapOption;

/// T24 F14: soal Modul IT memakai S06 apa adanya. Untuk tiap tipe dipilih
/// soal sulit dari 300 seed dengan kata tanpa spasi terpanjang (lalu teks
/// terpanjang), misalnya `FALSE)*VLOOKUP("Monitor";` di rumus Excel, lalu
/// diperiksa dengan font app sungguhan di 360 dp: tidak meluap dan tidak ada
/// kata yang terpotong di tengah.
int longestSeed(QuestionType type) {
  var best = 0;
  var bestScore = -1;
  for (var seed = 0; seed < 300; seed++) {
    final q = GeneratorRegistry.generate(type, seed, Difficulty.hard);
    final figure = q.stem.figure;
    final text = [
      q.stem.text ?? '',
      if (figure is TableFigure) ...figure.rows.expand((r) => r),
      for (final o in q.options) o.content.text ?? '',
    ].join(' ');
    final longestWord = text
        .split(RegExp(r'\s+'))
        .fold<int>(0, (m, w) => w.length > m ? w.length : m);
    final score = longestWord * 10000 + text.length;
    if (score > bestScore) {
      best = seed;
      bestScore = score;
    }
  }
  return best;
}

void main() {
  for (final type in [
    QuestionType.itPse,
    QuestionType.itFlw,
    QuestionType.itXls
  ]) {
    final seed = longestSeed(type);
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
          '${type.code} terpanjang di 360 dp, teks ${(scale * 100).round()}%',
          (tester) async {
        final app = await openSession(
          tester,
          SessionMode.latihan,
          SessionPlan(items: [
            PlanItem(
              type: type,
              seed: seed,
              difficulty: Difficulty.hard,
              genVersi: GeneratorRegistry.generator(type).version,
              subtes: 'it',
            ),
          ]),
          textScale: scale,
        );
        final q = app.sessionState!.question!;
        expect(q.type, type);
        expect(find.text(q.stem.text!), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: '${type.code} soal');

        await tapOption(tester, q.correctIndex);
        await tapButton(
            tester, 'Kirim jawaban ${q.options[q.correctIndex].id}');
        expect(find.text(q.explanation), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester, reason: '${type.code} pembahasan');
      });
    }
  }

  test('tiga tipe IT terdaftar dan masuk kategori it', () {
    for (final t in [
      QuestionType.itPse,
      QuestionType.itFlw,
      QuestionType.itXls
    ]) {
      expect(GeneratorRegistry.has(t), isTrue);
      expect(t.category.code, 'it');
    }
    // planItem fixture tetap bisa dipakai untuk tipe IT.
    expect(planItem(QuestionType.itXls, 1, 'it').subtes, 'it');
  });
}
