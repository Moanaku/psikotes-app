import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';

import 'support/real_app.dart';

/// Alur 2 (docs/08-rencana-tes.md): jawaban salah membentuk kartu yang jatuh
/// tempo besok; jam dimajukan; tiga ulangan benar berturut-turut menguasai
/// kartu (tangga SM-2 1, 3, 7 hari).
/// Membuka buku kesalahan dari beranda, seperti pemakai yang kembali ke app:
/// layar dibuat baru dan membaca jam saat itu.
Future<void> openBook(RealApp app) async {
  await app.go('/');
  await app.go('/buku-kesalahan');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('salah jadi kartu, tiga ulangan benar menguasainya',
      (tester) async {
    final app = await RealApp.start(tester);
    addTearDown(app.dispose);
    await app.createUmumProfile();

    // Latihan Matriks 3x3 (10 soal): hanya soal pertama dijawab salah.
    await app.tapText('Psikotes', last: true);
    await app.tapText('Matriks 3x3');
    expect(find.text('Mode Latihan, soal 1 dari 10'), findsOneWidget);
    await app.finishPractice(10, correct: (i) => i != 0);

    var cards = await app.db.select(app.db.mistakeCardTable).get();
    expect(cards, hasLength(1));
    var card = cards.single;
    expect(card.tipe, 'FIG-MTX');
    expect(card.status, CardStatus.aktif.code);
    expect((card.streakBenar, card.intervalHari), (0, 1));

    // Hari ini belum ada yang jatuh tempo; kartu itu menunggu besok.
    await openBook(app);
    expect(find.text('Tidak ada kartu jatuh tempo hari ini'), findsOneWidget);
    expect(find.text('Ulangi yang jatuh tempo'), findsNothing);

    // Besok kartu muncul, lalu tiga ulangan benar menaiki tangga 1, 3, 7.
    final ladder = [1, 3, 7];
    final expected = [(1, 3), (2, 7)];
    for (var round = 0; round < 3; round++) {
      if (round > 0) {
        // Sehari sebelum jadwal kartu belum muncul.
        app.advanceDays(ladder[round] - 1);
        await openBook(app);
        expect(find.text('Ulangi yang jatuh tempo'), findsNothing,
            reason: 'ulangan ${round + 1} belum jatuh tempo');
        app.advanceDays(1);
      } else {
        app.advanceDays(1);
      }
      await openBook(app);
      expect(find.text('Ulangi yang jatuh tempo'), findsOneWidget,
          reason: 'ulangan ${round + 1} jatuh tempo');
      await app.tapText('Ulangi yang jatuh tempo');
      expect(find.text('Mode Latihan, soal 1 dari 1'), findsOneWidget);
      await app.finishPractice(1, correct: (_) => true);

      cards = await app.db.select(app.db.mistakeCardTable).get();
      expect(cards, hasLength(1), reason: 'ulangan tidak menambah kartu');
      card = cards.single;
      if (round < 2) {
        expect(card.status, CardStatus.aktif.code);
        expect((card.streakBenar, card.intervalHari), expected[round]);
      }
    }

    // Setelah tiga ulangan benar: dikuasai, masuk pemeriksaan ulang 14 hari.
    expect(card.status, CardStatus.dikuasai.code);
    expect(card.streakBenar, 3);
    expect(card.intervalHari, 14);
    await openBook(app);
    expect(find.text('sudah dikuasai'), findsOneWidget);
    expect(find.text('Tidak ada kartu jatuh tempo hari ini'), findsOneWidget);
  });
}
