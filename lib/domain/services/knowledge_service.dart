import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/knowledge.dart';
import '../models/notebook.dart';
import '../models/session.dart';
import '../repositories/repositories.dart';
import 'clock.dart';
import 'knowledge_bank.dart';

/// Pemilihan butir untuk satu sesi kartu (S19 ke S20). Deterministik: tanpa
/// keacakan, jadi pilihan yang sama untuk keadaan yang sama.
abstract final class KnowledgeSelector {
  /// Kartu per sesi ("Latihan 10 kartu").
  static const int sessionSize = 10;

  /// Butir untuk ([role], [level]) dengan topik [topik] bila diberikan.
  ///
  /// Urutan: butir yang kartunya jatuh tempo ([dueIds]), butir yang belum
  /// pernah dinilai, butir yang belum dikuasai (terlama dulu), lalu yang sudah
  /// dikuasai. Mode Umum melewati butir yang sudah dikuasai dan menyilangkan
  /// role supaya butirnya lintas role.
  static List<KnowledgeItem> pick(
    KnowledgeBank bank, {
    required KnowledgeRole role,
    required KnowledgeLevel level,
    String? topik,
    Map<String, KnowledgeProgress> progress = const {},
    Set<String> dueIds = const {},
    int count = sessionSize,
  }) {
    var pool = bank.of(role, level);
    if (topik != null) {
      pool = [
        for (final i in pool)
          if (i.topik == topik) i,
      ];
    }
    if (role == KnowledgeRole.umum) {
      pool = [
        for (final i in pool)
          if (progress[i.id]?.dikuasai != true) i
      ];
    }
    int rank(KnowledgeItem i) {
      final p = progress[i.id];
      if (dueIds.contains(i.id)) return 0;
      if (p == null) return 1;
      return p.dikuasai ? 3 : 2;
    }

    final ranked = [...pool]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final pa = progress[a.id]?.terakhir;
        final pb = progress[b.id]?.terakhir;
        if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
        return a.id.compareTo(b.id);
      });
    if (role != KnowledgeRole.umum) return ranked.take(count).toList();

    // Lintas role: bergiliran satu butir per role, urutan rank tetap.
    final byRole = <KnowledgeRole, List<KnowledgeItem>>{
      for (final r in KnowledgeRole.values)
        r: [
          for (final i in ranked)
            if (i.role == r) i
        ],
    }..removeWhere((_, v) => v.isEmpty);
    final out = <KnowledgeItem>[];
    for (var round = 0; out.length < count; round++) {
      var any = false;
      for (final list in byRole.values) {
        if (round < list.length && out.length < count) {
          out.add(list[round]);
          any = true;
        }
      }
      if (!any) break;
    }
    return out;
  }

  /// Ringkasan level: berapa butir ada dan berapa yang dikuasai, dalam
  /// cakupan [role] dan [topik] bila diberikan.
  static ({int total, int mastered}) tally(
    KnowledgeBank bank, {
    required KnowledgeRole role,
    required KnowledgeLevel level,
    String? topik,
    Map<String, KnowledgeProgress> progress = const {},
  }) {
    var total = 0;
    var mastered = 0;
    for (final i in bank.of(role, level)) {
      if (topik != null && i.topik != topik) continue;
      total++;
      if (progress[i.id]?.dikuasai == true) mastered++;
    }
    return (total: total, mastered: mastered);
  }
}

/// Penilaian poin kunci level Lanjut: butir dianggap dipahami bila paling
/// sedikit dua pertiga poin kunci dicentang (A106).
abstract final class KeyPointScoring {
  /// Jumlah poin kunci yang harus dicentang dari [total].
  static int needed(int total) => (total * 2 / 3).ceil();

  static bool passes(int checked, int total) => checked >= needed(total);
}

/// Menyimpan penilaian diri atas satu butir: kemajuan, dan jadwal SM-2 di
/// buku kesalahan (F07).
class KnowledgeService {
  KnowledgeService({
    required KnowledgeRepository progress,
    required MistakeRepository mistakes,
    required Clock clock,
  })  : _progress = progress,
        _mistakes = mistakes,
        _clock = clock;

  final KnowledgeRepository _progress;
  final MistakeRepository _mistakes;
  final Clock _clock;

  /// Jawaban bayangan yang menamai kartu: tanpa sesi, hanya identitas butir.
  static AnswerRecord cardKey(KnowledgeItem item, {required bool paham}) =>
      AnswerRecord(
        sessionId: 0,
        posisi: 0,
        tipe: item.tipe,
        kategori: 'pengetahuan',
        seed: 0,
        kesulitan: Difficulty.medium,
        genVersi: 1,
        sumber: AnswerSource.pengetahuan,
        refId: item.number,
        benar: paham,
        durasiMs: 0,
        label: paham ? SpeedLabel.benarLambat : SpeedLabel.salahLambat,
      );

  /// "Sudah paham" ([paham] true) atau "Belum paham". Belum paham membuat atau
  /// menjadwalkan ulang kartu buku kesalahan sumber `pengetahuan`; sudah paham
  /// pada butir yang kartunya ada dihitung sebagai ulangan benar SM-2.
  Future<void> judge(KnowledgeItem item, {required bool paham}) async {
    final now = _clock.now();
    await _progress.save(KnowledgeProgress(
      butirId: item.id,
      level: item.level,
      terakhir: now,
      dikuasai: paham,
    ));
    final key = cardKey(item, paham: paham);
    if (paham) {
      final card = await _mistakes.findFor(key);
      if (card != null) await _mistakes.applyReview(card.id, true, now);
    } else {
      await _mistakes.upsertFromAnswer(key, now);
    }
  }

  /// Id butir yang kartu buku kesalahannya jatuh tempo.
  static Set<String> dueIds(KnowledgeBank bank, Iterable<MistakeCard> due) => {
        for (final c in due)
          if (c.sumber == AnswerSource.pengetahuan && c.refId != null)
            if (bank.byCard(c.tipe, c.refId!) case final item?) item.id,
      };
}
