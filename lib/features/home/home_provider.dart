import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/providers.dart';
import '../../domain/services/answered_today.dart';
import '../../domain/services/daily_planner.dart';
import '../../domain/services/profile_validation.dart';
import '../../domain/services/session_controller.dart';

/// Sesi yang terputus dan bisa dilanjutkan.
class ResumeInfo {
  const ResumeInfo({
    required this.sessionId,
    required this.mode,
    required this.position,
    required this.total,
  });

  final int sessionId;
  final SessionMode mode;

  /// Nomor soal terakhir yang dibuka, mulai dari 1.
  final int position;
  final int total;
}

/// Semua yang dibutuhkan S04.
class HomeData {
  const HomeData({
    required this.profile,
    required this.plan,
    required this.weaknesses,
    required this.dueCount,
    required this.daysUntilTest,
    required this.answeredToday,
    this.resume,
  });

  final TestProfile profile;
  final DailyPlan plan;

  /// Tiga tipe terlemah; kosong bila belum ada riwayat.
  final List<WeaknessEntry> weaknesses;
  final int dueCount;

  /// Hari kalender sampai tanggal tes (0 = hari ini, negatif = sudah lewat);
  /// null bila tanggal tes belum diisi.
  final int? daysUntilTest;

  /// Soal yang dijawab pada hari kalender ini, semua sesi dan profil.
  final int answeredToday;

  /// Sesi profil aktif yang belum selesai; null bila tidak ada.
  final ResumeInfo? resume;
}

/// Data beranda. Null berarti belum ada profil aktif; router mengalihkan ke
/// onboarding, jadi layar menampilkan kondisi memuat sebentar. Dihitung ulang
/// saat profil berubah, kartu jatuh tempo berubah, atau sesi selesai.
final homeProvider = FutureProvider.autoDispose<HomeData?>((ref) async {
  // Berubah saat sesi dimulai, ditutup, atau selesai: sesi yang terputus dan
  // riwayat jawaban ikut berubah.
  ref.watch(
    sessionControllerProvider.select((s) => (s?.sessionId, s?.finished)),
  );
  final profiles = await ref.watch(profilesProvider.future);
  TestProfile? profile;
  for (final p in profiles) {
    if (p.aktif) profile = p;
  }
  if (profile == null) return null;

  ref.watch(dayProvider);
  final now = ref.watch(clockProvider).now();
  final plan = await ref.watch(dailyPlannerProvider).plan(profile, now);
  final weaknesses = await ref.watch(weaknessModelProvider).weakest(
        profile,
        now,
        count: 3,
      );
  final due = await ref.watch(dueCardsProvider.future);

  final unfinished = await ref
      .watch(sessionRepositoryProvider)
      .unfinished(profileId: profile.id);

  final answeredToday = await AnsweredToday(
    ref.watch(answerRepositoryProvider),
    ref.watch(clockProvider),
  ).count();

  final days = profile.tanggalTes
      ?.difference(ProfileValidation.dateOnly(now.toLocal()))
      .inDays;
  return HomeData(
    profile: profile,
    plan: plan,
    weaknesses: weaknesses,
    dueCount: due.length,
    daysUntilTest: days,
    answeredToday: answeredToday,
    resume: unfinished == null
        ? null
        : ResumeInfo(
            sessionId: unfinished.session.id,
            mode: unfinished.session.mode,
            position: unfinished.session.posisi + 1,
            total: unfinished.session.plan.items.length,
          ),
  );
});
