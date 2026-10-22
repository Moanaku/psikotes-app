import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import '../models/session.dart';

/// Menyusun `SessionPlan` dari tipe soal dan blueprint profil. Fungsi murni:
/// seed diturunkan dari waktu yang dioper (lewat `Clock`), tanpa membaca jam.
///
/// Tidak menghindari (tipe, seed) yang sudah muncul 30 hari terakhir; itu
/// tugas `DailyPlanner` (T13). Seed di sini berasal dari detik pembuatan
/// rencana, jadi dua rencana berbeda hampir tidak pernah berbagi seed.
abstract final class SessionPlanBuilder {
  /// Jumlah soal sesi latihan satu tipe dari katalog (A56).
  static const int practiceCount = 10;

  /// Seed dasar dari waktu, 0 sampai 2^31 - 2.
  static int seedBase(DateTime now) =>
      (now.millisecondsSinceEpoch ~/ 1000) % _seedModulus;

  static const int _seedModulus = 0x7FFFFFFF;

  static int _seed(int base, int index, QuestionType type) =>
      (base + index * 7919 + type.index * 104729) % _seedModulus;

  static PlanItem _item(
    QuestionType type,
    int base,
    int index,
    Difficulty difficulty,
  ) =>
      PlanItem(
        type: type,
        seed: _seed(base, index, type),
        difficulty: difficulty,
        genVersi: GeneratorRegistry.generator(type).version,
        subtes: type.category.code,
      );

  /// Latihan satu tipe tanpa timer (S05 ke S06). Tipe harus terdaftar di
  /// `GeneratorRegistry`.
  static SessionPlan practice(
    QuestionType type, {
    required DateTime now,
    int count = practiceCount,
    Difficulty difficulty = Difficulty.medium,
  }) {
    final base = seedBase(now);
    return SessionPlan(
      items: [for (var i = 0; i < count; i++) _item(type, base, i, difficulty)],
    );
  }

  /// Campuran [count] soal menurut bobot kategori profil, dari tipe yang
  /// terdaftar saja. Mengembalikan rencana kosong bila tidak ada kategori
  /// berbobot yang punya tipe terdaftar. Soal berselang-seling antar kategori.
  static SessionPlan mixed(
    ProfileBlueprint blueprint, {
    required DateTime now,
    required int count,
    required Set<QuestionType> available,
  }) {
    final base = seedBase(now);
    final categories = <String, List<QuestionType>>{};
    for (final s in blueprint.subtes) {
      if (!s.aktif) continue;
      final types = [
        for (final t in available)
          if (t.category.code == s.kategori && GeneratorRegistry.has(t)) t,
      ]..sort((a, b) => a.index.compareTo(b.index));
      if (types.isNotEmpty && (blueprint.bobot[s.kategori] ?? 0) > 0) {
        categories[s.kategori] = types;
      }
    }
    if (categories.isEmpty || count <= 0) return const SessionPlan(items: []);

    // Jatah per kategori: terbesar-sisa dari bobot yang dinormalkan.
    final total = categories.keys
        .fold<double>(0, (a, k) => a + (blueprint.bobot[k] ?? 0));
    final quota = <String, int>{};
    final remainder = <String, double>{};
    var assigned = 0;
    for (final k in categories.keys) {
      final exact = count * (blueprint.bobot[k] ?? 0) / total;
      quota[k] = exact.floor();
      remainder[k] = exact - exact.floor();
      assigned += quota[k]!;
    }
    final byRemainder = categories.keys.toList()
      ..sort((a, b) => remainder[b]!.compareTo(remainder[a]!));
    for (var i = 0; assigned < count; i++, assigned++) {
      quota[byRemainder[i % byRemainder.length]] =
          quota[byRemainder[i % byRemainder.length]]! + 1;
    }

    // Selang-seling kategori; di dalam kategori berputar antar tipe.
    final used = {for (final k in categories.keys) k: 0};
    final items = <PlanItem>[];
    var index = 0;
    while (items.length < count) {
      for (final k in categories.keys) {
        if (used[k]! >= quota[k]!) continue;
        final types = categories[k]!;
        items.add(_item(
            types[used[k]! % types.length], base, index++, Difficulty.medium));
        used[k] = used[k]! + 1;
        if (items.length == count) break;
      }
    }
    return SessionPlan(items: items);
  }

  /// Simulasi penuh dari blueprint profil: tiap subtes aktif yang punya tipe
  /// terdaftar menjadi satu subtes bertimer. Subtes tanpa tipe terdaftar
  /// dilewati ([skipped] berisi kategorinya). Mengembalikan null bila tidak ada
  /// subtes yang bisa disusun.
  static ({SessionPlan plan, List<String> skipped})? simulation(
    ProfileBlueprint blueprint, {
    required DateTime now,
    required Set<QuestionType> available,
  }) {
    final base = seedBase(now);
    final items = <PlanItem>[];
    final subtests = <SubtestPlan>[];
    final skipped = <String>[];
    for (final s in blueprint.subtes) {
      if (!s.aktif) continue;
      final types = [
        for (final t in available)
          if (t.category.code == s.kategori && GeneratorRegistry.has(t)) t,
      ]..sort((a, b) => a.index.compareTo(b.index));
      if (types.isEmpty) {
        skipped.add(s.kategori);
        continue;
      }
      for (var i = 0; i < s.jumlah; i++) {
        items.add(_item(
            types[i % types.length], base, items.length, Difficulty.medium));
      }
      subtests.add(
        SubtestPlan(kategori: s.kategori, jumlah: s.jumlah, menit: s.menit),
      );
    }
    if (subtests.isEmpty) return null;
    return (
      plan: SessionPlan(items: items, subtes: subtests),
      skipped: skipped,
    );
  }
}
