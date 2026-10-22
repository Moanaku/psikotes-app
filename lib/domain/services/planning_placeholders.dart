import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import 'daily_planner.dart';
import 'session_plan_builder.dart';

/// Pengganti `DailyPlanner` sampai T13: campuran soal menurut bobot profil,
/// tanpa riwayat jawaban dan tanpa kartu buku kesalahan. Sama dengan rencana
/// untuk pengguna tanpa riwayat (docs/05-spek-layar.md, S04).
class PlaceholderDailyPlanner implements DailyPlanner {
  const PlaceholderDailyPlanner(this.available);

  /// Target durasi bawaan 15 menit (A3) dengan perkiraan 60 detik per soal.
  static const int targetMinutes = 15;
  static const int secondsPerQuestion = 60;

  final Set<QuestionType> available;

  @override
  Future<DailyPlan> plan(TestProfile profile, DateTime now) async {
    const count = targetMinutes * 60 ~/ secondsPerQuestion;
    final session = SessionPlanBuilder.mixed(
      profile.blueprint,
      now: now,
      count: count,
      available: available,
    );
    return DailyPlan(
      session: session,
      blocks: session.items.isEmpty
          ? const []
          : [const PlanBlock(kind: PlanBlockKind.mixed, count: count)],
      estimatedMinutes: targetMinutes,
    );
  }
}

/// Pengganti `WeaknessModel` sampai T13: belum ada riwayat, jadi daftar kosong
/// dan S04 menampilkan kondisi kosongnya.
class PlaceholderWeaknessModel implements WeaknessModel {
  const PlaceholderWeaknessModel();

  @override
  Future<List<WeaknessEntry>> weakest(
    TestProfile profile,
    DateTime now, {
    int count = 3,
  }) async =>
      const [];
}
