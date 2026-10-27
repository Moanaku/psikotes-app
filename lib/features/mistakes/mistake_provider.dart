import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:question_engine/question_engine.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/notebook.dart';
import '../../domain/models/session.dart';
import '../../domain/providers.dart';
import '../../domain/services/capture_questions.dart';
import '../../domain/services/mistake_book.dart';

/// Filter sumber S10; bertahan selama layar terbuka.
final mistakeFilterProvider = StateProvider.autoDispose<MistakeFilter>(
  (ref) => MistakeFilter.semua,
);

/// Semua kartu buku kesalahan, diperbarui saat kartu berubah.
final mistakeCardsProvider = StreamProvider.autoDispose<List<MistakeCard>>(
  (ref) => ref.watch(mistakeRepositoryProvider).watchAll(),
);

/// Isi S10 untuk filter terpilih. Jam dari `Clock`, jadi test bisa mengatur
/// hari.
final mistakeBookProvider = Provider.autoDispose<AsyncValue<MistakeBookView>>(
  (ref) {
    final filter = ref.watch(mistakeFilterProvider);
    ref.watch(dayProvider);
    final now = ref.watch(clockProvider).now();
    return ref
        .watch(mistakeCardsProvider)
        .whenData((cards) => MistakeBookView.of(cards, now, filter));
  },
);

/// Pembahasan satu kartu: soal asal dibuat ulang dari (tipe, seed) dengan
/// kesulitan dan versi generator dari jawaban asalnya. [question] null bila
/// soal tidak bisa dibuat ulang (generator gagal, versi berbeda, atau bukan
/// soal engine).
class CardReview {
  const CardReview({
    required this.card,
    required this.type,
    this.question,
    this.captured,
  });

  final MistakeCard card;

  /// Null bila kode tipe kartu tidak dikenal (tipe buatan pengguna).
  final QuestionType? type;
  final Question? question;

  /// Soal Capture asal kartu (foto dan kategori), null untuk soal lain atau
  /// bila sudah dihapus.
  final CapturedQuestion? captured;
}

/// Kartu [id]; null bila tidak ada.
final cardReviewProvider =
    FutureProvider.autoDispose.family<CardReview?, int>((ref, id) async {
  final card = await ref.watch(mistakeRepositoryProvider).byId(id);
  if (card == null) return null;
  if (card.sumber == AnswerSource.capture) {
    final refId = card.refId;
    final saved = refId == null
        ? null
        : await ref.watch(captureRepositoryProvider).byId(refId);
    return CardReview(
      card: card,
      type: null,
      question: saved == null ? null : CaptureQuestions.toQuestion(saved),
      captured: saved,
    );
  }
  QuestionType? type;
  try {
    type = QuestionType.fromCode(card.tipe);
  } catch (_) {
    type = null;
  }
  if (type != null && card.sumber == AnswerSource.bank) {
    final bank = ref.watch(verbalBankProvider);
    final refId = card.refId;
    Question? question;
    if (bank != null && refId != null) {
      try {
        question = ref.watch(questionBuilderProvider)(PlanItem.bank(
          type: type,
          refId: refId,
          seed: 0,
          difficulty: Difficulty.medium,
          genVersi: bank.versi,
          subtes: type.category.code,
        ));
      } catch (_) {
        question = null;
      }
    }
    return CardReview(card: card, type: type, question: question);
  }
  if (type == null || card.sumber != AnswerSource.engine || card.seed == null) {
    return CardReview(card: card, type: type);
  }
  final origin = await ref
      .watch(answerRepositoryProvider)
      .latestEngineAnswer(card.tipe, card.seed!);
  Question? question;
  try {
    question = ref.watch(questionBuilderProvider)(PlanItem(
      type: type,
      seed: card.seed!,
      difficulty: origin?.kesulitan ?? Difficulty.medium,
      genVersi: origin?.genVersi ?? GeneratorRegistry.generator(type).version,
      subtes: type.category.code,
    ));
  } catch (_) {
    question = null;
  }
  return CardReview(card: card, type: type, question: question);
});
