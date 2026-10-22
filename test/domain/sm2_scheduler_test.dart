import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/services/sm2_scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 8);
  CardSchedule card(
          {int streak = 0,
          int interval = 1,
          CardStatus s = CardStatus.aktif}) =>
      CardSchedule(
        jatuhTempo: now,
        intervalHari: interval,
        streakBenar: streak,
        status: s,
      );

  test('salah: kembali ke awal, jatuh tempo besok', () {
    final r = Sm2Scheduler.afterWrong(now);
    expect((r.streakBenar, r.intervalHari, r.status), (0, 1, CardStatus.aktif));
    expect(r.jatuhTempo, now.add(const Duration(days: 1)));
  });

  test(
      'benar berturut-turut: 3 hari, 7 hari, lalu dikuasai dengan cek ulang 14 hari',
      () {
    final a = Sm2Scheduler.afterReview(card(), true, now);
    expect((a.streakBenar, a.intervalHari), (1, 3));
    final b = Sm2Scheduler.afterReview(a, true, now);
    expect((b.streakBenar, b.intervalHari), (2, 7));
    final c = Sm2Scheduler.afterReview(b, true, now);
    expect(c.status, CardStatus.dikuasai);
    expect(c.streakBenar, 3);
    expect(c.jatuhTempo, now.add(const Duration(days: 14)));
  });

  test('ulangan salah di tengah tangga mengulang dari awal', () {
    final r =
        Sm2Scheduler.afterReview(card(streak: 2, interval: 7), false, now);
    expect((r.streakBenar, r.intervalHari, r.status), (0, 1, CardStatus.aktif));
  });

  test('kartu dikuasai: benar tidak mengubah, salah mengaktifkan lagi', () {
    final done = card(streak: 3, interval: 14, s: CardStatus.dikuasai);
    expect(identical(Sm2Scheduler.afterReview(done, true, now), done), isTrue);
    final back = Sm2Scheduler.afterReview(done, false, now);
    expect((back.status, back.intervalHari), (CardStatus.aktif, 1));
  });
}
