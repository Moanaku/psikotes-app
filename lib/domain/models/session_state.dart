import 'package:question_engine/question_engine.dart';

import 'codes.dart';
import 'session.dart';

/// Aturan sesi menurut mode (F05).
class SessionRules {
  const SessionRules._({
    required this.immediateFeedback,
    required this.freeNavigation,
    required this.timerRequired,
    required this.timerCanBeDisabled,
  });

  factory SessionRules.of(SessionMode mode) => switch (mode) {
        SessionMode.latihan => const SessionRules._(
            immediateFeedback: true,
            freeNavigation: false,
            timerRequired: false,
            timerCanBeDisabled: true,
          ),
        SessionMode.simulasi => const SessionRules._(
            immediateFeedback: false,
            freeNavigation: true,
            timerRequired: true,
            timerCanBeDisabled: false,
          ),
        SessionMode.diagnostik => const SessionRules._(
            immediateFeedback: false,
            freeNavigation: true,
            timerRequired: false,
            timerCanBeDisabled: false,
          ),
      };

  /// Latihan: benar atau salah dan pembahasan langsung setelah mengirim.
  /// Mode lain: pembahasan hanya di akhir.
  final bool immediateFeedback;

  /// Boleh maju dan mundur di dalam subtes. Tidak pernah ke subtes sebelumnya.
  final bool freeNavigation;

  /// Setiap subtes wajib punya batas waktu.
  final bool timerRequired;
  final bool timerCanBeDisabled;
}

/// Rentang soal satu subtes di rencana sesi: posisi [start] sampai sebelum
/// [end].
class SubtestRange {
  const SubtestRange({
    required this.index,
    required this.kategori,
    required this.start,
    required this.end,
    this.duration,
  });

  final int index;
  final String kategori;
  final int start;
  final int end;

  /// Batas waktu subtes; null berarti tanpa batas.
  final Duration? duration;

  int get jumlah => end - start;
  bool contains(int posisi) => posisi >= start && posisi < end;

  /// Membagi rencana ke subtes. Rencana tanpa daftar subtes menjadi satu
  /// subtes tanpa batas waktu. Melempar [ArgumentError] bila rencana tidak
  /// sah.
  static List<SubtestRange> of(SessionPlan plan) {
    final items = plan.items;
    if (items.isEmpty) throw ArgumentError('rencana sesi kosong');
    if (plan.subtes.isEmpty) {
      return [
        SubtestRange(
          index: 0,
          kategori: items.first.subtes,
          start: 0,
          end: items.length,
        ),
      ];
    }
    final ranges = <SubtestRange>[];
    var start = 0;
    for (final s in plan.subtes) {
      final menit = s.menit;
      if (s.jumlah <= 0) {
        throw ArgumentError('subtes ${s.kategori} tanpa soal');
      }
      if (menit != null && menit <= 0) {
        throw ArgumentError('batas waktu subtes ${s.kategori} harus positif');
      }
      final end = start + s.jumlah;
      if (end > items.length) {
        throw ArgumentError('jumlah soal subtes melebihi rencana');
      }
      for (var i = start; i < end; i++) {
        if (items[i].subtes != s.kategori) {
          throw ArgumentError(
              'soal $i milik ${items[i].subtes}, bukan subtes ${s.kategori}');
        }
      }
      ranges.add(SubtestRange(
        index: ranges.length,
        kategori: s.kategori,
        start: start,
        end: end,
        duration: menit == null ? null : Duration(minutes: menit),
      ));
      start = end;
    }
    if (start != items.length) {
      throw ArgumentError('jumlah soal subtes tidak sama dengan rencana');
    }
    return ranges;
  }
}

/// Hasil mengirim jawaban di mode Latihan.
class AnswerFeedback {
  const AnswerFeedback({
    required this.posisi,
    required this.chosen,
    required this.correctIndex,
    required this.benar,
  });

  final int posisi;
  final int? chosen;
  final int correctIndex;
  final bool benar;
}

/// Pesan singkat saat waktu subtes habis (S07).
class TimeUpNotice {
  const TimeUpNotice({required this.subtest, required this.sessionEnded});

  /// Subtes yang waktunya habis.
  final SubtestRange subtest;

  /// True bila itu subtes terakhir dan sesi selesai.
  final bool sessionEnded;
}

/// Keadaan sesi yang sedang berjalan. Tidak dapat diubah; dibuat ulang oleh
/// `SessionController` setiap ada perubahan.
class SessionState {
  const SessionState({
    required this.sessionId,
    required this.profileId,
    required this.mode,
    required this.plan,
    required this.subtests,
    required this.subtestIndex,
    required this.posisi,
    required this.answers,
    required this.timerEnabled,
    required this.finished,
    this.selected,
    this.feedback,
    this.deadline,
    this.remaining,
    this.question,
    this.questionFailed = false,
    this.notice,
    this.skor,
  });

  final int sessionId;
  final int profileId;
  final SessionMode mode;
  final SessionPlan plan;
  final List<SubtestRange> subtests;
  final int subtestIndex;

  /// Indeks soal yang sedang tampil.
  final int posisi;

  /// Jawaban yang sudah tersimpan, menurut posisi.
  final Map<int, AnswerRecord> answers;

  /// Latihan: timer belum dimatikan pengguna. Simulasi: selalu true.
  final bool timerEnabled;
  final bool finished;

  /// Latihan: opsi yang dipilih tetapi belum dikirim.
  final int? selected;

  /// Latihan: hasil soal yang sudah dikirim.
  final AnswerFeedback? feedback;

  /// Batas waktu mutlak subtes berjalan; null berarti tanpa timer.
  final DateTime? deadline;

  /// Sisa waktu pada bacaan jam terakhir; null berarti tanpa timer.
  final Duration? remaining;

  /// Soal di [posisi]; null bila gagal dibuat ([questionFailed]).
  final Question? question;

  /// Soal tidak bisa dibuat ulang (semua percobaan generator gagal atau versi
  /// generator berbeda). Layar menampilkan teks galat dari spek, bukan pesan
  /// exception.
  final bool questionFailed;
  final TimeUpNotice? notice;

  /// Persen, terisi setelah sesi selesai.
  final double? skor;

  SessionRules get rules => SessionRules.of(mode);
  SubtestRange get subtest => subtests[subtestIndex];
  bool get timed => deadline != null;
  bool get isLastSubtest => subtestIndex == subtests.length - 1;
  bool get isLastInSubtest => posisi == subtest.end - 1;
  AnswerRecord? get currentAnswer => answers[posisi];

  /// Simulasi: boleh mundur di dalam subtes yang sama.
  bool get canGoBack =>
      !finished && rules.freeNavigation && posisi > subtest.start;

  /// Latihan: "Kirim jawaban" aktif.
  bool get canSubmit =>
      !finished &&
      rules.immediateFeedback &&
      feedback == null &&
      selected != null &&
      question != null;
}
