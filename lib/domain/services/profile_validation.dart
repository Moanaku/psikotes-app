import '../models/codes.dart';
import '../models/profile.dart';
import 'profile_templates.dart';

/// Satu baris subtes di formulir S02, apa adanya dari isian pengguna.
class SubtestInput {
  const SubtestInput({
    required this.kategori,
    required this.aktif,
    required this.jumlah,
    required this.menit,
  });

  final String kategori;
  final bool aktif;
  final String jumlah;
  final String menit;

  SubtestInput copyWith({bool? aktif, String? jumlah, String? menit}) =>
      SubtestInput(
        kategori: kategori,
        aktif: aktif ?? this.aktif,
        jumlah: jumlah ?? this.jumlah,
        menit: menit ?? this.menit,
      );

  factory SubtestInput.fromSpec(SubtestSpec s) => SubtestInput(
        kategori: s.kategori,
        aktif: s.aktif,
        jumlah: '${s.jumlah}',
        menit: '${s.menit}',
      );
}

enum NumberError {
  /// Kosong atau bukan bilangan bulat.
  invalid,

  /// Di luar rentang yang diizinkan.
  outOfRange,
}

enum DateError {
  /// Bukan tanggal yang ada di kalender, atau bukan format hh/bb/tttt.
  invalid,

  /// Sebelum hari ini.
  past,
}

/// Hasil validasi S02. Kosong berarti sah.
class ProfileErrors {
  const ProfileErrors({
    this.noSubtest = false,
    this.jumlah = const {},
    this.menit = const {},
    this.tanggal,
  });

  /// Tidak ada subtes aktif.
  final bool noSubtest;
  final Map<String, NumberError> jumlah;
  final Map<String, NumberError> menit;
  final DateError? tanggal;

  bool get isValid =>
      !noSubtest && jumlah.isEmpty && menit.isEmpty && tanggal == null;
}

/// Aturan S02 (docs/05-spek-layar.md): minimal satu subtes aktif, jumlah soal
/// 1 sampai 200, menit 1 sampai 180, tanggal tes bukan di masa lalu. Fungsi
/// murni; "hari ini" dioper dari luar (lewat `Clock`).
abstract final class ProfileValidation {
  static const int minCount = 1;
  static const int maxCount = 200;
  static const int minMinutes = 1;
  static const int maxMinutes = 180;

  static ProfileErrors validate({
    required List<SubtestInput> subtests,
    required String tanggal,
    required DateTime today,
  }) {
    final active = subtests.where((s) => s.aktif).toList();
    final jumlah = <String, NumberError>{};
    final menit = <String, NumberError>{};
    for (final s in active) {
      final j = _checkInt(s.jumlah, minCount, maxCount);
      if (j != null) jumlah[s.kategori] = j;
      final m = _checkInt(s.menit, minMinutes, maxMinutes);
      if (m != null) menit[s.kategori] = m;
    }
    DateError? dateError;
    if (tanggal.trim().isNotEmpty) {
      final d = parseDate(tanggal);
      if (d == null) {
        dateError = DateError.invalid;
      } else if (d.isBefore(dateOnly(today))) {
        dateError = DateError.past;
      }
    }
    return ProfileErrors(
      noSubtest: active.isEmpty,
      jumlah: jumlah,
      menit: menit,
      tanggal: dateError,
    );
  }

  static NumberError? _checkInt(String text, int min, int max) {
    final v = int.tryParse(text.trim());
    if (v == null) return NumberError.invalid;
    if (v < min || v > max) return NumberError.outOfRange;
    return null;
  }

  /// "hh/bb/tttt" menjadi tanggal UTC tengah malam; null bila bukan tanggal
  /// kalender yang ada (31/02 ditolak).
  static DateTime? parseDate(String text) {
    final m = RegExp(r'^(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{4})$')
        .firstMatch(text.trim());
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    final d = DateTime.utc(year, month, day);
    if (d.year != year || d.month != month || d.day != day) return null;
    return d;
  }

  static String formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Tanggal kalender (tanpa jam) dari [t], dalam zona waktu lokal [t].
  static DateTime dateOnly(DateTime t) => DateTime.utc(t.year, t.month, t.day);

  /// Susunan akhir blueprint dari isian yang sudah sah. Isian subtes nonaktif
  /// yang tidak terbaca diganti angka awalnya.
  static ProfileBlueprint toBlueprint(
    ProfileRole role,
    TestFormat format,
    List<SubtestInput> subtests,
  ) {
    final specs = [
      for (final s in subtests)
        SubtestSpec(
          kategori: s.kategori,
          aktif: s.aktif,
          jumlah: int.tryParse(s.jumlah.trim()) ??
              ProfileTemplates.defaultSizes[s.kategori]!.$1,
          menit: int.tryParse(s.menit.trim()) ??
              ProfileTemplates.defaultSizes[s.kategori]!.$2,
        ),
    ];
    return ProfileTemplates.blueprint(role, format, subtests: specs);
  }
}
