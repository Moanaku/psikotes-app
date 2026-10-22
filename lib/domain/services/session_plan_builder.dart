import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import '../models/session.dart';
import 'seed_allocator.dart';

/// Menyusun `SessionPlan` dari tipe soal dan blueprint profil. Fungsi murni:
/// seed diturunkan dari waktu yang dioper (lewat `Clock`), tanpa membaca jam.
///
/// Seed berasal dari detik pembuatan rencana. Pasangan (tipe, seed) yang
/// sudah muncul 30 hari terakhir dilewati lewat [avoid] (kunci dari
/// `SeedAllocator.key`); tanpa [avoid] dua rencana yang berselang kelipatan
/// 7919 detik bisa berbagi soal.
abstract final class SessionPlanBuilder {
  /// Jumlah soal sesi latihan satu tipe dari katalog (A56).
  static const int practiceCount = 10;

  /// Seed dasar dari waktu, 0 sampai 2^31 - 2.
  static int seedBase(DateTime now) =>
      (now.millisecondsSinceEpoch ~/ 1000) % SeedAllocator.modulus;

  /// Butir rencana untuk [type] dengan versi generator yang berlaku sekarang.
  static PlanItem item(
    QuestionType type,
    int seed,
    Difficulty difficulty, {
    String? subtes,
  }) =>
      PlanItem(
        type: type,
        seed: seed,
        difficulty: difficulty,
        genVersi: GeneratorRegistry.generator(type).version,
        subtes: subtes ?? type.category.code,
      );

  /// Tipe terdaftar di [available] untuk satu kategori, urut menurut katalog.
  static List<QuestionType> categoryTypes(
    String kategori,
    Set<QuestionType> available,
  ) =>
      [
        for (final t in available)
          if (t.category.code == kategori && GeneratorRegistry.has(t)) t,
      ]..sort((a, b) => a.index.compareTo(b.index));

  /// Latihan satu tipe tanpa timer (S05 ke S06). Tipe harus terdaftar di
  /// `GeneratorRegistry`.
  static SessionPlan practice(
    QuestionType type, {
    required DateTime now,
    int count = practiceCount,
    Difficulty difficulty = Difficulty.medium,
    Set<String> avoid = const {},
  }) {
    final seeds = SeedAllocator(seedBase(now), avoid: avoid);
    return SessionPlan(
      items: [
        for (var i = 0; i < count; i++)
          item(type, seeds.next(type), difficulty),
      ],
    );
  }

  /// Urutan tipe untuk campuran [count] soal menurut bobot kategori profil,
  /// dari tipe yang terdaftar saja. Kosong bila tidak ada kategori berbobot
  /// yang punya tipe terdaftar. Soal berselang-seling antar kategori; di dalam
  /// kategori berputar antar tipe.
  static List<QuestionType> mixedTypes(
    ProfileBlueprint blueprint, {
    required int count,
    required Set<QuestionType> available,
  }) {
    final categories = <String, List<QuestionType>>{};
    for (final s in blueprint.subtes) {
      if (!s.aktif) continue;
      final types = categoryTypes(s.kategori, available);
      if (types.isNotEmpty && (blueprint.bobot[s.kategori] ?? 0) > 0) {
        categories[s.kategori] = types;
      }
    }
    if (categories.isEmpty || count <= 0) return const [];

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

    final used = {for (final k in categories.keys) k: 0};
    final result = <QuestionType>[];
    while (result.length < count) {
      for (final k in categories.keys) {
        if (used[k]! >= quota[k]!) continue;
        final types = categories[k]!;
        result.add(types[used[k]! % types.length]);
        used[k] = used[k]! + 1;
        if (result.length == count) break;
      }
    }
    return result;
  }

  /// Campuran [count] soal medium menurut bobot kategori profil. Mengembalikan
  /// rencana kosong bila tidak ada kategori berbobot yang punya tipe
  /// terdaftar.
  static SessionPlan mixed(
    ProfileBlueprint blueprint, {
    required DateTime now,
    required int count,
    required Set<QuestionType> available,
    Set<String> avoid = const {},
  }) {
    final seeds = SeedAllocator(seedBase(now), avoid: avoid);
    return SessionPlan(
      items: [
        for (final t
            in mixedTypes(blueprint, count: count, available: available))
          item(t, seeds.next(t), Difficulty.medium),
      ],
    );
  }

  /// Simulasi penuh dari blueprint profil: tiap subtes aktif yang punya tipe
  /// terdaftar menjadi satu subtes bertimer. Subtes tanpa tipe terdaftar
  /// dilewati ([skipped] berisi kategorinya). Mengembalikan null bila tidak ada
  /// subtes yang bisa disusun.
  static ({SessionPlan plan, List<String> skipped})? simulation(
    ProfileBlueprint blueprint, {
    required DateTime now,
    required Set<QuestionType> available,
    Set<String> avoid = const {},
  }) {
    final seeds = SeedAllocator(seedBase(now), avoid: avoid);
    final items = <PlanItem>[];
    final subtests = <SubtestPlan>[];
    final skipped = <String>[];
    for (final s in blueprint.subtes) {
      if (!s.aktif) continue;
      final types = categoryTypes(s.kategori, available);
      if (types.isEmpty) {
        skipped.add(s.kategori);
        continue;
      }
      for (var i = 0; i < s.jumlah; i++) {
        final type = types[i % types.length];
        items.add(item(type, seeds.next(type), Difficulty.medium));
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
