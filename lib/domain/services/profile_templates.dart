import '../models/codes.dart';
import '../models/profile.dart';

/// Template profil (docs/06-bank-konten.md, "Blueprint tes per profil"; F01).
/// Fungsi murni. Angka subtes adalah asumsi awal sampai daftar tes nyata (Q1)
/// tersedia; lihat A4 dan A48 di docs/11-asumsi-dan-pertanyaan.md.
abstract final class ProfileTemplates {
  /// Kategori yang muncul di daftar subtes S02, berurutan. Modul IT dan
  /// Pengetahuan role punya layar sendiri dan tidak ada di sini.
  static const List<String> subtestCategories = [
    'verbal',
    'numerik',
    'logika',
    'figural',
    'kraepelin',
    'kepribadian',
  ];

  /// Role yang dipilih di S01, berurutan.
  static const List<ProfileRole> roles = [
    ProfileRole.qa,
    ProfileRole.mobile,
    ProfileRole.ba,
    ProfileRole.umum,
    ProfileRole.lainnya,
  ];

  static const List<TestFormat> formats = [
    TestFormat.ccat,
    TestFormat.bank,
    TestFormat.kustom,
  ];

  /// Kategori yang bobotnya naik 50% untuk role (A2). Umum dan Lainnya tidak
  /// menaikkan apa pun.
  static const Map<ProfileRole, Set<String>> roleBoost = {
    ProfileRole.qa: {'kraepelin', 'logika'},
    ProfileRole.mobile: {'figural', 'it'},
    ProfileRole.ba: {'verbal', 'numerik'},
  };

  static const double boostFactor = 1.5;

  /// Bobot dasar format. Kustom kosong: semua subtes aktif berbobot sama.
  static const Map<TestFormat, Map<String, double>> _baseWeights = {
    TestFormat.ccat: {
      'verbal': 0.30,
      'numerik': 0.30,
      'logika': 0.20,
      'figural': 0.20,
    },
    TestFormat.bank: {
      'verbal': 0.25,
      'numerik': 0.25,
      'figural': 0.20,
      'kraepelin': 0.15,
      'kepribadian': 0.15,
    },
    TestFormat.kustom: {},
  };

  /// Isian awal saat subtes dinyalakan tanpa angka (jumlah, menit).
  static const Map<String, (int, int)> defaultSizes = {
    'verbal': (20, 8),
    'numerik': (20, 8),
    'logika': (20, 8),
    'figural': (20, 8),
    'kraepelin': (10, 10),
    'kepribadian': (30, 10),
  };

  /// Subtes awal untuk [format]: semua kategori S02 dengan penanda aktif.
  static List<SubtestSpec> subtests(TestFormat format) {
    const ccat = {
      'verbal': (15, 4),
      'numerik': (15, 4),
      'logika': (10, 4),
      'figural': (10, 3),
    };
    const bank = {
      'verbal': (30, 25),
      'numerik': (30, 25),
      'figural': (24, 20),
      'kraepelin': (15, 15),
      'kepribadian': (36, 15),
    };
    const kustom = {
      'verbal': (20, 8),
      'numerik': (20, 8),
      'logika': (20, 8),
      'figural': (20, 8),
    };
    final active = switch (format) {
      TestFormat.ccat => ccat,
      TestFormat.bank => bank,
      TestFormat.kustom => kustom,
    };
    return [
      for (final k in subtestCategories)
        SubtestSpec(
          kategori: k,
          aktif: active.containsKey(k),
          jumlah: (active[k] ?? defaultSizes[k]!).$1,
          menit: (active[k] ?? defaultSizes[k]!).$2,
        ),
    ];
  }

  /// Bobot kategori untuk subtes aktif: bobot dasar format, dinaikkan 50% untuk
  /// kategori role, lalu dinormalkan ke 1,0 (dibulatkan 4 desimal; selisih
  /// pembulatan masuk ke bobot terbesar). Kategori aktif yang tidak ada di
  /// bobot dasar memakai bobot dasar terkecil. Tanpa subtes aktif: kosong.
  static Map<String, double> weights(
    ProfileRole role,
    TestFormat format,
    List<SubtestSpec> subtests,
  ) {
    final active = [
      for (final s in subtests)
        if (s.aktif) s.kategori,
    ];
    if (active.isEmpty) return const {};
    final base = _baseWeights[format]!;
    final floor =
        base.isEmpty ? 1.0 : base.values.reduce((a, b) => a < b ? a : b);
    final boost = roleBoost[role] ?? const <String>{};
    final raw = <String, double>{
      for (final k in active)
        k: (base[k] ?? floor) * (boost.contains(k) ? boostFactor : 1.0),
    };
    final total = raw.values.fold<double>(0, (a, b) => a + b);
    final out = <String, double>{
      for (final e in raw.entries)
        e.key: (e.value / total * 10000).round() / 10000,
    };
    var sum = out.values.fold<double>(0, (a, b) => a + b);
    if ((sum - 1).abs() > 1e-9) {
      final top = out.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      out[top] = ((out[top]! + (1 - sum)) * 10000).round() / 10000;
      sum = out.values.fold<double>(0, (a, b) => a + b);
    }
    return out;
  }

  /// Blueprint lengkap untuk [role] dan [format]; [subtests] mengganti isian
  /// awal bila pengguna sudah mengubahnya. Subtes nonaktif tetap disimpan
  /// (dengan angkanya) agar menyalakannya lagi tidak kehilangan isian.
  static ProfileBlueprint blueprint(
    ProfileRole role,
    TestFormat format, {
    List<SubtestSpec>? subtests,
  }) {
    final list = subtests ?? ProfileTemplates.subtests(format);
    return ProfileBlueprint(
      subtes: list,
      bobot: weights(role, format, list),
    );
  }

  static String roleName(ProfileRole role) => switch (role) {
        ProfileRole.qa => 'QA Engineer',
        ProfileRole.mobile => 'Mobile / App Developer',
        ProfileRole.ba => 'IT Business Analyst',
        ProfileRole.umum => 'Umum, tanpa role',
        ProfileRole.lainnya => 'Lainnya',
      };

  /// Singkatan untuk nama profil otomatis.
  static String roleShort(ProfileRole role) => switch (role) {
        ProfileRole.qa => 'QA',
        ProfileRole.mobile => 'Mobile Dev',
        ProfileRole.ba => 'IT BA',
        ProfileRole.umum => 'Umum',
        ProfileRole.lainnya => 'Lainnya',
      };

  static String roleHint(ProfileRole role) => switch (role) {
        ProfileRole.qa => 'Penekanan: ketelitian, logika deduktif, '
            'Kraepelin/Pauli',
        ProfileRole.mobile => 'Penekanan: figural induktif, pseudocode, '
            'numerik',
        ProfileRole.ba => 'Penekanan: verbal, bacaan, tabel data, silogisme',
        ProfileRole.umum => 'Semua kategori dengan bobot rata. Cocok kalau '
            'role belum jelas.',
        ProfileRole.lainnya => 'Format tes menentukan bobot kategori',
      };

  static String formatName(TestFormat format) => switch (format) {
        TestFormat.ccat => 'CCAT-style',
        TestFormat.bank => 'Psikotes Bank-style',
        TestFormat.kustom => 'Kustom',
      };

  static String categoryName(String kategori) => switch (kategori) {
        'verbal' => 'Verbal',
        'numerik' => 'Numerik',
        'logika' => 'Logika',
        'figural' => 'Figural',
        'kraepelin' => 'Kraepelin / Pauli',
        'kepribadian' => 'Kepribadian',
        'it' => 'Modul IT',
        'pengetahuan' => 'Pengetahuan role',
        _ => kategori,
      };

  /// Satuan jumlah per subtes: "soal", "kolom" (Kraepelin), "item" (kepribadian).
  static String countUnit(String kategori) => switch (kategori) {
        'kraepelin' => 'kolom',
        'kepribadian' => 'item',
        _ => 'soal',
      };

  /// Nama profil otomatis, mis. "QA, CCAT-style".
  static String autoName(ProfileRole role, TestFormat format) =>
      '${roleShort(role)}, ${formatName(format)}';
}
