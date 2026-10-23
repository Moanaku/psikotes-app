import '../models/codes.dart';
import '../models/notebook.dart';
import 'sm2_scheduler.dart';

extension MistakeCardSchedule on MistakeCard {
  CardSchedule get schedule => CardSchedule(
        jatuhTempo: jatuhTempo,
        intervalHari: intervalHari,
        streakBenar: streakBenar,
        status: status,
      );

  /// Kartu dikuasai yang menunggu pemeriksaan ulang 14 hari (A1).
  bool get awaitsRecheck => Sm2Scheduler.awaitsRecheck(schedule);
}

/// "Hari ini" di buku kesalahan berarti hari kalender setempat: kartu yang
/// jatuh tempo kapan pun sebelum tengah malam ikut hari ini (A80). Jadwal
/// tetap disimpan sebagai saat tepat (jawaban + N hari); hanya penyajian dan
/// penarikan kartu yang membulat ke hari.
abstract final class DueDay {
  /// Batas atas "jatuh tempo hari ini": 1 ms sebelum tengah malam setempat.
  /// Dioper ke `MistakeRepository.watchDue`.
  static DateTime cutoff(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month, local.day + 1)
        .toUtc()
        .subtract(const Duration(milliseconds: 1));
  }

  /// Selisih hari kalender setempat dari [now] ke [due]; yang sudah lewat
  /// dihitung 0.
  static int daysUntil(DateTime due, DateTime now) {
    final a = due.toLocal();
    final b = now.toLocal();
    final days = DateTime.utc(a.year, a.month, a.day)
        .difference(DateTime.utc(b.year, b.month, b.day))
        .inDays;
    return days < 0 ? 0 : days;
  }
}

/// Filter sumber di S10.
enum MistakeFilter {
  semua('Semua'),
  psikotes('Psikotes'),
  capture('Capture'),
  wawancara('Wawancara');

  const MistakeFilter(this.label);
  final String label;

  /// Soal engine dan bank verbal tergolong Psikotes. Wawancara belum punya
  /// sumber kartu (v1.3), jadi tidak ada kartu yang cocok. Butir pengetahuan
  /// hanya tampil di Semua.
  bool accepts(AnswerSource source) => switch (this) {
        MistakeFilter.semua => true,
        MistakeFilter.psikotes =>
          source == AnswerSource.engine || source == AnswerSource.bank,
        MistakeFilter.capture => source == AnswerSource.capture,
        MistakeFilter.wawancara => false,
      };
}

String sourceName(AnswerSource source) => switch (source) {
      AnswerSource.engine || AnswerSource.bank => 'Psikotes',
      AnswerSource.capture => 'Capture',
      AnswerSource.pengetahuan => 'Pengetahuan',
    };

/// Satu baris daftar S10.
class MistakeRow {
  const MistakeRow({
    required this.card,
    required this.due,
    required this.daysUntil,
  });

  final MistakeCard card;

  /// Sudah jatuh tempo hari ini (atau lebih awal).
  final bool due;

  /// Hari kalender sampai jatuh tempo; 0 bila [due].
  final int daysUntil;

  /// Jumlah titik penguasaan yang terisi, 0 sampai 3.
  int get mastery => card.streakBenar.clamp(0, Sm2Scheduler.masteredStreak);

  bool get recheck => card.awaitsRecheck;
}

/// Isi S10 dari semua kartu, tanpa I/O.
class MistakeBookView {
  const MistakeBookView({
    required this.rows,
    required this.dueCount,
    required this.masteredCount,
    required this.totalCards,
    required this.nextDue,
  });

  /// Kartu yang akan muncul lagi (aktif atau menunggu pemeriksaan ulang) dari
  /// sumber yang dipilih, urut jatuh tempo.
  final List<MistakeRow> rows;

  /// Semua sumber, tidak terpengaruh filter.
  final int dueCount;
  final int masteredCount;
  final int totalCards;

  /// Jatuh tempo terdekat di antara kartu yang belum jatuh tempo; null bila
  /// tidak ada.
  final DateTime? nextDue;

  factory MistakeBookView.of(
    List<MistakeCard> cards,
    DateTime now,
    MistakeFilter filter,
  ) {
    final cutoff = DueDay.cutoff(now);
    final rows = <MistakeRow>[];
    var due = 0;
    var mastered = 0;
    DateTime? next;
    for (final c in cards) {
      if (c.status == CardStatus.dikuasai) mastered++;
      final scheduled = c.status == CardStatus.aktif || c.awaitsRecheck;
      if (!scheduled) continue;
      final isDue = !c.jatuhTempo.isAfter(cutoff);
      if (isDue) {
        due++;
      } else if (next == null || c.jatuhTempo.isBefore(next)) {
        next = c.jatuhTempo;
      }
      if (!filter.accepts(c.sumber)) continue;
      rows.add(MistakeRow(
        card: c,
        due: isDue,
        daysUntil: isDue ? 0 : DueDay.daysUntil(c.jatuhTempo, now),
      ));
    }
    rows.sort((a, b) {
      final byDate = a.card.jatuhTempo.compareTo(b.card.jatuhTempo);
      return byDate != 0 ? byDate : a.card.id.compareTo(b.card.id);
    });
    return MistakeBookView(
      rows: rows,
      dueCount: due,
      masteredCount: mastered,
      totalCards: cards.length,
      nextDue: next,
    );
  }
}
