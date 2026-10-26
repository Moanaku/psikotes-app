import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/notebook.dart';
import '../models/session.dart';
import 'item_allocator.dart';
import 'verbal_bank.dart';
import 'session_plan_builder.dart';

/// Kartu bank dan pengetahuan yang diulang dengan butir yang sama. Belum bisa
/// masuk `SessionPlan` karena belum ada pemakai bank dan pengetahuan (T07,
/// T25); daftar ini menjaga identitas butirnya. Kartu Capture sudah masuk
/// rencana lewat `PlanItem.capture` (T18).
class SameItemReview {
  const SameItemReview({
    required this.cardId,
    required this.sumber,
    required this.tipe,
    required this.refId,
  });

  final int cardId;
  final AnswerSource sumber;
  final String tipe;
  final int? refId;
}

class ReviewPlan {
  const ReviewPlan({
    required this.plan,
    required this.sameItems,
    required this.skipped,
  });

  /// Soal engine dengan seed baru, satu per kartu, urut jatuh tempo.
  final SessionPlan plan;

  /// Kartu bank dan pengetahuan yang diulang dengan butir yang sama.
  final List<SameItemReview> sameItems;

  /// Kartu soal engine yang tipenya tidak punya generator di app ini.
  final List<MistakeCard> skipped;
}

QuestionType? _bankType(String code, VerbalBank? bank) {
  if (bank == null) return null;
  for (final t in VerbalBank.bankTypes) {
    if (t.code == code && bank.has(t)) return t;
  }
  return null;
}

/// Menyusun ulangan dari kartu jatuh tempo (F07): soal engine memakai tipe
/// yang sama dengan seed baru; soal Capture, bank, dan pengetahuan memakai
/// butir yang sama.
abstract final class ReviewPlanner {
  /// Paling banyak kartu dalam satu ulangan (A80).
  static const int maxCards = 20;

  /// [difficulty] memberi kesulitan soal asal kartu; tanpa data, medium.
  /// [avoid] adalah pasangan (tipe, seed) 30 hari terakhir.
  static ReviewPlan build(
    List<MistakeCard> due, {
    required DateTime now,
    required Set<QuestionType> available,
    Set<String> avoid = const {},
    Difficulty Function(MistakeCard card)? difficulty,
    VerbalBank? bank,
  }) {
    final alloc = ItemAllocator(SessionPlanBuilder.seedBase(now),
        avoid: avoid, bank: bank);
    final items = <PlanItem>[];
    final same = <SameItemReview>[];
    final skipped = <MistakeCard>[];
    for (final card in due.take(maxCards)) {
      if (card.sumber == AnswerSource.capture && card.refId != null) {
        items.add(PlanItem.capture(
          refId: card.refId!,
          kategori: card.kategori,
          subtes: SubtestPlan.mixedLabel,
          cardId: card.id,
        ));
        continue;
      }
      if (card.sumber == AnswerSource.bank && card.refId != null) {
        final type = _bankType(card.tipe, bank);
        final picked = type == null ? null : bank!.byRef(type, card.refId!);
        if (picked != null) {
          items.add(PlanItem.bank(
            type: type!,
            refId: picked.number,
            seed: 0,
            difficulty: picked.difficulty,
            genVersi: bank!.versi,
            subtes: type.category.code,
            cardId: card.id,
          ));
          continue;
        }
      }
      if (card.sumber != AnswerSource.engine) {
        same.add(SameItemReview(
          cardId: card.id,
          sumber: card.sumber,
          tipe: card.tipe,
          refId: card.refId,
        ));
        continue;
      }
      QuestionType? type;
      for (final t in available) {
        if (t.code == card.tipe) type = t;
      }
      if (type == null || !GeneratorRegistry.has(type)) {
        skipped.add(card);
        continue;
      }
      items.add(alloc.next(
        type,
        difficulty?.call(card) ?? Difficulty.medium,
        cardId: card.id,
      ));
    }
    return ReviewPlan(
      plan: SessionPlan(items: items),
      sameItems: same,
      skipped: skipped,
    );
  }
}
