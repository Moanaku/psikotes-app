import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/services/sm2_scheduler.dart';

/// Satu baris tabel jadwal (docs/03-data-model.md, "Jadwal SM-2 sederhana"):
/// keadaan awal, peristiwa, dan keadaan sesudahnya.
class _Row {
  const _Row(
    this.name, {
    required this.streak,
    required this.interval,
    required this.status,
    required this.correct,
    required this.expectStreak,
    required this.expectInterval,
    required this.expectStatus,
    this.expectDue,
  });

  final String name;
  final int streak;
  final int interval;
  final CardStatus status;
  final bool correct;
  final int expectStreak;
  final int expectInterval;
  final CardStatus expectStatus;

  /// Hari dari "sekarang" sampai jatuh tempo baru; null = jatuh tempo tidak
  /// berubah (kartu yang pemeriksaannya sudah lulus).
  final int? expectDue;
}

void main() {
  final now = DateTime.utc(2026, 10, 1, 8);
  final before = DateTime.utc(2026, 9, 20);

  CardSchedule schedule(_Row r) => CardSchedule(
        jatuhTempo: before,
        intervalHari: r.interval,
        streakBenar: r.streak,
        status: r.status,
      );

  const rows = [
    _Row('kartu baru benar: ke tangga 3 hari',
        streak: 0,
        interval: 1,
        status: CardStatus.aktif,
        correct: true,
        expectStreak: 1,
        expectInterval: 3,
        expectStatus: CardStatus.aktif,
        expectDue: 3),
    _Row('streak 1 benar: ke tangga 7 hari',
        streak: 1,
        interval: 3,
        status: CardStatus.aktif,
        correct: true,
        expectStreak: 2,
        expectInterval: 7,
        expectStatus: CardStatus.aktif,
        expectDue: 7),
    _Row('streak 2 benar: dikuasai, cek ulang 14 hari',
        streak: 2,
        interval: 7,
        status: CardStatus.aktif,
        correct: true,
        expectStreak: 3,
        expectInterval: 14,
        expectStatus: CardStatus.dikuasai,
        expectDue: 14),
    _Row('streak 0 salah: tetap di awal, besok',
        streak: 0,
        interval: 1,
        status: CardStatus.aktif,
        correct: false,
        expectStreak: 0,
        expectInterval: 1,
        expectStatus: CardStatus.aktif,
        expectDue: 1),
    _Row('streak 1 salah: kembali ke awal',
        streak: 1,
        interval: 3,
        status: CardStatus.aktif,
        correct: false,
        expectStreak: 0,
        expectInterval: 1,
        expectStatus: CardStatus.aktif,
        expectDue: 1),
    _Row('streak 2 salah: kembali ke awal',
        streak: 2,
        interval: 7,
        status: CardStatus.aktif,
        correct: false,
        expectStreak: 0,
        expectInterval: 1,
        expectStatus: CardStatus.aktif,
        expectDue: 1),
    _Row('cek ulang 14 hari benar: lulus, tidak muncul lagi',
        streak: 3,
        interval: 14,
        status: CardStatus.dikuasai,
        correct: true,
        expectStreak: 3,
        expectInterval: 0,
        expectStatus: CardStatus.dikuasai),
    _Row('cek ulang 14 hari salah: aktif lagi, interval 1',
        streak: 3,
        interval: 14,
        status: CardStatus.dikuasai,
        correct: false,
        expectStreak: 0,
        expectInterval: 1,
        expectStatus: CardStatus.aktif,
        expectDue: 1),
    _Row('sudah lulus cek ulang, benar: tidak berubah',
        streak: 3,
        interval: 0,
        status: CardStatus.dikuasai,
        correct: true,
        expectStreak: 3,
        expectInterval: 0,
        expectStatus: CardStatus.dikuasai),
    _Row('sudah lulus cek ulang, salah: aktif lagi',
        streak: 3,
        interval: 0,
        status: CardStatus.dikuasai,
        correct: false,
        expectStreak: 0,
        expectInterval: 1,
        expectStatus: CardStatus.aktif,
        expectDue: 1),
  ];

  group('afterReview, satu baris tabel jadwal per kasus', () {
    for (final r in rows) {
      test(r.name, () {
        final out = Sm2Scheduler.afterReview(schedule(r), r.correct, now);
        expect(out.streakBenar, r.expectStreak);
        expect(out.intervalHari, r.expectInterval);
        expect(out.status, r.expectStatus);
        expect(
          out.jatuhTempo,
          r.expectDue == null ? before : now.add(Duration(days: r.expectDue!)),
        );
      });
    }
  });

  group('Soal salah di sesi mana pun', () {
    test('kartu dibuat atau diperbarui: awal, jatuh tempo besok', () {
      final r = Sm2Scheduler.afterWrong(now);
      expect(
          (r.streakBenar, r.intervalHari, r.status), (0, 1, CardStatus.aktif));
      expect(r.jatuhTempo, now.add(const Duration(days: 1)));
    });
  });

  group('tangga interval', () {
    test('1, 3, 7 hari lalu pemeriksaan 14 hari (A1)', () {
      final days = <int>[];
      var s = Sm2Scheduler.afterWrong(now);
      days.add(s.intervalHari);
      while (s.status == CardStatus.aktif) {
        s = Sm2Scheduler.afterReview(s, true, now);
        days.add(s.intervalHari);
      }
      expect(days, [1, 3, 7, 14]);
      expect(Sm2Scheduler.ladder, [1, 3, 7]);
      expect(Sm2Scheduler.recheckDays, 14);
    });

    test('keluar dari buku tepat setelah tiga benar berturut-turut', () {
      var s = Sm2Scheduler.afterWrong(now);
      for (var i = 1; i <= 3; i++) {
        s = Sm2Scheduler.afterReview(s, true, now);
        expect(s.streakBenar, i);
        expect(s.status, i < 3 ? CardStatus.aktif : CardStatus.dikuasai);
      }
    });

    test('benar, benar, salah tidak menyisakan streak', () {
      var s = Sm2Scheduler.afterWrong(now);
      s = Sm2Scheduler.afterReview(s, true, now);
      s = Sm2Scheduler.afterReview(s, true, now);
      s = Sm2Scheduler.afterReview(s, false, now);
      expect((s.streakBenar, s.intervalHari), (0, 1));
      s = Sm2Scheduler.afterReview(s, true, now);
      expect((s.streakBenar, s.intervalHari), (1, 3));
    });
  });

  group('pemeriksaan 14 hari (A1)', () {
    CardSchedule mastered() {
      var s = Sm2Scheduler.afterWrong(now);
      for (var i = 0; i < 3; i++) {
        s = Sm2Scheduler.afterReview(s, true, now);
      }
      return s;
    }

    test('kartu dikuasai menunggu pemeriksaan dan jatuh tempo 14 hari lagi',
        () {
      final s = mastered();
      expect(Sm2Scheduler.awaitsRecheck(s), isTrue);
      expect(Sm2Scheduler.isDue(s, now.add(const Duration(days: 13))), isFalse);
      expect(Sm2Scheduler.isDue(s, now.add(const Duration(days: 14))), isTrue);
    });

    test('lulus: tidak pernah jatuh tempo lagi', () {
      final due = now.add(const Duration(days: 14));
      final passed = Sm2Scheduler.afterReview(mastered(), true, due);
      expect(Sm2Scheduler.awaitsRecheck(passed), isFalse);
      expect(passed.status, CardStatus.dikuasai);
      expect(Sm2Scheduler.isDue(passed, due.add(const Duration(days: 400))),
          isFalse);
    });

    test('gagal: aktif dengan interval 1 dan menempuh tangga dari awal', () {
      final due = now.add(const Duration(days: 14));
      var s = Sm2Scheduler.afterReview(mastered(), false, due);
      expect(
          (s.status, s.intervalHari, s.streakBenar), (CardStatus.aktif, 1, 0));
      expect(s.jatuhTempo, due.add(const Duration(days: 1)));
      s = Sm2Scheduler.afterReview(s, true, due);
      expect(s.intervalHari, 3);
    });
  });

  group('isDue', () {
    CardSchedule at(DateTime due, CardStatus status, int interval) =>
        CardSchedule(
          jatuhTempo: due,
          intervalHari: interval,
          streakBenar: status == CardStatus.dikuasai ? 3 : 0,
          status: status,
        );

    test('kartu aktif: tepat pada batas waktu sudah jatuh tempo', () {
      expect(Sm2Scheduler.isDue(at(now, CardStatus.aktif, 1), now), isTrue);
      expect(
        Sm2Scheduler.isDue(
          at(now.add(const Duration(seconds: 1)), CardStatus.aktif, 1),
          now,
        ),
        isFalse,
      );
    });

    test('kartu dikuasai tanpa pemeriksaan tertunda tidak pernah jatuh tempo',
        () {
      expect(
        Sm2Scheduler.isDue(
            at(before, CardStatus.dikuasai, Sm2Scheduler.recheckDone), now),
        isFalse,
      );
    });
  });
}
