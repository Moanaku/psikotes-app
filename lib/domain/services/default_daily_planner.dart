import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/notebook.dart';
import '../models/profile.dart';
import '../models/session.dart';
import '../repositories/repositories.dart';
import 'daily_planner.dart';
import 'mistake_book.dart';
import 'practice_history.dart';
import 'profile_validation.dart';
import 'question_timing.dart';
import 'item_allocator.dart';
import 'verbal_bank.dart';
import 'session_plan_builder.dart';
import 'weakness_model.dart';

/// Pembagian jumlah soal rencana harian ke tiga bagian.
class PlanComposition {
  const PlanComposition({
    required this.weakest,
    required this.due,
    required this.mixed,
  });

  final int weakest;
  final int due;
  final int mixed;

  int get total => weakest + due + mixed;
}

/// Rencana latihan harian (F03, docs/03-data-model.md):
///
/// 1. `N = round(menit * 60 / median detik per soal)`; median dari riwayat 30
///    hari, atau `estimatedSeconds` engine bila belum ada riwayat.
/// 2. Kelemahan tiap tipe dari `WeaknessScoring` (tanpa data bernilai 0,5).
/// 3. Komposisi 50% tipe terlemah, 30% kartu buku kesalahan jatuh tempo (yang
///    kurang diisi dari kelemahan), 20% campuran sesuai bobot profil.
/// 4. Tanggal tes kurang dari 7 hari: satu subtes simulasi di akhir rencana.
/// 5. Tidak ada (tipe, seed) yang muncul dalam 30 hari terakhir.
///
/// Tanpa riwayat dan tanpa kartu jatuh tempo seluruh rencana adalah campuran
/// sesuai bobot profil (kondisi kosong S04).
class DefaultDailyPlanner implements DailyPlanner {
  DefaultDailyPlanner({
    required AnswerRepository answers,
    required MistakeRepository mistakes,
    required Set<QuestionType> available,
    VerbalBank? bank,
    this.targetMinutes = defaultMinutes,
    int Function(Iterable<QuestionType> types)? estimate,
  })  : _answers = answers,
        _mistakes = mistakes,
        _available = available,
        _bank = bank,
        _estimate = estimate ?? QuestionTiming.medianOf;

  /// Target durasi bawaan 15 menit (A3).
  static const int defaultMinutes = 15;

  static const double weakestShare = 0.5;
  static const double dueShare = 0.3;
  static const double mixedShare = 0.2;

  /// Tanggal tes kurang dari ini (dalam hari) menambah blok simulasi.
  static const int testSoonDays = 7;

  static const int minQuestions = 5;
  static const int maxQuestions = 60;

  final AnswerRepository _answers;
  final MistakeRepository _mistakes;
  final Set<QuestionType> _available;
  final VerbalBank? _bank;
  final int targetMinutes;
  final int Function(Iterable<QuestionType> types) _estimate;

  /// Membagi [total] soal menurut 50/30/20 dengan metode sisa terbesar
  /// (selisih tiap bagian dari angka eksak kurang dari satu soal). Jatah kartu
  /// dibatasi [dueAvailable]; kekurangannya menambah bagian kelemahan.
  static PlanComposition compose(int total, {required int dueAvailable}) {
    final exact = [
      total * weakestShare,
      total * dueShare,
      total * mixedShare,
    ];
    final counts = [for (final e in exact) e.floor()];
    final order = [0, 1, 2]..sort((a, b) {
        final byRemainder =
            (exact[b] - counts[b]).compareTo(exact[a] - counts[a]);
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    var leftover = total - counts.fold(0, (a, b) => a + b);
    for (var i = 0; leftover > 0; i++, leftover--) {
      counts[order[i]]++;
    }
    final due = counts[1] < dueAvailable ? counts[1] : dueAvailable;
    return PlanComposition(
      weakest: counts[0] + (counts[1] - due),
      due: due,
      mixed: counts[2],
    );
  }

  @override
  Future<DailyPlan> plan(TestProfile profile, DateTime now) async {
    final blueprint = profile.blueprint;
    final candidates =
        WeaknessScoring.candidates(blueprint, _available, bank: _bank);
    if (candidates.isEmpty) {
      return const DailyPlan(
        session: SessionPlan(items: []),
        blocks: [],
        estimatedMinutes: 0,
      );
    }

    final history = await PracticeHistory.load(_answers, now);
    final dueCards = [
      for (final c in await _mistakes.watchDue(DueDay.cutoff(now)).first)
        if (_usable(c)) c,
    ];

    final seconds = history.medianSeconds ?? _estimate(candidates);
    final total = (targetMinutes * 60 / seconds)
        .round()
        .clamp(minQuestions, maxQuestions);

    final alloc = ItemAllocator(
      SessionPlanBuilder.seedBase(now),
      avoid: history.seenKeys,
      bank: _bank,
    );
    final items = <PlanItem>[];
    final blocks = <PlanBlock>[];
    QuestionType? weakest;

    void add(QuestionType type, {String? subtes, int? cardId}) => items.add(
          alloc.next(type, Difficulty.medium, subtes: subtes, cardId: cardId),
        );

    if (history.isEmpty && dueCards.isEmpty) {
      for (final t in SessionPlanBuilder.mixedTypes(blueprint,
          count: total, available: _available, bank: _bank)) {
        add(t);
      }
      if (items.isNotEmpty) {
        blocks.add(PlanBlock(kind: PlanBlockKind.mixed, count: items.length));
      }
    } else {
      final parts = compose(total, dueAvailable: dueCards.length);
      final ranked = WeaknessScoring.rank(history, blueprint, candidates);
      weakest = ranked.first.type;

      if (parts.weakest > 0) {
        for (var i = 0; i < parts.weakest; i++) {
          add(weakest);
        }
        blocks.add(PlanBlock(
          kind: PlanBlockKind.weakest,
          count: parts.weakest,
          type: weakest,
        ));
      }
      if (parts.due > 0) {
        for (final card in dueCards.take(parts.due)) {
          if (card.sumber == AnswerSource.capture) {
            items.add(PlanItem.capture(
              refId: card.refId!,
              kategori: card.kategori,
              subtes: SubtestPlan.mixedLabel,
              cardId: card.id,
            ));
          } else if (card.sumber == AnswerSource.bank) {
            final type = QuestionType.fromCode(card.tipe);
            final picked = _bank!.byRef(type, card.refId!)!;
            items.add(PlanItem.bank(
              type: type,
              refId: picked.number,
              seed: 0,
              difficulty: picked.difficulty,
              genVersi: _bank.versi,
              subtes: type.category.code,
              cardId: card.id,
            ));
          } else {
            add(QuestionType.fromCode(card.tipe), cardId: card.id);
          }
        }
        blocks.add(PlanBlock(kind: PlanBlockKind.due, count: parts.due));
      }
      if (parts.mixed > 0) {
        final types = SessionPlanBuilder.mixedTypes(blueprint,
            count: parts.mixed, available: _available, bank: _bank);
        for (final t in types) {
          add(t);
        }
        if (types.isNotEmpty) {
          blocks.add(PlanBlock(kind: PlanBlockKind.mixed, count: types.length));
        }
      }
    }

    var minutes = (items.length * seconds / 60).round();
    var subtests = const <SubtestPlan>[];
    final simulation = _simulation(profile, now, weakest);
    if (simulation != null && items.isNotEmpty) {
      final practiceCount = items.length;
      for (var i = 0; i < practiceCount; i++) {
        items[i] = items[i].withSubtes(SubtestPlan.mixedLabel);
      }
      final types = SessionPlanBuilder.categoryTypes(
          simulation.kategori, _available,
          bank: _bank);
      for (var i = 0; i < simulation.jumlah; i++) {
        add(types[i % types.length]);
      }
      subtests = [
        SubtestPlan(kategori: SubtestPlan.mixedLabel, jumlah: practiceCount),
        SubtestPlan(
          kategori: simulation.kategori,
          jumlah: simulation.jumlah,
          menit: simulation.menit,
        ),
      ];
      blocks.add(PlanBlock(
        kind: PlanBlockKind.simulation,
        count: simulation.jumlah,
        kategori: simulation.kategori,
        minutes: simulation.menit,
      ));
      minutes += simulation.menit;
    }

    return DailyPlan(
      session: SessionPlan(items: items, subtes: subtests),
      blocks: blocks,
      estimatedMinutes: minutes,
    );
  }

  /// Kartu yang bisa dijadikan soal: soal engine dengan tipe yang terdaftar,
  /// atau soal Capture atau bank yang punya `ref_id` (butir bank harus ada di
  /// bank yang termuat). Kartu pengetahuan menunggu pemakainya (T25).
  bool _usable(MistakeCard c) {
    if (c.sumber == AnswerSource.capture) return c.refId != null;
    if (c.sumber == AnswerSource.bank) {
      final bank = _bank;
      final refId = c.refId;
      if (bank == null || refId == null) return false;
      for (final t in VerbalBank.bankTypes) {
        if (t.code == c.tipe) return bank.byRef(t, refId) != null;
      }
      return false;
    }
    if (c.sumber != AnswerSource.engine) return false;
    for (final t in _available) {
      if (t.code == c.tipe) return GeneratorRegistry.has(t);
    }
    return false;
  }

  /// Subtes simulasi bila tanggal tes 0 sampai 6 hari lagi: kategori tipe
  /// terlemah (atau kategori berbobot terbesar bila belum ada riwayat), dengan
  /// jumlah soal dan menit dari blueprint.
  ({String kategori, int jumlah, int menit})? _simulation(
    TestProfile profile,
    DateTime now,
    QuestionType? weakest,
  ) {
    final date = profile.tanggalTes;
    if (date == null) return null;
    final days =
        date.difference(ProfileValidation.dateOnly(now.toLocal())).inDays;
    if (days < 0 || days >= testSoonDays) return null;

    final specs = [
      for (final s in profile.blueprint.subtes)
        if (s.aktif &&
            (profile.blueprint.bobot[s.kategori] ?? 0) > 0 &&
            SessionPlanBuilder.categoryTypes(s.kategori, _available,
                    bank: _bank)
                .isNotEmpty)
          s,
    ];
    if (specs.isEmpty) return null;
    SubtestSpec? chosen;
    if (weakest != null) {
      for (final s in specs) {
        if (s.kategori == weakest.category.code) chosen = s;
      }
    }
    chosen ??= specs.reduce((best, s) =>
        (profile.blueprint.bobot[s.kategori] ?? 0) >
                (profile.blueprint.bobot[best.kategori] ?? 0)
            ? s
            : best);
    return (
      kategori: chosen.kategori,
      jumlah: chosen.jumlah,
      menit: chosen.menit
    );
  }
}
