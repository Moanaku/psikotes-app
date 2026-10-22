import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile.dart';
import '../../domain/providers.dart';
import '../../domain/services/daily_planner.dart';
import '../../domain/services/profile_validation.dart';
import '../../domain/services/session_controller.dart';

/// Semua yang dibutuhkan S04.
class HomeData {
  const HomeData({
    required this.profile,
    required this.plan,
    required this.weaknesses,
    required this.dueCount,
    required this.daysUntilTest,
  });

  final TestProfile profile;
  final DailyPlan plan;

  /// Tiga tipe terlemah; kosong bila belum ada riwayat.
  final List<WeaknessEntry> weaknesses;
  final int dueCount;

  /// Hari kalender sampai tanggal tes (0 = hari ini, negatif = sudah lewat);
  /// null bila tanggal tes belum diisi.
  final int? daysUntilTest;
}

/// Data beranda. Null berarti belum ada profil aktif; router mengalihkan ke
/// onboarding, jadi layar menampilkan kondisi memuat sebentar. Dihitung ulang
/// saat profil berubah, kartu jatuh tempo berubah, atau sesi selesai.
final homeProvider = FutureProvider.autoDispose<HomeData?>((ref) async {
  ref.watch(sessionControllerProvider.select((s) => s?.finished ?? false));
  final profiles = await ref.watch(profilesProvider.future);
  TestProfile? profile;
  for (final p in profiles) {
    if (p.aktif) profile = p;
  }
  if (profile == null) return null;

  final now = ref.watch(clockProvider).now();
  final plan = await ref.watch(dailyPlannerProvider).plan(profile, now);
  final weaknesses = await ref.watch(weaknessModelProvider).weakest(
        profile,
        now,
        count: 3,
      );
  final due = await ref.watch(dueCardsProvider.future);

  final days = profile.tanggalTes
      ?.difference(ProfileValidation.dateOnly(now.toLocal()))
      .inDays;
  return HomeData(
    profile: profile,
    plan: plan,
    weaknesses: weaknesses,
    dueCount: due.length,
    daysUntilTest: days,
  );
});
