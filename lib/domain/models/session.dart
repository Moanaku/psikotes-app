import 'package:question_engine/question_engine.dart';

import 'codes.dart';

/// Satu soal dalam rencana sesi. Soal engine tidak disimpan utuh: engine
/// membuatnya ulang dari `(type, seed, difficulty, genVersi)`. Soal Capture
/// (F09) dirujuk dari `captured_question` lewat [refId]; isinya tetap di
/// database, bukan di rencana.
class PlanItem {
  const PlanItem({
    required QuestionType this.type,
    required this.seed,
    required this.difficulty,
    required this.genVersi,
    required this.subtes,
    this.cardId,
  })  : source = AnswerSource.engine,
        refId = null,
        _kategori = null;

  /// Soal dari bank pribadi. [kategori] adalah kategori buatan pengguna
  /// (`captured_question.kategori`); seed dan versi generator tidak berlaku.
  const PlanItem.capture({
    required int this.refId,
    required String kategori,
    required this.subtes,
    this.cardId,
  })  : type = null,
        source = AnswerSource.capture,
        seed = 0,
        difficulty = Difficulty.medium,
        genVersi = 0,
        _kategori = kategori;

  /// Soal dari bank verbal (VRB-SYN, VRB-ANA). [refId] adalah nomor butir
  /// bank (`VRB-SYN-0042` bertipe `VRB-SYN`, refId 42); [seed] adalah seed
  /// pemilih butir, [difficulty] kesulitan butir yang terpilih, dan
  /// [genVersi] nomor versi bank.
  const PlanItem.bank({
    required QuestionType this.type,
    required int this.refId,
    required this.seed,
    required this.difficulty,
    required this.genVersi,
    required this.subtes,
    this.cardId,
  })  : source = AnswerSource.bank,
        _kategori = null;

  /// Nilai kolom `tipe` untuk semua soal Capture: identitas kartu dan
  /// jawaban Capture dibaca dari `(sumber, tipe, ref_id)`, jadi tidak ikut
  /// berubah bila pengguna mengganti kategorinya.
  static const String captureTipe = 'CAPTURE';

  /// Null untuk soal Capture (kategori buatan pengguna bukan [QuestionType]).
  final QuestionType? type;
  final AnswerSource source;
  final int? refId;
  final int seed;
  final Difficulty difficulty;
  final int genVersi;
  final String? _kategori;

  /// Kategori subtes tempat soal ini berada.
  final String subtes;

  /// Kartu buku kesalahan yang diulang oleh soal ini (seed baru, tipe sama
  /// untuk soal engine; butir yang sama untuk Capture). Null untuk soal biasa.
  /// Saat sesi selesai, jawaban soal ini menjadwal ulang kartu itu, bukan
  /// membuat kartu baru.
  final int? cardId;

  bool get isCapture => source == AnswerSource.capture;
  bool get isBank => source == AnswerSource.bank;

  /// Kode tipe yang ditulis ke `answer.tipe`.
  String get tipeCode => type?.code ?? captureTipe;

  /// Kategori yang ditulis ke `answer.kategori`.
  String get kategoriCode => type?.category.code ?? _kategori!;

  PlanItem withSubtes(String subtes) => type == null
      ? PlanItem.capture(
          refId: refId!,
          kategori: _kategori!,
          subtes: subtes,
          cardId: cardId,
        )
      : isBank
          ? PlanItem.bank(
              type: type!,
              refId: refId!,
              seed: seed,
              difficulty: difficulty,
              genVersi: genVersi,
              subtes: subtes,
              cardId: cardId,
            )
          : PlanItem(
              type: type!,
              seed: seed,
              difficulty: difficulty,
              genVersi: genVersi,
              subtes: subtes,
              cardId: cardId,
            );

  Map<String, Object?> toJson() => isBank
      ? {
          'sumber': AnswerSource.bank.code,
          'type': type!.code,
          'refId': refId,
          'seed': seed,
          'difficulty': difficulty.code,
          'genVersi': genVersi,
          'subtes': subtes,
          if (cardId != null) 'cardId': cardId,
        }
      : type == null
          ? {
              'sumber': AnswerSource.capture.code,
              'refId': refId,
              'kategori': _kategori,
              'subtes': subtes,
              if (cardId != null) 'cardId': cardId,
            }
          : {
              'type': type!.code,
              'seed': seed,
              'difficulty': difficulty.code,
              'genVersi': genVersi,
              'subtes': subtes,
              if (cardId != null) 'cardId': cardId,
            };

  factory PlanItem.fromJson(Map<String, Object?> m) {
    if (m['sumber'] == AnswerSource.capture.code) {
      return PlanItem.capture(
        refId: m['refId']! as int,
        kategori: m['kategori']! as String,
        subtes: m['subtes']! as String,
        cardId: m['cardId'] as int?,
      );
    }
    if (m['sumber'] == AnswerSource.bank.code) {
      return PlanItem.bank(
        type: QuestionType.fromCode(m['type']! as String),
        refId: m['refId']! as int,
        seed: m['seed']! as int,
        difficulty: Difficulty.fromCode(m['difficulty']! as String),
        genVersi: m['genVersi']! as int,
        subtes: m['subtes']! as String,
        cardId: m['cardId'] as int?,
      );
    }
    return PlanItem(
      type: QuestionType.fromCode(m['type']! as String),
      seed: m['seed']! as int,
      difficulty: Difficulty.fromCode(m['difficulty']! as String),
      genVersi: m['genVersi']! as int,
      subtes: m['subtes']! as String,
      cardId: m['cardId'] as int?,
    );
  }
}

class SubtestPlan {
  /// Nama subtes bagi soal campuran lintas kategori, mis. bagian latihan
  /// rencana harian yang diikuti satu subtes bertimer.
  static const String mixedLabel = 'campuran';

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
    required this.posisi,
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
    this.dijawabPada,
  });

  final int? id;
  final int sessionId;

  /// Indeks soal di rencana sesi (0 dan seterusnya). Satu jawaban per
  /// (sesi, posisi): menjawab ulang soal yang sama menggantikan jawabannya.
  final int posisi;

  /// Kode tipe soal, mis. `FIG-MTX`; untuk Capture boleh tipe buatan pengguna.
  final String tipe;
  final String kategori;
  final int seed;
  final Difficulty kesulitan;
  final int genVersi;
  final AnswerSource sumber;

  /// Wajib bila bukan engine: id captured_question, atau nomor butir bank
  /// ("VRB-SYN-0042" menjadi tipe `VRB-SYN`, refId 42).
  final int? refId;

  /// Null berarti dilewati.
  final int? opsiDipilih;
  final bool benar;
  final int durasiMs;
  final SpeedLabel label;

  /// Kapan jawaban dicatat (UTC); null pada data lama dan soal dilewati.
  final DateTime? dijawabPada;
}

class SessionSnapshot {
  const SessionSnapshot({required this.session, required this.answers});

  final SessionRecord session;
  final List<AnswerRecord> answers;
}
