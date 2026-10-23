import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/review_planner.dart';
import 'package:simulator_psikotes_it/domain/services/seed_allocator.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 8);
  final available = {QuestionType.numSeq, QuestionType.figMtx};

  MistakeCard engine(int id, QuestionType type, int seed) => MistakeCard(
        id: id,
        tipe: type.code,
        kategori: type.category.code,
        seed: seed,
        sumber: AnswerSource.engine,
        jatuhTempo: now,
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
        dibuat: now,
      );

  MistakeCard other(int id, AnswerSource source, String tipe, int refId) =>
      MistakeCard(
        id: id,
        tipe: tipe,
        kategori: 'verbal',
        sumber: source,
        refId: refId,
        jatuhTempo: now,
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
        dibuat: now,
      );

  test('soal engine: tipe sama, seed baru, terhubung ke kartu', () {
    final due = [
      engine(1, QuestionType.numSeq, 7),
      engine(2, QuestionType.figMtx, 8),
    ];
    final r = ReviewPlanner.build(due, now: now, available: available);
    expect(r.plan.items.map((i) => i.type),
        [QuestionType.numSeq, QuestionType.figMtx]);
    expect(r.plan.items.map((i) => i.cardId), [1, 2]);
    expect(r.plan.items.map((i) => i.seed), isNot(contains(7)));
    expect(r.plan.items.map((i) => i.seed), isNot(contains(8)));
    expect(r.plan.items[0].seed, isNot(r.plan.items[1].seed));
    expect(r.sameItems, isEmpty);
    expect(r.skipped, isEmpty);
  });

  test('seed baru melewati pasangan (tipe, seed) 30 hari terakhir', () {
    final first = ReviewPlanner.build(
      [engine(1, QuestionType.numSeq, 7)],
      now: now,
      available: available,
    ).plan.items.single;
    final again = ReviewPlanner.build(
      [engine(1, QuestionType.numSeq, 7)],
      now: now,
      available: available,
      avoid: {SeedAllocator.key(QuestionType.numSeq, first.seed)},
    ).plan.items.single;
    expect(again.seed, isNot(first.seed));
  });

  test('seed asal kartu tidak dipakai kembali walau muncul dalam avoid', () {
    final r = ReviewPlanner.build(
      [engine(1, QuestionType.numSeq, 7)],
      now: now,
      available: available,
      avoid: {SeedAllocator.key(QuestionType.numSeq, 7)},
    );
    expect(r.plan.items.single.seed, isNot(7));
  });

  test('kartu Capture, bank, dan pengetahuan memakai butir yang sama', () {
    final due = [
      other(10, AnswerSource.capture, 'lipat-kertas', 42),
      other(11, AnswerSource.bank, 'VRB-SYN', 5),
      other(12, AnswerSource.pengetahuan, 'KB-QA', 3),
      engine(1, QuestionType.numSeq, 7),
    ];
    final r = ReviewPlanner.build(due, now: now, available: available);
    expect(r.plan.items, hasLength(1));
    expect(r.sameItems.map((s) => (s.cardId, s.sumber, s.tipe, s.refId)), [
      (10, AnswerSource.capture, 'lipat-kertas', 42),
      (11, AnswerSource.bank, 'VRB-SYN', 5),
      (12, AnswerSource.pengetahuan, 'KB-QA', 3),
    ]);
  });

  test('tipe tanpa generator atau tidak tersedia dilewati dan dilaporkan', () {
    final unknown = engine(5, QuestionType.logSyl, 3);
    final r = ReviewPlanner.build(
      [unknown, engine(1, QuestionType.numSeq, 7)],
      now: now,
      available: available,
    );
    expect(r.plan.items.map((i) => i.cardId), [1]);
    expect(r.skipped.map((c) => c.id), [5]);
  });

  test('kesulitan soal asal dipakai; tanpa data, medium', () {
    final due = [
      engine(1, QuestionType.numSeq, 7),
      engine(2, QuestionType.figMtx, 8),
    ];
    final r = ReviewPlanner.build(
      due,
      now: now,
      available: available,
      difficulty: (c) => c.id == 1 ? Difficulty.hard : Difficulty.medium,
    );
    expect(r.plan.items.map((i) => i.difficulty),
        [Difficulty.hard, Difficulty.medium]);
    expect(
      ReviewPlanner.build(due, now: now, available: available)
          .plan
          .items
          .map((i) => i.difficulty)
          .toSet(),
      {Difficulty.medium},
    );
  });

  test('satu ulangan paling banyak ${ReviewPlanner.maxCards} kartu', () {
    final due = [
      for (var i = 0; i < 35; i++) engine(i + 1, QuestionType.numSeq, i),
    ];
    final r = ReviewPlanner.build(due, now: now, available: available);
    expect(r.plan.items, hasLength(ReviewPlanner.maxCards));
    expect(r.plan.items.map((i) => i.cardId), [
      for (var i = 1; i <= ReviewPlanner.maxCards; i++) i,
    ]);
    expect({for (final i in r.plan.items) i.seed}, hasLength(20));
  });

  test('tanpa kartu: rencana kosong', () {
    final r = ReviewPlanner.build(const [], now: now, available: available);
    expect(r.plan.items, isEmpty);
    expect(r.sameItems, isEmpty);
  });

  test('PlanItem.cardId bertahan lewat JSON; tanpa kartu tidak ditulis', () {
    final r = ReviewPlanner.build(
      [engine(9, QuestionType.numSeq, 7)],
      now: now,
      available: available,
    );
    final item = r.plan.items.single;
    expect(item.toJson()['cardId'], 9);
    final json = r.plan.toJson();
    final back = (json['items']! as List).first as Map<String, Object?>;
    expect(back['cardId'], 9);
    final plain = SessionPlanBuilder.item(
      QuestionType.numSeq,
      1,
      Difficulty.medium,
    );
    expect(plain.toJson().containsKey('cardId'), isFalse);
    expect(PlanItem.fromJson(plain.toJson()).cardId, isNull);
    expect(PlanItem.fromJson(item.toJson()).cardId, 9);
  });
}
