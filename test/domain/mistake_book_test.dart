import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/services/mistake_book.dart';

void main() {
  // 08:00 UTC: tanggal setempat sama dengan tanggal UTC di zona waktu mana
  // pun dari UTC-8 sampai UTC+15, jadi selisih hari kalender tidak bergantung
  // pada zona waktu mesin.
  final now = DateTime.utc(2026, 10, 22, 8);

  MistakeCard card(
    int id, {
    int days = 0,
    int hours = 0,
    CardStatus status = CardStatus.aktif,
    int streak = 0,
    int interval = 1,
    AnswerSource source = AnswerSource.engine,
  }) =>
      MistakeCard(
        id: id,
        tipe: 'NUM-SEQ',
        kategori: 'numerik',
        seed: source == AnswerSource.engine ? id : null,
        sumber: source,
        refId: source == AnswerSource.engine ? null : id,
        jatuhTempo: now.add(Duration(days: days, hours: hours)),
        intervalHari: interval,
        streakBenar: streak,
        status: status,
        dibuat: now,
      );

  group('DueDay', () {
    test('cutoff: tepat sebelum tengah malam setempat', () {
      final cutoff = DueDay.cutoff(now);
      final local = cutoff.toLocal();
      final today = now.toLocal();
      expect((local.year, local.month, local.day),
          (today.year, today.month, today.day));
      expect((local.hour, local.minute, local.second), (23, 59, 59));
      expect(cutoff.isUtc, isTrue);
    });

    test('daysUntil: hari kalender, yang lewat jadi 0', () {
      expect(DueDay.daysUntil(now, now), 0);
      expect(DueDay.daysUntil(now.add(const Duration(days: 1)), now), 1);
      expect(DueDay.daysUntil(now.add(const Duration(days: 3)), now), 3);
      expect(DueDay.daysUntil(now.subtract(const Duration(days: 2)), now), 0);
    });
  });

  group('MistakeBookView', () {
    test('hitungan: jatuh tempo hari ini dan dikuasai, semua sumber', () {
      final v = MistakeBookView.of([
        card(1, days: -2),
        card(2),
        card(3, days: 1),
        card(4, source: AnswerSource.capture),
        card(5, status: CardStatus.dikuasai, streak: 3, interval: 0, days: -20),
        card(6, status: CardStatus.dikuasai, streak: 3, interval: 14, days: -1),
      ], now, MistakeFilter.psikotes);
      // Jatuh tempo: 1, 2, 4 (Capture tetap dihitung), 6 (cek ulang 14 hari).
      expect(v.dueCount, 4);
      expect(v.masteredCount, 2);
      expect(v.totalCards, 6);
    });

    test('daftar: kartu aktif dan cek ulang saja, urut jatuh tempo lalu id',
        () {
      final v = MistakeBookView.of([
        card(3, days: 3),
        card(2, days: -1),
        card(1, days: -1),
        card(4, status: CardStatus.dikuasai, streak: 3, interval: 0, days: -20),
        card(5, status: CardStatus.dikuasai, streak: 3, interval: 14, days: 2),
      ], now, MistakeFilter.semua);
      expect(v.rows.map((r) => r.card.id), [1, 2, 5, 3]);
      expect(v.rows.map((r) => r.due), [true, true, false, false]);
      expect(v.rows.map((r) => r.daysUntil), [0, 0, 2, 3]);
      expect(v.rows.firstWhere((r) => r.card.id == 5).recheck, isTrue);
    });

    test('kartu yang jatuh tempo nanti hari ini sudah dihitung hari ini', () {
      // Tepat pada cutoff masih hari ini; semenit setelahnya besok.
      final cutoff = DueDay.cutoff(now);
      MistakeCard at(int id, DateTime due) => MistakeCard(
            id: id,
            tipe: 'NUM-SEQ',
            kategori: 'numerik',
            seed: id,
            sumber: AnswerSource.engine,
            jatuhTempo: due,
            intervalHari: 1,
            streakBenar: 0,
            status: CardStatus.aktif,
            dibuat: now,
          );
      final v = MistakeBookView.of([
        at(1, cutoff),
        at(2, cutoff.add(const Duration(minutes: 1))),
      ], now, MistakeFilter.semua);
      expect(v.dueCount, 1);
      expect(v.rows.map((r) => r.due), [true, false]);
      expect(v.rows.last.daysUntil, 1);
    });

    test('filter: Psikotes, Capture, Wawancara menyaring daftar, bukan angka',
        () {
      final cards = [
        card(1, days: -1),
        card(2, days: 1, source: AnswerSource.bank),
        card(3, days: -1, source: AnswerSource.capture),
        card(4, days: 2, source: AnswerSource.pengetahuan),
      ];
      List<int> ids(MistakeFilter f) =>
          MistakeBookView.of(cards, now, f).rows.map((r) => r.card.id).toList();
      expect(ids(MistakeFilter.semua), [1, 3, 2, 4]);
      expect(ids(MistakeFilter.psikotes), [1, 2]);
      expect(ids(MistakeFilter.capture), [3]);
      expect(ids(MistakeFilter.wawancara), isEmpty);
      for (final f in MistakeFilter.values) {
        final v = MistakeBookView.of(cards, now, f);
        expect(v.dueCount, 2, reason: 'angka atas tidak ikut filter ($f)');
      }
    });

    test('nextDue: jatuh tempo terdekat di antara yang belum jatuh tempo', () {
      final v = MistakeBookView.of(
        [card(1, days: -1), card(2, days: 5), card(3, days: 2)],
        now,
        MistakeFilter.semua,
      );
      expect(v.nextDue, now.add(const Duration(days: 2)));
      expect(
        MistakeBookView.of([card(1, days: -1)], now, MistakeFilter.semua)
            .nextDue,
        isNull,
      );
    });

    test('titik penguasaan mengikuti streak, 0 sampai 3', () {
      final v = MistakeBookView.of(
        [card(1, streak: 0), card(2, streak: 2, interval: 7, days: 7)],
        now,
        MistakeFilter.semua,
      );
      expect(v.rows.map((r) => r.mastery), [0, 2]);
    });

    test('tanpa kartu: semuanya nol', () {
      final v = MistakeBookView.of(const [], now, MistakeFilter.semua);
      expect(v.rows, isEmpty);
      expect(v.dueCount, 0);
      expect(v.masteredCount, 0);
      expect(v.totalCards, 0);
      expect(v.nextDue, isNull);
    });
  });

  group('MistakeFilter.accepts', () {
    test('Psikotes memuat engine dan bank; Wawancara belum memuat apa pun', () {
      expect(MistakeFilter.psikotes.accepts(AnswerSource.engine), isTrue);
      expect(MistakeFilter.psikotes.accepts(AnswerSource.bank), isTrue);
      expect(MistakeFilter.psikotes.accepts(AnswerSource.capture), isFalse);
      expect(MistakeFilter.capture.accepts(AnswerSource.capture), isTrue);
      for (final s in AnswerSource.values) {
        expect(MistakeFilter.wawancara.accepts(s), isFalse);
        expect(MistakeFilter.semua.accepts(s), isTrue);
      }
    });
  });
}
