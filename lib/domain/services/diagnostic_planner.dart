import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import '../models/session.dart';
import '../repositories/repositories.dart';
import 'practice_history.dart';
import 'question_timing.dart';
import 'item_allocator.dart';
import 'verbal_bank.dart';
import 'session_plan_builder.dart';

/// Rencana sesi diagnostik beserta kategori yang dilewati.
class DiagnosticPlan {
  const DiagnosticPlan({
    required this.plan,
    required this.categories,
    required this.skipped,
  });

  final SessionPlan plan;

  /// Kategori subtes berurutan, sama dengan `plan.subtes`.
  final List<String> categories;

  /// Kategori aktif di profil yang belum punya soal (A59); dilewati.
  final List<String> skipped;

  int get totalMinutes => plan.subtes.fold(0, (a, s) => a + (s.menit ?? 0));
}

/// Menyusun sesi diagnostik (F02): satu subtes bertimer untuk tiap kategori
/// aktif di profil yang punya soal, dengan jumlah menit seluruhnya paling
/// banyak 20. Waktu 20 menit dibagi rata antar kategori; jumlah soal tiap
/// subtes menyesuaikan perkiraan waktu per soal, dan semua tipe di kategori itu
/// muncul sedikitnya sekali sehingga kelemahan per tipe terukur.
class DiagnosticPlanner {
  DiagnosticPlanner({
    required AnswerRepository answers,
    required Set<QuestionType> available,
    VerbalBank? bank,
  })  : _answers = answers,
        _available = available,
        _bank = bank;

  static const int maxMinutes = 20;
  static const int minQuestionsPerSubtest = 3;
  static const int maxQuestionsPerSubtest = 12;

  final AnswerRepository _answers;
  final Set<QuestionType> _available;
  final VerbalBank? _bank;

  /// Null bila tidak ada kategori aktif yang punya soal.
  Future<DiagnosticPlan?> plan(TestProfile profile, DateTime now) async {
    final history = await PracticeHistory.load(_answers, now);
    return build(
      profile.blueprint,
      now: now,
      available: _available,
      avoid: history.seenKeys,
      bank: _bank,
    );
  }

  /// Bagian murni dari [plan], untuk test.
  static DiagnosticPlan? build(
    ProfileBlueprint blueprint, {
    required DateTime now,
    required Set<QuestionType> available,
    Set<String> avoid = const {},
    int Function(QuestionType type)? estimate,
    VerbalBank? bank,
  }) {
    final seconds = estimate ?? QuestionTiming.estimatedSeconds;
    final categories = <String, List<QuestionType>>{};
    final skipped = <String>[];
    for (final s in blueprint.subtes) {
      if (!s.aktif) continue;
      final types =
          SessionPlanBuilder.categoryTypes(s.kategori, available, bank: bank);
      if (types.isEmpty) {
        skipped.add(s.kategori);
      } else {
        categories[s.kategori] = types;
      }
    }
    if (categories.isEmpty) return null;

    final minutes = (maxMinutes ~/ categories.length).clamp(1, maxMinutes);
    final alloc = ItemAllocator(SessionPlanBuilder.seedBase(now),
        avoid: avoid, bank: bank);
    final items = <PlanItem>[];
    final subtests = <SubtestPlan>[];
    for (final MapEntry(key: kategori, value: types) in categories.entries) {
      final perQuestion =
          (types.map(seconds).reduce((a, b) => a + b) / types.length).round();
      final count = (minutes * 60 / perQuestion).round().clamp(
            types.length > minQuestionsPerSubtest
                ? types.length
                : minQuestionsPerSubtest,
            maxQuestionsPerSubtest,
          );
      for (var i = 0; i < count; i++) {
        final type = types[i % types.length];
        items.add(alloc.next(type, Difficulty.medium));
      }
      subtests.add(
        SubtestPlan(kategori: kategori, jumlah: count, menit: minutes),
      );
    }
    return DiagnosticPlan(
      plan: SessionPlan(items: items, subtes: subtests),
      categories: categories.keys.toList(),
      skipped: skipped,
    );
  }
}
