/// Bank pengetahuan role (F17): butir, role, level, dan kemajuan.
library;

enum KnowledgeRole {
  qa('qa', 'QA', 'QA'),
  mobile('mobile', 'Mobile Dev', 'MOB'),
  ba('ba', 'IT BA', 'BA'),
  umum('umum', 'Umum', 'UM');

  const KnowledgeRole(this.code, this.label, this.idCode);

  /// Nilai `role` di `knowledge_bank.json`.
  final String code;
  final String label;

  /// Bagian role di id butir, mis. `QA` pada `KB-QA-D-001`.
  final String idCode;

  static KnowledgeRole? fromCode(String code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }

  static KnowledgeRole? fromIdCode(String code) {
    for (final r in values) {
      if (r.idCode == code) return r;
    }
    return null;
  }
}

enum KnowledgeLevel {
  dasar('dasar', 'Dasar', 'D'),
  menengah('menengah', 'Menengah', 'M'),
  lanjut('lanjut', 'Lanjut', 'L');

  const KnowledgeLevel(this.code, this.label, this.idCode);

  final String code;
  final String label;
  final String idCode;

  static KnowledgeLevel? fromCode(String code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  static KnowledgeLevel? fromIdCode(String code) {
    for (final l in values) {
      if (l.idCode == code) return l;
    }
    return null;
  }
}

class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.role,
    required this.level,
    required this.topik,
    required this.pertanyaan,
    required this.jawabanModel,
    required this.poinKunci,
    this.sumber,
    required this.needsVerification,
  });

  /// `KB-QA-D-001`: role, level, lalu nomor.
  final String id;
  final KnowledgeRole role;
  final KnowledgeLevel level;

  /// Slug topik, mis. `siklus-bug`.
  final String topik;
  final String pertanyaan;
  final String jawabanModel;
  final List<String> poinKunci;

  /// Rujukan butir; null bila tidak ada, dan butir itu `needsVerification`.
  final String? sumber;
  final bool needsVerification;

  /// Kode tipe di kartu buku kesalahan: id tanpa nomor, mis. `KB-QA-D`.
  String get tipe => id.substring(0, id.lastIndexOf('-'));

  /// Nomor di akhir id; jadi `ref_id` kartu buku kesalahan.
  int get number => int.parse(id.substring(id.lastIndexOf('-') + 1));

  /// Nama tampilan topik: "siklus-bug" menjadi "Siklus bug".
  String get topikLabel => topicLabel(topik);

  static String topicLabel(String slug) {
    final words = slug.replaceAll('-', ' ').trim();
    if (words.isEmpty) return slug;
    return words[0].toUpperCase() + words.substring(1);
  }

  /// Nama kartu di buku kesalahan dari kode tipenya (`KB-QA-D`), atau null
  /// bila kodenya bukan kode pengetahuan.
  static String? cardName(String tipe) {
    final m = RegExp(r'^KB-([A-Z]+)-([DML])$').firstMatch(tipe);
    if (m == null) return null;
    final role = KnowledgeRole.fromIdCode(m.group(1)!);
    final level = KnowledgeLevel.fromIdCode(m.group(2)!);
    if (role == null || level == null) return null;
    return 'Pengetahuan ${role.label}, ${level.label}';
  }
}

/// Kemajuan satu butir (tabel `knowledge_progress`).
class KnowledgeProgress {
  const KnowledgeProgress({
    required this.butirId,
    required this.level,
    required this.terakhir,
    required this.dikuasai,
  });

  final String butirId;
  final KnowledgeLevel level;
  final DateTime terakhir;
  final bool dikuasai;
}
