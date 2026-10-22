import 'package:question_engine/question_engine.dart';

import 'codes.dart';

/// Satu soal dalam rencana sesi. Soal tidak disimpan utuh: engine membuatnya
/// ulang dari `(type, seed, difficulty, genVersi)`.
class PlanItem {
  const PlanItem({
    required this.type,
    required this.seed,
    required this.difficulty,
    required this.genVersi,
    required this.subtes,
  });

  final QuestionType type;
  final int seed;
  final Difficulty difficulty;
  final int genVersi;

  /// Kategori subtes tempat soal ini berada.
  final String subtes;

  Map<String, Object?> toJson() => {
        'type': type.code,
        'seed': seed,
        'difficulty': difficulty.code,
        'genVersi': genVersi,
        'subtes': subtes,
      };

  factory PlanItem.fromJson(Map<String, Object?> m) => PlanItem(
        type: QuestionType.fromCode(m['type']! as String),
        seed: m['seed']! as int,
        difficulty: Difficulty.fromCode(m['difficulty']! as String),
        genVersi: m['genVersi']! as int,
        subtes: m['subtes']! as String,
      );
}

class SubtestPlan {
  const SubtestPlan({
    required this.kategori,
    required this.jumlah,
    this.menit,
  });

  final String kategori;
  final int jumlah;

  /// Batas waktu subtes; null berarti tanpa batas (mode Latihan).
  final int? menit;

  Map<String, Object?> toJson() =>
      {'kategori': kategori, 'jumlah': jumlah, 'menit': menit};

  factory SubtestPlan.fromJson(Map<String, Object?> m) => SubtestPlan(
        kategori: m['kategori']! as String,
        jumlah: m['jumlah']! as int,
        menit: m['menit'] as int?,
      );
}

/// Isi `rencana_json`.
class SessionPlan {
  const SessionPlan({required this.items, this.subtes = const []});

  final List<PlanItem> items;
  final List<SubtestPlan> subtes;

  Map<String, Object?> toJson() => {
        'items': [for (final i in items) i.toJson()],
        'subtes': [for (final s in subtes) s.toJson()],
      };

  factory SessionPlan.fromJson(Map<String, Object?> m) => SessionPlan(
        items: [
          for (final i in (m['items']! as List))
            PlanItem.fromJson((i as Map).cast<String, Object?>()),
        ],
        subtes: [
          for (final s in (m['subtes'] as List? ?? const []))
            SubtestPlan.fromJson((s as Map).cast<String, Object?>()),
        ],
      );
}

/// Masukan untuk memulai sesi.
class NewSession {
  const NewSession({
    required this.profileId,
    required this.mode,
    required this.plan,
    required this.mulai,
    this.deadline,
  });

  final int profileId;
  final SessionMode mode;
  final SessionPlan plan;
  final DateTime mulai;
  final DateTime? deadline;
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.profileId,
    required this.mode,
    required this.plan,
    required this.mulai,
    this.selesai,
    this.deadline,
    this.posisi = 0,
    this.skor,
  });

  final int id;
  final int profileId;
  final SessionMode mode;
  final SessionPlan plan;
  final DateTime mulai;

  /// Null berarti belum selesai (bisa dilanjutkan).
  final DateTime? selesai;

  /// Batas waktu mutlak subtes yang berjalan, untuk Simulasi.
  final DateTime? deadline;

  /// Indeks soal terakhir.
  final int posisi;

  /// Persen, 0 sampai 100.
  final double? skor;
}

class AnswerRecord {
  const AnswerRecord({
    this.id,
    required this.sessionId,
    required this.tipe,
    required this.kategori,
    required this.seed,
    required this.kesulitan,
    required this.genVersi,
    this.sumber = AnswerSource.engine,
    this.refId,
    this.opsiDipilih,
    required this.benar,
    required this.durasiMs,
    required this.label,
  });

  final int? id;
  final int sessionId;

  /// Kode tipe soal, mis. `FIG-MTX`; untuk Capture boleh tipe buatan pengguna.
  final String tipe;
  final String kategori;
  final int seed;
  final Difficulty kesulitan;
  final int genVersi;
  final AnswerSource sumber;

  /// Id captured_question atau butir bank bila bukan engine.
  final int? refId;

  /// Null berarti dilewati.
  final int? opsiDipilih;
  final bool benar;
  final int durasiMs;
  final SpeedLabel label;
}

class SessionSnapshot {
  const SessionSnapshot({required this.session, required this.answers});

  final SessionRecord session;
  final List<AnswerRecord> answers;
}
