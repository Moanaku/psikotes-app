import 'package:question_engine/question_engine.dart';

import '../models/codes.dart';
import '../models/session.dart';

/// Ringkasan satu kategori di hasil sesi.
class CategoryScore {
  const CategoryScore({
    required this.kategori,
    required this.benar,
    required this.jumlah,
    this.medianMs,
  });

  final String kategori;
  final int benar;

  /// Jumlah soal kategori ini di rencana, termasuk yang tidak dijawab.
  final int jumlah;

  /// Median `durasi_ms` soal yang dijawab; null bila tidak ada yang dijawab.
  final int? medianMs;

  double get akurasi => jumlah == 0 ? 0 : benar * 100.0 / jumlah;
}

class SessionSummary {
  const SessionSummary({
    required this.skor,
    required this.benar,
    required this.total,
    required this.tidakDijawab,
    required this.perKategori,
    required this.kuadran,
  });

  /// Persen, 0 sampai 100; sama dengan `SessionRepository.finish`.
  final double skor;
  final int benar;
  final int total;

  /// Soal yang dilewati atau tidak sempat dikerjakan.
  final int tidakDijawab;
  final Map<String, CategoryScore> perKategori;

  /// Hitungan per label. Keempatnya menjumlah ke [total] (S08).
  final Map<SpeedLabel, int> kuadran;
}

/// Penilaian sesi (F05, F06). Fungsi murni.
abstract final class Scoring {
  /// Jendela riwayat untuk ambang cepat dan lambat (docs/03-data-model.md).
  static const Duration window = Duration(days: 30);

  static bool isCorrect(Question question, int? chosen) =>
      chosen != null && chosen == question.correctIndex;

  /// Label kecepatan. Waktu di bawah atau sama dengan ambang berarti cepat.
  /// Soal yang dilewati atau tidak sempat dijawab selalu `salah_lambat`: waktu
  /// habis sebelum jawabannya ada (A46).
  static SpeedLabel label({
    required bool benar,
    required bool dijawab,
    required int durasiMs,
    required int ambangMs,
  }) {
    if (!dijawab) return SpeedLabel.salahLambat;
    final cepat = durasiMs <= ambangMs;
    if (benar) return cepat ? SpeedLabel.benarCepat : SpeedLabel.benarLambat;
    return cepat ? SpeedLabel.salahCepat : SpeedLabel.salahLambat;
  }

  /// Median `durasi_ms` jawaban benar per tipe soal.
  static Map<String, int> correctMedians(Iterable<AnswerRecord> answers) {
    final byType = <String, List<int>>{};
    for (final a in answers) {
      if (!a.benar || a.opsiDipilih == null) continue;
      (byType[a.tipe] ??= []).add(a.durasiMs);
    }
    return {
      for (final e in byType.entries) e.key: median(e.value)!,
    };
  }

  /// Ambang tipe: median riwayat, atau `estimatedSeconds` engine bila belum
  /// ada data.
  static int thresholdMs(
    Map<String, int> medians,
    String tipe,
    int estimatedSeconds,
  ) =>
      medians[tipe] ?? estimatedSeconds * 1000;

  /// Median bilangan bulat (rata-rata dua nilai tengah dibulatkan ke bawah);
  /// null untuk daftar kosong.
  static int? median(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return null;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  /// Skor persen: benar dibagi jumlah soal di rencana.
  static double score(int benar, int total) =>
      total == 0 ? 0 : (benar * 100.0 / total).clamp(0.0, 100.0);

  /// Ringkasan sesi dari rencana dan jawabannya. Soal tanpa baris jawaban
  /// dihitung salah dan lambat, seperti soal yang dilewati.
  static SessionSummary summarize(
    SessionPlan plan,
    Iterable<AnswerRecord> answers,
  ) {
    final byPos = {for (final a in answers) a.posisi: a};
    final kuadran = {for (final l in SpeedLabel.values) l: 0};
    final benarKat = <String, int>{};
    final jumlahKat = <String, int>{};
    final durasiKat = <String, List<int>>{};
    var benar = 0;
    var tidakDijawab = 0;
    for (var i = 0; i < plan.items.length; i++) {
      final a = byPos[i];
      final kategori = a?.kategori ?? plan.items[i].kategoriCode;
      jumlahKat[kategori] = (jumlahKat[kategori] ?? 0) + 1;
      if (a == null || a.opsiDipilih == null) tidakDijawab++;
      if (a == null) {
        kuadran[SpeedLabel.salahLambat] = kuadran[SpeedLabel.salahLambat]! + 1;
        continue;
      }
      kuadran[a.label] = kuadran[a.label]! + 1;
      if (a.benar) {
        benar++;
        benarKat[kategori] = (benarKat[kategori] ?? 0) + 1;
      }
      if (a.opsiDipilih != null) {
        (durasiKat[kategori] ??= []).add(a.durasiMs);
      }
    }
    return SessionSummary(
      skor: score(benar, plan.items.length),
      benar: benar,
      total: plan.items.length,
      tidakDijawab: tidakDijawab,
      perKategori: {
        for (final k in jumlahKat.keys)
          k: CategoryScore(
            kategori: k,
            benar: benarKat[k] ?? 0,
            jumlah: jumlahKat[k]!,
            medianMs: median(durasiKat[k] ?? const []),
          ),
      },
      kuadran: kuadran,
    );
  }
}
