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
/// Fungsi murni. Kartu yang baru dikuasai memakai satu pemeriksaan ulang 14
/// hari kemudian (asumsi A1): `intervalHari = 14` berarti pemeriksaan itu
/// belum dilakukan; setelah lulus `intervalHari = 0` dan kartu tidak muncul
/// lagi. Kartu dikuasai dan sudah lulus tidak punya jadwal.
abstract final class Sm2Scheduler {
  static const int masteredStreak = 3;
  static const int recheckDays = 14;
  static const List<int> ladder = [1, 3, 7];

  /// `intervalHari` kartu dikuasai yang pemeriksaan 14 harinya sudah lulus.
  static const int recheckDone = 0;

  /// Kartu dikuasai yang menunggu pemeriksaan ulang 14 hari.
  static bool awaitsRecheck(CardSchedule s) =>
      s.status == CardStatus.dikuasai && s.intervalHari == recheckDays;

  /// Kartu muncul di ulangan: kartu aktif, atau kartu dikuasai yang menunggu
  /// pemeriksaan ulang, dengan batas waktu yang sudah lewat.
  static bool isDue(CardSchedule s, DateTime now) =>
      (s.status == CardStatus.aktif || awaitsRecheck(s)) &&
      !s.jatuhTempo.isAfter(now);

  /// Kartu baru atau yang salah lagi: kembali ke awal.
  static CardSchedule afterWrong(DateTime now) => CardSchedule(
        jatuhTempo: now.add(const Duration(days: 1)),
        intervalHari: 1,
        streakBenar: 0,
        status: CardStatus.aktif,
      );

  /// Jadwal setelah satu ulangan. Ulangan benar pada kartu aktif menaikkan
  /// tangga; pada kartu yang menunggu pemeriksaan ulang menutupnya. Ulangan
  /// salah selalu mengembalikan kartu ke awal.
  static CardSchedule afterReview(
    CardSchedule current,
    bool correct,
    DateTime now,
  ) {
    if (!correct) return afterWrong(now);
    if (current.status == CardStatus.dikuasai) {
      if (!awaitsRecheck(current)) return current;
      return CardSchedule(
        jatuhTempo: current.jatuhTempo,
        intervalHari: recheckDone,
        streakBenar: masteredStreak,
        status: CardStatus.dikuasai,
      );
    }
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
