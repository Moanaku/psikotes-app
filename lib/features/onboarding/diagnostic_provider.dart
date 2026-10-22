import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/session.dart';
import '../../domain/models/session_state.dart';
import '../../domain/providers.dart';
import '../../domain/services/diagnostic_planner.dart';
import '../../domain/services/scoring.dart';
import '../../domain/services/session_controller.dart';

/// Keadaan satu subtes di daftar progres S03.
enum SubtestProgress { selesai, berjalan, belum }

class DiagnosticRow {
  const DiagnosticRow({
    required this.kategori,
    required this.progress,
    this.jumlah,
    this.menit,
  });

  final String kategori;
  final SubtestProgress progress;
  final int? jumlah;
  final int? menit;
}

/// Hasil diagnostik yang sudah selesai: akurasi dan median per kategori.
class DiagnosticResult {
  const DiagnosticResult({required this.sessionId, required this.categories});

  final int sessionId;

  /// Berurutan seperti subtes sesinya.
  final List<CategoryScore> categories;

  /// Kategori dengan akurasi terendah; imbang jatuh ke yang lebih dulu.
  String get weakest {
    var worst = categories.first;
    for (final c in categories) {
      if (c.akurasi < worst.akurasi) worst = c;
    }
    return worst.kategori;
  }
}

/// Semua yang dibutuhkan S03.
class DiagnosticData {
  const DiagnosticData({
    required this.profile,
    required this.plan,
    required this.rows,
    this.unfinishedId,
    this.result,
  });

  final TestProfile profile;

  /// Rencana untuk memulai diagnostik baru; null bila tidak ada kategori aktif
  /// yang punya soal.
  final DiagnosticPlan? plan;
  final List<DiagnosticRow> rows;

  /// Sesi diagnostik yang terputus; bisa dilanjutkan.
  final int? unfinishedId;

  /// Diagnostik terakhir yang selesai; hasil lama tetap tersimpan saat diulang.
  final DiagnosticResult? result;

  bool get canStart => plan != null;
}

/// Data S03. Null berarti belum ada profil aktif. Dihitung ulang saat sesi
/// selesai.
final diagnosticProvider =
    FutureProvider.autoDispose<DiagnosticData?>((ref) async {
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
  if (profile == null || profile.id == null) return null;

  final now = ref.watch(clockProvider).now();
  final sessions = ref.watch(sessionRepositoryProvider);
  final plan = await ref.watch(diagnosticPlannerProvider).plan(profile, now);

  final snapshot = await sessions.unfinished(profileId: profile.id);
  final unfinished =
      snapshot != null && snapshot.session.mode == SessionMode.diagnostik
          ? snapshot
          : null;

  DiagnosticResult? result;
  final finished =
      await sessions.latestFinished(profile.id!, SessionMode.diagnostik);
  if (finished != null && finished.plan.items.isNotEmpty) {
    final answers =
        await ref.watch(answerRepositoryProvider).forSession(finished.id);
    final summary = Scoring.summarize(finished.plan, answers);
    final order = [for (final s in SubtestRange.of(finished.plan)) s.kategori];
    final categories = [
      for (final k in order)
        if (summary.perKategori[k] != null) summary.perKategori[k]!,
    ];
    if (categories.isNotEmpty) {
      result = DiagnosticResult(sessionId: finished.id, categories: categories);
    }
  }

  final List<DiagnosticRow> rows;
  if (unfinished != null) {
    final ranges = SubtestRange.of(unfinished.session.plan);
    final current = ranges
        .indexWhere((r) => r.contains(unfinished.session.posisi))
        .clamp(0, ranges.length - 1);
    rows = [
      for (final r in ranges)
        DiagnosticRow(
          kategori: r.kategori,
          jumlah: r.jumlah,
          menit: r.duration?.inMinutes,
          progress: r.index < current
              ? SubtestProgress.selesai
              : r.index == current
                  ? SubtestProgress.berjalan
                  : SubtestProgress.belum,
        ),
    ];
  } else if (result != null) {
    rows = [
      for (final c in result.categories)
        DiagnosticRow(
          kategori: c.kategori,
          jumlah: c.jumlah,
          progress: SubtestProgress.selesai,
        ),
    ];
  } else {
    rows = [
      for (final s in plan?.plan.subtes ?? const <SubtestPlan>[])
        DiagnosticRow(
          kategori: s.kategori,
          jumlah: s.jumlah,
          menit: s.menit,
          progress: SubtestProgress.belum,
        ),
    ];
  }

  return DiagnosticData(
    profile: profile,
    plan: plan,
    rows: rows,
    unfinishedId: unfinished?.session.id,
    result: result,
  );
});
