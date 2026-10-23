import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/capture_questions.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';

import '../support/fake_repositories.dart';

final DateTime now = DateTime.utc(2026, 10, 22, 8);

CapturedQuestion cap(
  int id, {
  String teks = 'Soal',
  String? note,
  int key = 1,
}) =>
    CapturedQuestion(
      id: id,
      teks: teks,
      opsi: const ['a', 'b', 'c'],
      kunci: key,
      pembahasan: note,
      kategori: 'lipat kertas',
      dibuat: now,
    );

void main() {
  group('PlanItem Capture', () {
    test('JSON bolak-balik, tanpa seed dan kesulitan engine', () {
      const item = PlanItem.capture(
        refId: 9,
        kategori: 'lipat kertas',
        subtes: 'campuran',
        cardId: 3,
      );
      final back = PlanItem.fromJson(item.toJson());
      expect(back.isCapture, isTrue);
      expect(back.source, AnswerSource.capture);
      expect(back.refId, 9);
      expect(back.cardId, 3);
      expect(back.type, isNull);
      expect(back.tipeCode, PlanItem.captureTipe);
      expect(back.kategoriCode, 'lipat kertas');
      expect(item.toJson().containsKey('seed'), isFalse);
    });

    test('rencana lama tanpa kunci sumber tetap terbaca sebagai engine', () {
      final item = PlanItem.fromJson({
        'type': 'NUM-SEQ',
        'seed': 5,
        'difficulty': 'medium',
        'genVersi': 1,
        'subtes': 'numerik',
      });
      expect(item.isCapture, isFalse);
      expect(item.type, QuestionType.numSeq);
      expect(item.kategoriCode, 'numerik');
    });

    test('withSubtes mempertahankan sumber', () {
      const item =
          PlanItem.capture(refId: 1, kategori: 'x', subtes: 'campuran');
      final moved = item.withSubtes('lain');
      expect(moved.isCapture, isTrue);
      expect(moved.subtes, 'lain');
      expect(moved.refId, 1);
    });
  });

  group('CaptureQuestions.toQuestion', () {
    test('opsi, kunci, dan pembahasan dibawa', () {
      final q = CaptureQuestions.toQuestion(cap(1, note: 'Karena b.'));
      expect(q.options.map((o) => o.id), ['A', 'B', 'C']);
      expect(q.options[1].content.text, 'b');
      expect(q.correctIndex, 1);
      expect(q.explanation, 'Karena b.');
      expect(q.stem.text, 'Soal');
      expect(q.validate(), isEmpty);
    });

    test('tanpa pembahasan: kalimat yang menyebut kunci', () {
      final q = CaptureQuestions.toQuestion(cap(1, key: 2));
      expect(q.explanation, startsWith('Kunci jawaban: C.'));
    });

    test('soal hanya foto: stem menunjuk ke foto', () {
      final q = CaptureQuestions.toQuestion(cap(1, teks: ''));
      expect(q.stem.text, CaptureQuestions.photoOnlyStem);
      expect(q.validate(), isEmpty);
    });
  });

  group('questionBuilderFor', () {
    test('memuat soal Capture dan membuat soal engine lewat builder', () async {
      final repo = FakeCaptureRepository([cap(1)]);
      const plan = SessionPlan(items: [
        PlanItem.capture(
          refId: 1,
          kategori: 'lipat kertas',
          subtes: 'campuran',
        ),
        PlanItem.capture(
          refId: 99,
          kategori: 'lipat kertas',
          subtes: 'campuran',
        ),
        PlanItem(
          type: QuestionType.numSeq,
          seed: 1,
          difficulty: Difficulty.easy,
          genVersi: 1,
          subtes: 'numerik',
        ),
      ]);
      final build = await questionBuilderFor(
        plan,
        () => repo,
        (item) => CaptureQuestions.toQuestion(cap(0, teks: 'engine')),
      );
      expect(build(plan.items[0]).stem.text, 'Soal');
      expect(() => build(plan.items[1]), throwsA(isA<QuestionUnavailable>()),
          reason: 'soal sudah dihapus');
      expect(build(plan.items[2]).stem.text, 'engine');
    });
  });

  group('SessionPlanBuilder.capture', () {
    test('paling banyak sepuluh, urutan tetap untuk waktu yang sama', () {
      final all = [for (var i = 1; i <= 14; i++) cap(i)];
      final a = SessionPlanBuilder.capture(all, now: now);
      final b = SessionPlanBuilder.capture(all, now: now);
      expect(a.items, hasLength(SessionPlanBuilder.practiceCount));
      expect(a.items.map((i) => i.refId), b.items.map((i) => i.refId));
      expect(a.items.map((i) => i.refId).toSet(), hasLength(10),
          reason: 'tanpa soal kembar');
      expect(a.items.every((i) => i.isCapture && i.cardId == null), isTrue);
    });

    test('bank kecil dipakai semuanya; bank kosong menghasilkan rencana kosong',
        () {
      expect(SessionPlanBuilder.capture([cap(1), cap(2)], now: now).items,
          hasLength(2));
      expect(SessionPlanBuilder.capture(const [], now: now).items, isEmpty);
    });
  });
}
