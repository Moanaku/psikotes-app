import '../models/codes.dart';

/// Keadaan jadwal satu kartu buku kesalahan.
class CardSchedule {
  const CardSchedule({
    required this.jatuhTempo,
    required this.intervalHari,
    required this.streakBenar,
    required this.status,
  });

  final DateTime jatuhTempo;
  final int intervalHari;
  final int streakBenar;
  final CardStatus status;
}

/// Jadwal SM-2 sederhana (docs/03-data-model.md). Tangga interval 1, 3, 7 hari;
/// keluar dari buku setelah 3 jawaban benar berturut-turut.
///
/// Fungsi murni. Pemeriksaan ulang 14 hari setelah dikuasai (asumsi A1)
/// dicatat lewat `jatuhTempo` kartu dikuasai; layar dan penarikannya milik T16.
abstract final class Sm2Scheduler {
  static const int masteredStreak = 3;
  static const int recheckDays = 14;
  static const List<int> ladder = [1, 3, 7];

  /// Kartu baru atau yang salah lagi: kembali ke awal.
  static CardSchedule afterWrong(DateTime now) => CardSchedule(
        jatuhTempo: now.add(const Duration(days: 1)),
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
      );

  static CardSchedule afterReview(
    CardSchedule current,
    bool correct,
    DateTime now,
  ) {
    if (!correct) return afterWrong(now);
    if (current.status == CardStatus.dikuasai) return current;
    final streak = current.streakBenar + 1;
    if (streak >= masteredStreak) {
      return CardSchedule(
        jatuhTempo: now.add(const Duration(days: recheckDays)),
        intervalHari: recheckDays,
        streakBenar: masteredStreak,
        status: CardStatus.dikuasai,
      );
    }
    final interval = ladder[streak];
    return CardSchedule(
      jatuhTempo: now.add(Duration(days: interval)),
      intervalHari: interval,
      streakBenar: streak,
      status: CardStatus.aktif,
    );
  }
}
