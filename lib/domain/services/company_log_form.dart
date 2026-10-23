import '../models/notebook.dart';
import 'profile_validation.dart';

/// Isi formulir catatan psikotes (S13) sebelum disimpan. Murni, seperti
/// `CaptureDraft`.
class CompanyLogDraft {
  const CompanyLogDraft({
    this.perusahaan = '',
    this.tanggal = '',
    this.subtes = const [],
    this.tipeBaru = '',
    this.catatan = '',
  });

  static const int maxTagLength = 40;
  static const int maxTags = 12;

  final String perusahaan;

  /// Tanggal tes sebagai teks hh/bb/tttt (A53).
  final String tanggal;
  final List<String> subtes;

  /// Tag tipe baru, dipisah koma atau baris baru.
  final String tipeBaru;
  final String catatan;

  /// Tag tipe baru yang sudah dirapikan: tanpa spasi berlebih, tanpa kembar
  /// (huruf besar diabaikan), paling banyak [maxTags].
  List<String> get tags {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in tipeBaru.split(RegExp(r'[,\n]'))) {
      final tag = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (tag.isEmpty) continue;
      if (!seen.add(NoteSuggestions.normalize(tag))) continue;
      out.add(tag.length > maxTagLength ? tag.substring(0, maxTagLength) : tag);
      if (out.length == maxTags) break;
    }
    return out;
  }

  CompanyLogErrors validate() => CompanyLogErrors(
        perusahaan: perusahaan.trim().isEmpty
            ? 'Isi nama perusahaan agar catatan mudah dicari.'
            : null,
        tanggal: ProfileValidation.parseDate(tanggal.trim()) == null
            ? 'Tulis tanggal tes sebagai hh/bb/tttt, misalnya 22/10/2026.'
            : null,
      );

  CompanyTestLog? build({int? id}) {
    if (validate().any) return null;
    return CompanyTestLog(
      id: id,
      perusahaan: perusahaan.trim(),
      tanggal: ProfileValidation.parseDate(tanggal.trim())!,
      subtes: subtes,
      tipeBaru: tags,
      catatan: catatan.trim(),
    );
  }
}

class CompanyLogErrors {
  const CompanyLogErrors({this.perusahaan, this.tanggal});

  final String? perusahaan;
  final String? tanggal;

  bool get any => perusahaan != null || tanggal != null;
}

/// Satu saran latihan dari catatan tes: tipe baru yang belum punya soal
/// Capture.
class NoteSuggestion {
  const NoteSuggestion({required this.tipe, required this.logId});

  final String tipe;
  final int? logId;
}

abstract final class NoteSuggestions {
  static String normalize(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Tag tipe baru di [logs] yang belum punya soal Capture dengan kategori
  /// yang sama ([questions]). Satu saran per tipe, dari catatan terbaru.
  static List<NoteSuggestion> pending(
    List<CompanyTestLog> logs,
    List<CapturedQuestion> questions,
  ) {
    final covered = {for (final q in questions) normalize(q.kategori)};
    final seen = <String>{};
    final out = <NoteSuggestion>[];
    final newestFirst = [...logs]..sort((a, b) {
        final byDate = b.tanggal.compareTo(a.tanggal);
        return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
      });
    for (final log in newestFirst) {
      for (final tag in log.tipeBaru) {
        final key = normalize(tag);
        if (covered.contains(key) || !seen.add(key)) continue;
        out.add(NoteSuggestion(tipe: tag, logId: log.id));
      }
    }
    return out;
  }

  /// Apakah ada tag tipe baru di [logs], dengan atau tanpa soal Capture.
  static bool hasTags(List<CompanyTestLog> logs) =>
      logs.any((l) => l.tipeBaru.isNotEmpty);
}
