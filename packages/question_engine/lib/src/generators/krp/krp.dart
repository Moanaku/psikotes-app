/// Kraepelin/Pauli (KRP), docs/06-bank-konten.md "Spesifikasi ringkas tipe
/// lain" dan F13.
///
/// Lembar berisi beberapa kolom angka 0 sampai 9. Tugasnya menjumlahkan dua
/// angka berurutan dari atas ke bawah dan menulis angka terakhir hasilnya
/// (7 + 5 = 12, ditulis 2). Tiap kolom punya waktu sendiri; saat waktu habis
/// pindah ke kolom berikutnya walau belum selesai. Bukan soal pilihan ganda,
/// jadi tidak masuk `GeneratorRegistry`.
///
/// Skor: kecepatan (rata-rata isian per kolom), ketelitian (persen isian yang
/// benar), dan konsistensi (selisih isian kolom tersibuk dan tersepi, serta
/// simpangan rata-rata dari rata-rata). Semua bilangan bulat atau [Fraction],
/// jadi hasilnya sama di VM dan web.
library;

import '../../fraction.dart';
import '../../rng.dart';

/// Pengaturan satu tes.
final class KrpConfig {
  const KrpConfig({
    required this.columns,
    required this.secondsPerColumn,
    required this.rows,
  });

  /// Pengaturan dari subtes profil: [columns] kolom dalam [minutes] menit.
  /// Waktu per kolom dibulatkan ke bawah lalu lewat [KrpConfig.timed].
  factory KrpConfig.fromSubtest({required int columns, required int minutes}) {
    final c = columns.clamp(minColumns, maxColumns);
    return KrpConfig.timed(columns: c, secondsPerColumn: minutes * 60 ~/ c);
  }

  /// [columns] kolom dengan [secondsPerColumn] detik per kolom, keduanya
  /// dijepit ke batas. Baris dibuat cukup banyak supaya kolom tidak habis
  /// sebelum waktunya (paling cepat sekitar dua isian per detik), paling
  /// banyak [maxRows].
  factory KrpConfig.timed({
    required int columns,
    required int secondsPerColumn,
  }) {
    final seconds = secondsPerColumn.clamp(minSeconds, maxSeconds);
    return KrpConfig(
      columns: columns.clamp(minColumns, maxColumns),
      secondsPerColumn: seconds,
      rows: (seconds * 2 + 1).clamp(minRows, maxRows),
    );
  }

  /// Latihan dari katalog tanpa subtes profil: 10 kolom, 30 detik per kolom.
  static const KrpConfig practice = KrpConfig(
    columns: 10,
    secondsPerColumn: 30,
    rows: 61,
  );

  static const int minColumns = 2;
  static const int maxColumns = 60;
  static const int minSeconds = 15;
  static const int maxSeconds = 600;
  static const int minRows = 21;
  static const int maxRows = 121;

  final int columns;
  final int secondsPerColumn;

  /// Angka per kolom; pasangan per kolom = rows - 1.
  final int rows;

  bool get isValid =>
      columns >= minColumns &&
      columns <= maxColumns &&
      secondsPerColumn >= minSeconds &&
      secondsPerColumn <= maxSeconds &&
      rows >= minRows &&
      rows <= maxRows;
}

final class KrpSheet {
  KrpSheet._(this.seed, this.config, List<List<int>> digits)
      : digits = List.unmodifiable(
            [for (final c in digits) List<int>.unmodifiable(c)]);

  /// Lembar dari [seed] (0 sampai 2^32 - 1). Seed sama, lembar sama.
  factory KrpSheet.generate(int seed, KrpConfig config) {
    if (!config.isValid) throw ArgumentError.value(config, 'config');
    final rng = Rng(seed);
    return KrpSheet._(seed, config, [
      for (var c = 0; c < config.columns; c++)
        [for (var r = 0; r < config.rows; r++) rng.nextInt(10)],
    ]);
  }

  final int seed;
  final KrpConfig config;

  /// `digits[kolom][baris]`, 0 sampai 9.
  final List<List<int>> digits;

  int get pairsPerColumn => config.rows - 1;

  /// Kunci pasangan ke-[index] di [column]: angka terakhir dari jumlah angka
  /// baris [index] dan [index] + 1.
  int answer(int column, int index) =>
      (digits[column][index] + digits[column][index + 1]) % 10;
}

/// Hasil satu kolom.
final class KrpColumnScore {
  const KrpColumnScore(this.filled, this.correct);

  /// Pasangan yang diisi (berurutan dari atas).
  final int filled;
  final int correct;

  int get wrong => filled - correct;
}

final class KrpScore {
  KrpScore._(this.columns);

  /// Skor dari [answers]: `answers[kolom]` berisi angka yang diketik,
  /// berurutan dari pasangan pertama. Isian lebih dari jumlah pasangan
  /// diabaikan; kolom yang tidak ada di [answers] dihitung kosong.
  factory KrpScore.of(KrpSheet sheet, List<List<int>> answers) {
    final cols = <KrpColumnScore>[];
    for (var c = 0; c < sheet.config.columns; c++) {
      final typed = c < answers.length ? answers[c] : const <int>[];
      final n = typed.length < sheet.pairsPerColumn
          ? typed.length
          : sheet.pairsPerColumn;
      var correct = 0;
      for (var i = 0; i < n; i++) {
        if (typed[i] == sheet.answer(c, i)) correct++;
      }
      cols.add(KrpColumnScore(n, correct));
    }
    return KrpScore._(List.unmodifiable(cols));
  }

  final List<KrpColumnScore> columns;

  int get filled => columns.fold(0, (a, c) => a + c.filled);
  int get correct => columns.fold(0, (a, c) => a + c.correct);
  int get wrong => filled - correct;

  /// Rata-rata isian per kolom (kecepatan).
  Fraction get speed => Fraction(filled, columns.length);

  /// Persen isian yang benar, dibulatkan setengah ke atas; 0 bila kosong.
  int get accuracyPercent =>
      filled == 0 ? 0 : Fraction(correct * 100, filled).roundHalfUp();

  int get maxFilled => columns.fold(0, (a, c) => c.filled > a ? c.filled : a);

  int get minFilled =>
      columns.fold(maxFilled, (a, c) => c.filled < a ? c.filled : a);

  /// Selisih isian kolom terbanyak dan tersedikit; makin kecil makin stabil.
  int get range => maxFilled - minFilled;

  /// Simpangan rata-rata isian tiap kolom dari [speed].
  Fraction get meanDeviation {
    var total = Fraction.zero;
    for (final c in columns) {
      final d = Fraction(c.filled) - speed;
      total = total + (d.isNegative ? -d : d);
    }
    return total / Fraction(columns.length);
  }
}
