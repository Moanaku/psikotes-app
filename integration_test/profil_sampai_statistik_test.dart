import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simulator_psikotes_it/core/widgets/number_bubble.dart';
import 'package:simulator_psikotes_it/features/session/session_widgets.dart';
import 'package:simulator_psikotes_it/core/widgets/stat_row.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';

import 'support/real_app.dart';

/// Alur 1 (docs/08-rencana-tes.md): profil Umum, simulasi, hasil dan
/// pembahasan, buku kesalahan, lalu statistik. Angka di layar dicocokkan
/// dengan isi database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profil, simulasi, hasil, pembahasan, dan statistik konsisten',
      (tester) async {
    final app = await RealApp.start(tester);
    addTearDown(app.dispose);

    // Onboarding: profil Umum, lewati diagnostik.
    expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
    await app.tapText('Umum, tanpa role');
    await app.tapButton('Lanjut');
    expect(find.text('Profil tes target'), findsOneWidget);
    await app.tapButton('Simpan dan lanjut');
    expect(app.router.routerDelegate.currentConfiguration.uri.toString(),
        '/onboarding/diagnostik');
    await app.tapText('Lewati, nanti saja');
    expect(app.router.routerDelegate.currentConfiguration.uri.toString(), '/');
    final profiles = await app.db.select(app.db.testProfileTable).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.role, ProfileRole.umum.code);
    expect(profiles.single.aktif, isTrue);

    // Simulasi dari katalog: tiga subtes, hanya tiga soal pertama subtes
    // pertama dijawab (benar, salah, benar); sisanya dilewati.
    await app.tapText('Psikotes', last: true);
    await app.tapText('Simulasi');
    await app.tapButton('Mulai simulasi');
    expect(find.textContaining('Subtes 1 dari 3'), findsOneWidget);

    final answered = <bool>[true, false, true];
    for (var i = 0; i < answered.length; i++) {
      app.advanceDays(0);
      app.clock.advance(const Duration(seconds: 40));
      await app.chooseOption(answered[i] ? app.correctIndex : app.wrongIndex);
      await app.tapButton('Berikutnya');
    }
    for (var subtest = 0; subtest < 3; subtest++) {
      // Navigator soal satu baris yang digulir mendatar: gulir ke ujung dulu
      // supaya nomor terakhir subtes terbangun.
      await tester.drag(find.byType(NumberStrip), const Offset(-5000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NumberBubble).last);
      await tester.pumpAndSettle();
      await app.tapButton('Berikutnya');
      final close = find.textContaining(
        RegExp(r'^(Tutup subtes|Selesaikan simulasi)'),
      );
      await tester.tap(close.last);
      await tester.pumpAndSettle();
    }

    // Hasil: skor, kategori, dan jumlah kartu cocok dengan database.
    final sessionRow = (await app.db.select(app.db.sessionTable).get()).single;
    expect(sessionRow.selesai, isNotNull);
    final answers = await app.db.select(app.db.answerTable).get();
    final total = answers.length;
    final correct = answers.where((a) => a.benar).length;
    expect(total, 35, reason: 'numerik 15, logika 10, figural 10');
    expect(correct, 2);
    expect(sessionRow.skor, closeTo(correct / total * 100, 0.01));

    expect(find.text('Hasil sesi'), findsOneWidget);
    expect(find.text('${sessionRow.skor!.round()}%'), findsOneWidget);
    expect(find.text('Umum, CCAT-style'), findsOneWidget);
    // Hanya jawaban yang diisi dan salah masuk buku kesalahan; 32 soal yang
    // tidak dijawab dihitung salah pada skor saja.
    final wrong =
        answers.where((a) => a.opsiDipilih != null && !a.benar).length;
    expect(wrong, 1);
    expect(
      find.textContaining('$wrong soal salah masuk buku kesalahan'),
      findsOneWidget,
    );
    expect(
        find.textContaining('Tidak dijawab: ${total - correct - wrong} soal'),
        findsOneWidget);
    final cards = await app.db.select(app.db.mistakeCardTable).get();
    expect(cards, hasLength(wrong));

    // Pembahasan: soal salah pertama (nomor 2) terbuka dengan kuncinya.
    await app.tapButton('Lihat pembahasan');
    expect(find.text('Salah'), findsWidgets);
    expect(find.text('Pembahasan'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Kembali').first);
    await tester.pumpAndSettle();

    // Beranda lalu Statistik: satu sesi selesai, menit dari durasi jawaban.
    await app.tapText('Beranda', last: true);
    await app.tapText('Statistik', last: true);
    final row = tester.widget<StatRow>(find.byType(StatRow));
    final labels = row.items.map((i) => i.label).toList();
    expect(labels, ['menit minggu ini', 'sesi selesai', 'hari beruntun']);
    final totalMs = answers.fold<int>(0, (sum, a) => sum + a.durasiMs);
    expect(row.items[0].value, '${(totalMs / 60000).round()}');
    expect(row.items[1].value, '1');
    expect(row.items[2].value, '1');
    expect(find.text('Per kategori'), findsOneWidget);
  });
}
