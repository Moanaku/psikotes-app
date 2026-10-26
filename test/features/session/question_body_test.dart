import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/features/session/session_widgets.dart';

import '../../support/pump_app.dart';

TextStyle? stemStyle(WidgetTester tester, Question q) {
  final finder = find.text(q.stem.text!);
  expect(finder, findsOneWidget);
  return tester.widget<Text>(finder).style;
}

Future<TextStyle?> pumpStem(WidgetTester tester, Question q) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: QuestionBody(question: q, selected: null, onSelect: (_) {}),
      ),
    ),
  );
  return stemStyle(tester, q);
}

void main() {
  testWidgets('kalimat soal bergambar tampil tebal untuk semua tipe figural',
      (tester) async {
    final reference = await pumpStem(
      tester,
      GeneratorRegistry.generate(QuestionType.figMtx, 3, Difficulty.medium),
    );
    expect(reference!.fontWeight, isNot(FontWeight.w400));
    for (final type in [
      QuestionType.figMir,
      QuestionType.figSeq,
      QuestionType.figMtx,
      QuestionType.figOdd,
    ]) {
      for (final d in Difficulty.values) {
        final q = GeneratorRegistry.generate(type, 11, d);
        final style = await pumpStem(tester, q);
        expect(style!.fontWeight, reference.fontWeight,
            reason: '${type.code} ${d.code}');
        expect(style.fontSize, reference.fontSize,
            reason: '${type.code} ${d.code}');
      }
    }
  });

  testWidgets('teks panjang tanpa gambar tetap berupa paragraf biasa',
      (tester) async {
    final q =
        GeneratorRegistry.generate(QuestionType.logSyl, 5, Difficulty.hard);
    expect(q.stem.figure, isNull);
    expect(q.stem.text!.length, greaterThan(70));
    final style = await pumpStem(tester, q);
    final title = await pumpStem(
      tester,
      GeneratorRegistry.generate(QuestionType.figMtx, 3, Difficulty.medium),
    );
    expect(style!.fontSize, lessThan(title!.fontSize!));
  });
}
