import '../models/notebook.dart';

/// Isi formulir Capture (S12) sebelum disimpan. Murni: validasi dan perakitan
/// `CapturedQuestion` tanpa I/O, supaya bisa diuji tanpa layar.
///
/// Opsi diisi per slot (A sampai F). Slot kosong dibuang saat disimpan dan
/// huruf opsi dirapatkan, jadi kunci dipetakan ulang ke indeks baru.
class CaptureDraft {
  const CaptureDraft({
    this.teks = '',
    this.fotoPath,
    this.opsi = const ['', '', '', ''],
    this.kunciSlot,
    this.kategori = '',
    this.pembahasan = '',
    this.companyLogId,
  });

  static const int minOptions = 2;
  static const int maxOptions = 6;

  /// Slot opsi yang tampil saat formulir baru dibuka (A sampai D).
  static const int initialSlots = 4;

  final String teks;
  final String? fotoPath;

  /// Satu string per slot, termasuk yang kosong.
  final List<String> opsi;

  /// Indeks slot yang ditandai sebagai kunci, atau null bila belum dipilih.
  final int? kunciSlot;

  /// Kategori terpilih, atau tipe baru yang diketik pengguna.
  final String kategori;
  final String pembahasan;
  final int? companyLogId;

  /// Draf dari soal tersimpan (mode ubah).
  factory CaptureDraft.from(CapturedQuestion q) => CaptureDraft(
        teks: q.teks,
        fotoPath: q.fotoPath,
        opsi: q.opsi.length >= initialSlots
            ? q.opsi
            : [
                ...q.opsi,
                for (var i = q.opsi.length; i < initialSlots; i++) ''
              ],
        kunciSlot: q.kunci,
        kategori: q.kategori,
        pembahasan: q.pembahasan ?? '',
        companyLogId: q.companyLogId,
      );

  CaptureDraft copyWith({
    String? teks,
    String? fotoPath,
    bool clearFoto = false,
    List<String>? opsi,
    int? kunciSlot,
    bool clearKunci = false,
    String? kategori,
    String? pembahasan,
    int? companyLogId,
    bool clearCompanyLog = false,
  }) =>
      CaptureDraft(
        teks: teks ?? this.teks,
        fotoPath: clearFoto ? null : fotoPath ?? this.fotoPath,
        opsi: opsi ?? this.opsi,
        kunciSlot: clearKunci ? null : kunciSlot ?? this.kunciSlot,
        kategori: kategori ?? this.kategori,
        pembahasan: pembahasan ?? this.pembahasan,
        companyLogId:
            clearCompanyLog ? null : companyLogId ?? this.companyLogId,
      );

  bool get hasPhoto => fotoPath != null && fotoPath!.isNotEmpty;

  List<int> get _filled => [
        for (var i = 0; i < opsi.length; i++)
          if (opsi[i].trim().isNotEmpty) i,
      ];

  CaptureErrors validate() {
    String? soal;
    String? opsiError;
    String? kunci;
    String? kategoriError;

    if (teks.trim().isEmpty && !hasPhoto) {
      soal = 'Isi teks soal atau tambahkan foto soal.';
    }
    final filled = _filled;
    if (filled.length < minOptions) {
      opsiError = 'Isi minimal 2 opsi jawaban.';
    }
    final slot = kunciSlot;
    if (slot == null) {
      kunci = 'Kunci jawaban belum dipilih. Pilih lingkaran di kiri opsi '
          'yang benar.';
    } else if (!filled.contains(slot)) {
      kunci = 'Kunci menunjuk opsi yang masih kosong. Isi opsinya atau pilih '
          'opsi lain.';
    }
    if (kategori.trim().isEmpty) {
      kategoriError = 'Pilih kategori soal, atau isi nama tipe baru.';
    }
    return CaptureErrors(
      soal: soal,
      opsi: opsiError,
      kunci: kunci,
      kategori: kategoriError,
    );
  }

  /// Soal siap simpan, atau null bila formulir belum sah. [id] dan [dibuat]
  /// dipertahankan saat mengubah soal yang sudah ada.
  CapturedQuestion? build({required DateTime now, int? id, DateTime? dibuat}) {
    if (validate().any) return null;
    final filled = _filled;
    final note = pembahasan.trim();
    return CapturedQuestion(
      id: id,
      teks: teks.trim(),
      opsi: [for (final i in filled) opsi[i].trim()],
      kunci: filled.indexOf(kunciSlot!),
      pembahasan: note.isEmpty ? null : note,
      kategori: kategori.trim(),
      fotoPath: hasPhoto ? fotoPath : null,
      companyLogId: companyLogId,
      dibuat: dibuat ?? now,
    );
  }
}

/// Pesan galat per bagian formulir; null berarti bagian itu sah.
class CaptureErrors {
  const CaptureErrors({this.soal, this.opsi, this.kunci, this.kategori});

  final String? soal;
  final String? opsi;
  final String? kunci;
  final String? kategori;

  bool get any =>
      soal != null || opsi != null || kunci != null || kategori != null;
}
