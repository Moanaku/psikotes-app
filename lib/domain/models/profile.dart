import 'codes.dart';

/// Satu subtes di blueprint: kategori, jumlah soal, dan menit.
class SubtestSpec {
  const SubtestSpec({
    required this.kategori,
    required this.aktif,
    required this.jumlah,
    required this.menit,
  });

  final String kategori;
  final bool aktif;
  final int jumlah;
  final int menit;

  Map<String, Object?> toJson() => {
        'kategori': kategori,
        'aktif': aktif,
        'jumlah': jumlah,
        'menit': menit,
      };

  factory SubtestSpec.fromJson(Map<String, Object?> m) => SubtestSpec(
        kategori: m['kategori']! as String,
        aktif: m['aktif']! as bool,
        jumlah: m['jumlah']! as int,
        menit: m['menit']! as int,
      );
}

/// Isi `blueprint_json`: subtes dan bobot kategori.
class ProfileBlueprint {
  const ProfileBlueprint({this.subtes = const [], this.bobot = const {}});

  final List<SubtestSpec> subtes;
  final Map<String, double> bobot;

  Map<String, Object?> toJson() => {
        'subtes': [for (final s in subtes) s.toJson()],
        'bobot': bobot,
      };

  factory ProfileBlueprint.fromJson(Map<String, Object?> m) {
    final subtes = <SubtestSpec>[
      for (final s in (m['subtes'] as List? ?? const []))
        SubtestSpec.fromJson((s as Map).cast<String, Object?>()),
    ];
    final bobot = <String, double>{
      for (final e in ((m['bobot'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toDouble(),
    };
    for (final s in subtes) {
      if (!kCategories.contains(s.kategori)) {
        throw FormatException('kategori tidak dikenal: ${s.kategori}');
      }
    }
    return ProfileBlueprint(subtes: subtes, bobot: bobot);
  }
}

class TestProfile {
  const TestProfile({
    this.id,
    required this.nama,
    required this.role,
    required this.formatTes,
    this.tanggalTes,
    this.aktif = false,
    this.blueprint = const ProfileBlueprint(),
    this.cvTeks,
    required this.dibuat,
  });

  /// Null untuk profil yang belum disimpan.
  final int? id;
  final String nama;
  final ProfileRole role;
  final TestFormat formatTes;
  final DateTime? tanggalTes;
  final bool aktif;
  final ProfileBlueprint blueprint;

  /// Teks CV yang sudah disanitasi; tidak pernah diekspor (backup).
  final String? cvTeks;
  final DateTime dibuat;

  TestProfile copyWith({int? id, bool? aktif}) => TestProfile(
        id: id ?? this.id,
        nama: nama,
        role: role,
        formatTes: formatTes,
        tanggalTes: tanggalTes,
        aktif: aktif ?? this.aktif,
        blueprint: blueprint,
        cvTeks: cvTeks,
        dibuat: dibuat,
      );
}
