import 'codes.dart';

/// Kartu buku kesalahan (F07).
class MistakeCard {
  const MistakeCard({
    required this.id,
    required this.tipe,
    required this.kategori,
    this.seed,
    required this.sumber,
    this.refId,
    required this.jatuhTempo,
    required this.intervalHari,
    required this.streakBenar,
    required this.status,
    required this.dibuat,
  });

  final int id;
  final String tipe;
  final String kategori;

  /// Seed asal; ulangan memakai seed baru.
  final int? seed;
  final AnswerSource sumber;
  final int? refId;
  final DateTime jatuhTempo;
  final int intervalHari;

  /// 0 sampai 3.
  final int streakBenar;
  final CardStatus status;
  final DateTime dibuat;
}

/// Soal tangkapan pengguna (F13). Tetap lokal; foto tidak ikut backup.
class CapturedQuestion {
  const CapturedQuestion({
    this.id,
    required this.teks,
    required this.opsi,
    required this.kunci,
    this.pembahasan,
    required this.kategori,
    this.fotoPath,
    this.companyLogId,
    required this.dibuat,
  });

  final int? id;
  final String teks;

  /// 2 sampai 6 opsi.
  final List<String> opsi;

  /// Indeks opsi yang benar.
  final int kunci;
  final String? pembahasan;
  final String kategori;
  final String? fotoPath;
  final int? companyLogId;
  final DateTime dibuat;

  /// Pelanggaran aturan bentuk; kosong berarti sah.
  List<String> validate() => [
        if (teks.trim().isEmpty) 'teks kosong',
        if (opsi.length < 2 || opsi.length > 6) 'opsi harus 2 sampai 6',
        if (kunci < 0 || kunci >= opsi.length) 'kunci di luar rentang opsi',
      ];
}

class CompanyTestLog {
  const CompanyTestLog({
    this.id,
    required this.perusahaan,
    required this.tanggal,
    this.subtes = const [],
    this.tipeBaru = const [],
    this.catatan = '',
  });

  final int? id;
  final String perusahaan;
  final DateTime tanggal;

  /// Kategori yang keluar.
  final List<String> subtes;

  /// Tag tipe baru, mis. "lipat kertas".
  final List<String> tipeBaru;
  final String catatan;
}
