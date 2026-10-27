import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/features/session/session_widgets.dart';

import '../support/pump_app.dart';
import '../support/text_fit.dart';

/// Uji perangkat 2 (temuan 5): header tabel soal cerita ("Unduhan (ribu)",
/// "Pengguna aktif (ribu)") terpotong di tengah kata di skala 1,3 dan 2,0.
/// Diukur dengan font app sungguhan.
Question? firstWithHeader(String header) {
  for (var s = 1; s < 600; s++) {
    for (final d in Difficulty.values) {
      final q = GeneratorRegistry.generate(QuestionType.numWord, s * 31, d);
      final f = q.stem.figure;
      if (f is TableFigure && f.headers.any((h) => h.contains(header))) {
        return q;
      }
    }
  }
  return null;
}

Future<void> pumpQuestion(WidgetTester tester, Question q, double scale) =>
    pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: QuestionBody(question: q, selected: null, onSelect: (_) {}),
        ),
      ),
      textScale: scale,
    );

void main() {
  final versi = firstWithHeader('Unduhan');

  test('tabel Versi ditemukan di generator', () {
    expect(versi, isNotNull);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('tabel Versi: tidak ada kata terpotong di $scale',
        (tester) async {
      await pumpQuestion(tester, versi!, scale);
      expectNoMidWordBreaks(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('semua tabel soal cerita utuh di 1,3 dan 2,0', (tester) async {
    final seen = <String>{};
    for (var s = 1; s < 120; s++) {
      final q = GeneratorRegistry.generate(
          QuestionType.numWord, s * 17, Difficulty.values[s % 3]);
      final f = q.stem.figure;
      if (f is! TableFigure || !seen.add(f.headers.join('|'))) continue;
      for (final scale in [1.3, 2.0]) {
        await pumpQuestion(tester, q, scale);
        expectNoMidWordBreaks(tester,
            reason: 'tabel ${f.headers.join(', ')} di skala $scale');
      }
    }
    expect(seen.length, greaterThan(1));
  });

  testWidgets('di skala 2,0 tabel Versi bisa digulir mendatar bila perlu',
      (tester) async {
    await pumpQuestion(tester, versi!, 2.0);
    final scrollables = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    // Boleh menggulir atau memuat; yang wajib: tidak ada luapan.
    expect(tester.takeException(), isNull);
    expect(scrollables.evaluate().length, lessThanOrEqualTo(1));
  });
}
