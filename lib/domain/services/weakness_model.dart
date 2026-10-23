import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import '../repositories/repositories.dart';
import 'daily_planner.dart';
import 'practice_history.dart';
import 'session_plan_builder.dart';

/// Skor kelemahan satu tipe.
class TypeScore {
  const TypeScore({
    required this.type,
    required this.benar,
    required this.jumlah,
  });

  final QuestionType type;
  final int benar;

  /// Jumlah jawaban yang dihitung, paling banyak [WeaknessScoring.lastAnswers].
  final int jumlah;

  /// Akurasi yang dihaluskan `(benar + 1) / (jumlah + 2)`. Tipe tanpa data
  /// bernilai 0,5 sehingga tipe baru tidak langsung menjadi yang terlemah.
  double get accuracy => (benar + 1) / (jumlah + 2);

  /// Skor kelemahan `w = 1 - accuracy`; tipe tanpa data 0,5.
  double get weakness => 1 - accuracy;
}

abstract final class WeaknessScoring {
  /// Jawaban terbaru per tipe yang dihitung (docs/03-data-model.md).
  static const int lastAnswers = 30;

  /// Tipe yang bisa dilatih untuk profil: terdaftar di [available], kategorinya
  /// aktif di blueprint dan berbobot lebih dari nol. Urut menurut katalog.
  static List<QuestionType> candidates(
    ProfileBlueprint blueprint,
    Set<QuestionType> available,
  ) {
    final result = <QuestionType>{};
    for (final s in blueprint.subtes) {
      if (!s.aktif || (blueprint.bobot[s.kategori] ?? 0) <= 0) continue;
      result.addAll(SessionPlanBuilder.categoryTypes(s.kategori, available));
    }
    return result.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  /// Skor tiap tipe di [types], dari yang terlemah. Imbang diurutkan menurut
  /// bobot kategori profil, lalu yang lebih sedikit datanya, lalu katalog.
  static List<TypeScore> rank(
    PracticeHistory history,
    ProfileBlueprint blueprint,
    Iterable<QuestionType> types,
  ) {
    final benar = <QuestionType, int>{};
    final jumlah = <QuestionType, int>{};
    for (final (type, a) in history.typedAnswers()) {
      // Soal yang tidak dijawab dihitung salah pada skor sesi, tetapi bukan
      // bukti lemah di tipe itu (A63).
      if (a.opsiDipilih == null) continue;
      final n = jumlah[type] ?? 0;
      if (n >= lastAnswers) continue;
      jumlah[type] = n + 1;
      if (a.benar) benar[type] = (benar[type] ?? 0) + 1;
    }
    final scores = [
      for (final t in types)
        TypeScore(type: t, benar: benar[t] ?? 0, jumlah: jumlah[t] ?? 0),
    ];
    double weight(TypeScore s) => blueprint.bobot[s.type.category.code] ?? 0;
    scores.sort((a, b) {
      final byWeakness = b.weakness.compareTo(a.weakness);
      if (byWeakness != 0) return byWeakness;
      final byWeight = weight(b).compareTo(weight(a));
      if (byWeight != 0) return byWeight;
      final byData = a.jumlah.compareTo(b.jumlah);
      if (byData != 0) return byData;
      return a.type.index.compareTo(b.type.index);
    });
    return scores;
  }
}

/// `WeaknessModel` dari riwayat jawaban 30 hari terakhir.
class HistoryWeaknessModel implements WeaknessModel {
  const HistoryWeaknessModel(this._answers, this._available);

  final AnswerRepository _answers;
  final Set<QuestionType> _available;

  /// Hanya tipe yang punya jawaban yang ditampilkan: tipe tanpa data (0,5)
  /// dipakai perencana, tetapi bukan "kelemahan" yang terukur.
  @override
  Future<List<WeaknessEntry>> weakest(
    TestProfile profile,
    DateTime now, {
    int count = 3,
  }) async {
    final history = await PracticeHistory.load(_answers, now);
    if (history.isEmpty) return const [];
    final ranked = WeaknessScoring.rank(
      history,
      profile.blueprint,
      WeaknessScoring.candidates(profile.blueprint, _available),
    );
    return [
      for (final s in ranked.where((s) => s.jumlah > 0).take(count))
        WeaknessEntry(type: s.type, accuracy: s.accuracy, answered: s.jumlah),
    ];
  }
}
