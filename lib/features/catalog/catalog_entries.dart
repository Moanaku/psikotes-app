import 'package:question_engine/question_engine.dart';

import '../../domain/models/catalog.dart';
import '../../domain/services/verbal_bank.dart';

/// Satu baris katalog. [type] null untuk butir yang bukan tipe soal engine
/// (Pengetahuan role, S19).
class CatalogEntry {
  const CatalogEntry({required this.label, this.type, this.release});

  final String label;
  final QuestionType? type;

  /// Rilis tempat butir ini masuk bila [type] null.
  final Release? release;

  factory CatalogEntry.of(QuestionType type) =>
      CatalogEntry(label: questionTypeName(type), type: type);

  Release get releaseOf => type == null ? release! : questionTypeRelease(type!);
}

class CatalogGroup {
  const CatalogGroup(this.title, this.entries);

  final String title;
  final List<CatalogEntry> entries;
}

/// Kelompok katalog S05 berurutan (docs/05-spek-layar.md). Bank pribadi
/// ditangani layar karena isinya dari database.
final List<CatalogGroup> catalogGroups = [
  CatalogGroup('Numerik dan logika', [
    CatalogEntry.of(QuestionType.numSeq),
    CatalogEntry.of(QuestionType.numAri),
    CatalogEntry.of(QuestionType.numWord),
    CatalogEntry.of(QuestionType.logSyl),
  ]),
  CatalogGroup('Figural', [
    CatalogEntry.of(QuestionType.figMtx),
    CatalogEntry.of(QuestionType.figSeq),
    CatalogEntry.of(QuestionType.figMir),
    CatalogEntry.of(QuestionType.figOdd),
  ]),
  CatalogGroup('Verbal', [
    CatalogEntry.of(QuestionType.vrbSyn),
    CatalogEntry.of(QuestionType.vrbAna),
    CatalogEntry.of(QuestionType.vrbRc),
  ]),
  CatalogGroup('Ketelitian dan kepribadian', [
    CatalogEntry.of(QuestionType.krp),
    CatalogEntry.of(QuestionType.perPapi),
    CatalogEntry.of(QuestionType.perDisc),
  ]),
  CatalogGroup('Modul IT', [
    CatalogEntry.of(QuestionType.itPse),
    CatalogEntry.of(QuestionType.itFlw),
    CatalogEntry.of(QuestionType.itXls),
  ]),
  const CatalogGroup('Pengetahuan role', [
    CatalogEntry(label: 'QA Engineer', release: Release.v11),
    CatalogEntry(label: 'Mobile Dev', release: Release.v11),
    CatalogEntry(label: 'IT BA', release: Release.v11),
    CatalogEntry(label: 'Umum', release: Release.v11),
  ]),
];

/// Mengapa sebuah butir tidak bisa dibuka; null bila bisa.
class CatalogAvailability {
  const CatalogAvailability._(this.tag, this.reason);

  /// Teks tag di baris (mis. "v1.1").
  final String tag;

  /// Penjelasan di bawah judul baris.
  final String reason;

  static const CatalogAvailability v11 = CatalogAvailability._(
    'v1.1',
    'Tersedia di v1.1',
  );

  static const CatalogAvailability preparing = CatalogAvailability._(
    'Segera',
    'Bank soal sedang disiapkan',
  );

  /// Bank verbal ada tetapi gagal dibaca atau skemanya salah.
  static const CatalogAvailability bankError = CatalogAvailability._(
    'Galat',
    'Bank soal tidak terbaca. Buka ulang app.',
  );

  /// Butir bisa dibuka bila tipenya ada di [available] (registry generator
  /// dan bank verbal). [bankFailed] menandai bank verbal yang gagal dimuat.
  static CatalogAvailability? of(
    CatalogEntry entry,
    Set<QuestionType> available, {
    bool bankFailed = false,
  }) {
    final type = entry.type;
    if (type != null && available.contains(type)) return null;
    if (type != null && bankFailed && VerbalBank.bankTypes.contains(type)) {
      return bankError;
    }
    return entry.releaseOf == Release.v11 ? v11 : preparing;
  }
}
