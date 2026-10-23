import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/figure_view.dart';
import 'package:simulator_psikotes_it/core/widgets/number_bubble.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/question_guides.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_clock.dart';
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

Future<AppHarness> openSession(
  WidgetTester tester,
  SessionMode mode,
  SessionPlan plan, {
  FakeSessionRepository? sessions,
  FakeClock? clock,
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    sessions: sessions,
    clock: clock,
    textScale: textScale,
    overrides: overrides,
  );
  final id = await app.startSession(mode, plan);
  await app.openSession(id);
  return app;
}

Finder option(int i) => find.byType(OptionTile).at(i);

Future<void> tapOption(WidgetTester tester, int i) async {
  await tester.ensureVisible(option(i));
  await tester.tap(option(i));
  await tester.pumpAndSettle();
}

Finder button(String label) => find.widgetWithText(AppButton, label);

VoidCallback? onPressed(WidgetTester tester, String label) =>
    tester.widget<AppButton>(button(label)).onPressed;

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(button(label));
  await tester.tap(button(label));
  await tester.pumpAndSettle();
}

bool selected(WidgetTester tester, int i) =>
    tester.widget<OptionTile>(option(i)).selected;

String letter(int i) => String.fromCharCode(0x41 + i);

void main() {
  group('latihan (S06)', () {
    testWidgets('judul tipe, mode, nomor soal, opsi, dan Kirim yang menunggu',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      expect(app.location, '/sesi/1');
      expect(find.text('Hitungan cepat'), findsOneWidget);
      expect(find.text('Mode Latihan, soal 1 dari 3'), findsOneWidget);
      expect(find.byType(NumberBubble), findsNWidgets(3));
      final q = app.sessionState!.question!;
      expect(find.text(q.stem.text!), findsOneWidget);
      expect(find.byType(OptionTile), findsNWidgets(q.options.length));
      expect(find.text('Buka petunjuk'), findsOneWidget);
      expect(find.text('Kirim jawaban'), findsOneWidget);
      expect(onPressed(tester, 'Kirim jawaban'), isNull,
          reason: 'tidak aktif sebelum ada opsi terpilih');
    });

    testWidgets('memilih opsi mengaktifkan Kirim dengan hurufnya; satu pilihan',
        (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan());
      await tapOption(tester, 1);
      expect(button('Kirim jawaban B'), findsOneWidget);
      expect(onPressed(tester, 'Kirim jawaban B'), isNotNull);
      expect(selected(tester, 1), isTrue);
      await tapOption(tester, 2);
      expect(selected(tester, 1), isFalse);
      expect(selected(tester, 2), isTrue);
      expect(button('Kirim jawaban C'), findsOneWidget);
    });

    testWidgets('jawaban benar: Benar, pembahasan, opsi terkunci, lalu lanjut',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      final q = app.sessionState!.question!;
      await tapOption(tester, q.correctIndex);
      await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');

      expect(find.text('Benar'), findsOneWidget);
      expect(find.text('Pembahasan'), findsOneWidget);
      expect(find.text(q.explanation), findsOneWidget);
      expect(find.text('Kirim jawaban'), findsNothing);
      expect(find.text('Berikutnya'), findsOneWidget);
      expect(tester.widget<OptionTile>(option(0)).onTap, isNull,
          reason: 'jawaban terkirim tidak bisa diganti');

      final saved = app.sessions.answersOf(1)[0]!;
      expect(saved.benar, isTrue);
      expect(saved.opsiDipilih, q.correctIndex);

      await tapButton(tester, 'Berikutnya');
      expect(find.text('Mode Latihan, soal 2 dari 3'), findsOneWidget);
      expect(find.text('Benar'), findsNothing);
      expect(onPressed(tester, 'Kirim jawaban'), isNull);
      final bubbles = tester
          .widgetList<NumberBubble>(find.byType(NumberBubble))
          .map((b) => b.state)
          .toList();
      expect(bubbles, [
        NumberBubbleState.answered,
        NumberBubbleState.current,
        NumberBubbleState.unanswered,
      ]);
    });

    testWidgets('jawaban salah: Salah dengan kunci dan pembahasan',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      final q = app.sessionState!.question!;
      final wrong = q.correctIndex == 0 ? 1 : 0;
      await tapOption(tester, wrong);
      await tapButton(tester, 'Kirim jawaban ${letter(wrong)}');
      expect(
          find.text('Salah. Kunci: ${letter(q.correctIndex)}'), findsOneWidget);
      expect(find.text(q.explanation), findsOneWidget);
      expect(app.sessions.answersOf(1)[0]!.benar, isFalse);
    });

    testWidgets('soal terakhir: Lihat hasil membuka S08 dan menutup sesi',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      for (var n = 0; n < 3; n++) {
        final q = app.sessionState!.question!;
        await tapOption(tester, q.correctIndex);
        await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
        await tapButton(tester, n == 2 ? 'Lihat hasil' : 'Berikutnya');
      }
      expect(app.location, '/hasil/1');
      final s = app.sessions.sessions[1]!;
      expect(s.selesai, isNotNull);
      expect(s.skor, 100);
      expect(app.sessionState, isNull,
          reason: 'controller dibersihkan saat layar sesi ditinggalkan');
    });

    testWidgets('petunjuk: aturan soal tanpa jawaban, menutup saat soal ganti',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      expect(find.text(questionTypeHint(QuestionType.numAri)), findsNothing);
      await tapButton(tester, 'Buka petunjuk');
      expect(find.text(questionTypeHint(QuestionType.numAri)), findsOneWidget);
      expect(find.text('Tutup petunjuk'), findsOneWidget);

      await tapButton(tester, 'Tutup petunjuk');
      expect(find.text(questionTypeHint(QuestionType.numAri)), findsNothing);

      await tapButton(tester, 'Buka petunjuk');
      final q = app.sessionState!.question!;
      await tapOption(tester, q.correctIndex);
      await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
      expect(find.text(questionTypeHint(QuestionType.numAri)), findsNothing,
          reason: 'sesudah menjawab pembahasan menggantikan petunjuk');
      await tapButton(tester, 'Berikutnya');
      expect(find.text(questionTypeHint(QuestionType.numAri)), findsNothing);
      expect(find.text('Buka petunjuk'), findsOneWidget);
    });

    testWidgets('soal bergambar: stem figur dan opsi bergambar berlabel',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      for (var n = 0; n < 2; n++) {
        final q = app.sessionState!.question!;
        await tapOption(tester, q.correctIndex);
        await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
        await tapButton(tester, 'Berikutnya');
      }
      expect(find.text('Matriks 3x3'), findsOneWidget);
      final q = app.sessionState!.question!;
      expect(find.byType(FigureView), findsNWidgets(1 + q.options.length));
      for (var i = 0; i < q.options.length; i++) {
        final tile = tester.widget<OptionTile>(option(i));
        expect(tile.semanticLabel, isNotEmpty, reason: 'opsi ${tile.letter}');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('timer latihan', () {
    testWidgets('tanpa menit: tanpa timer dan tanpa tombol mematikan',
        (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan());
      expect(find.text('Matikan timer'), findsNothing);
      expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsNothing);
    });

    testWidgets('timer menghitung mundur dari deadline dan bisa dimatikan',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.latihan, timedLatihanPlan());
      expect(find.text('05:00'), findsOneWidget);
      await app.tickSeconds(30);
      expect(find.text('04:30'), findsOneWidget);

      await tapButton(tester, 'Matikan timer');
      expect(find.text('04:30'), findsNothing);
      expect(find.text('Matikan timer'), findsNothing);
      expect(app.sessions.sessions[1]!.deadline, isNull);
      await app.tickSeconds(60);
      expect(find.text('Mode Latihan, soal 1 dari 3'), findsOneWidget,
          reason: 'waktu habis tidak menutup subtes bila timer dimatikan');
    });
  });

  group('simulasi (S07)', () {
    testWidgets('judul dengan nama profil, langkah subtes, kisi, dan catatan',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan());
      expect(find.text('Simulasi'), findsOneWidget);
      expect(find.text('QA, CCAT-style'), findsOneWidget,
          reason: 'nama profil jadi baris sekunder, bukan judul');
      expect(find.text('05:00'), findsOneWidget);
      for (final k in ['Numerik', 'Logika', 'Figural']) {
        expect(find.text(k), findsOneWidget, reason: k);
      }
      expect(find.text('Subtes 1 dari 3, soal 1 dari 3'), findsOneWidget);
      expect(find.byType(NumberBubble), findsNWidgets(3));
      expect(find.byType(ListView), findsWidgets,
          reason: 'navigator soal satu baris yang digulir mendatar');
      expect(
        find.textContaining('Setelah subtes ditutup, kamu tidak bisa kembali '
            'ke sana. Pembahasan muncul setelah simulasi selesai.'),
        findsOneWidget,
      );
      expect(find.text('Kirim jawaban'), findsNothing,
          reason: 'simulasi tanpa kirim dan tanpa pembahasan');
      expect(onPressed(tester, 'Sebelumnya'), isNull);
      expect(find.text('Buka petunjuk'), findsNothing);
    });

    testWidgets('memilih opsi langsung tersimpan dan bisa diganti',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await tapOption(tester, 2);
      expect(app.sessions.answersOf(1)[0]!.opsiDipilih, 2);
      expect(selected(tester, 2), isTrue);
      await tapOption(tester, 0);
      expect(app.sessions.answersOf(1)[0]!.opsiDipilih, 0);
      expect(selected(tester, 0), isTrue);
      expect(selected(tester, 2), isFalse);
      expect(
        tester.widget<NumberBubble>(find.byType(NumberBubble).first).state,
        NumberBubbleState.current,
      );
    });

    testWidgets('navigasi bebas di dalam subtes: Berikutnya, Sebelumnya, kisi',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await tapOption(tester, 1);
      await tapButton(tester, 'Berikutnya');
      expect(find.text('Subtes 1 dari 3, soal 2 dari 3'), findsOneWidget);
      expect(onPressed(tester, 'Sebelumnya'), isNotNull);
      await tapButton(tester, 'Sebelumnya');
      expect(find.text('Subtes 1 dari 3, soal 1 dari 3'), findsOneWidget);
      expect(selected(tester, 1), isTrue, reason: 'jawaban tetap tampil');

      await tester.tap(find.byType(NumberBubble).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Subtes 1 dari 3, soal 3 dari 3'), findsOneWidget);
      expect(app.sessions.sessions[1]!.posisi, 2);
    });

    testWidgets(
        'soal terakhir subtes: konfirmasi, lalu subtes berikutnya '
        'tanpa jalan kembali', (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await tapOption(tester, 0);
      await tester.tap(find.byType(NumberBubble).at(2));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Berikutnya');

      expect(find.textContaining('Tutup subtes Numerik?'), findsOneWidget);
      expect(find.textContaining('2 soal belum dijawab'), findsOneWidget);
      expect(find.text('Subtes 1 dari 3, soal 3 dari 3'), findsOneWidget);

      await tapButton(tester, 'Tetap di subtes');
      expect(find.textContaining('Tutup subtes Numerik?'), findsNothing);
      expect(app.sessionState!.subtestIndex, 0);

      await tapButton(tester, 'Berikutnya');
      await tapButton(tester, 'Tutup subtes Numerik');
      expect(find.text('Subtes 2 dari 3, soal 1 dari 2'), findsOneWidget);
      expect(find.text('Logika'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget,
          reason: 'subtes berikutnya mulai dengan durasi penuh');
      expect(
        find.textContaining('Tidak bisa kembali ke subtes Numerik. '
            'Pembahasan muncul setelah simulasi selesai.'),
        findsOneWidget,
      );
      expect(onPressed(tester, 'Sebelumnya'), isNull);
      final answers = app.sessions.answersOf(1);
      expect(answers[0]!.opsiDipilih, 0);
      expect(answers[1]!.opsiDipilih, isNull, reason: 'dilewati');
      expect(answers[2]!.opsiDipilih, isNull);
    });

    testWidgets('subtes terakhir: Selesaikan simulasi membuka S08',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      for (final last in [2, 1, 1]) {
        await tester.tap(find.byType(NumberBubble).at(last));
        await tester.pumpAndSettle();
        await tapButton(tester, 'Berikutnya');
        final close =
            find.textContaining(RegExp(r'^(Tutup subtes|Selesaikan simulasi)'));
        await tester
            .tap(find.descendant(of: find.byType(Row), matching: close.last));
        await tester.pumpAndSettle();
      }
      expect(app.location, '/hasil/1');
      expect(app.sessions.sessions[1]!.selesai, isNotNull);
    });

    testWidgets('waktu subtes habis: pindah otomatis dengan pesan singkat',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await tapOption(tester, 1);
      await app.tickSeconds(5 * 60 + 1);
      expect(find.text('Subtes 2 dari 3, soal 1 dari 2'), findsOneWidget);
      expect(
        find.text('Waktu subtes Numerik habis. Lanjut ke subtes Logika.'),
        findsOneWidget,
      );
      expect(find.text('04:00'), findsOneWidget);
      expect(app.sessions.answersOf(1)[0]!.opsiDipilih, 1);
      expect(app.sessions.answersOf(1)[1]!.opsiDipilih, isNull);

      await tapButton(tester, 'Tutup pesan');
      expect(find.textContaining('Waktu subtes Numerik habis'), findsNothing);
    });

    testWidgets('waktu subtes terakhir habis: sesi selesai dan membuka S08',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await app.tickSeconds(5 * 60 + 1);
      await app.tickSeconds(4 * 60 + 1);
      await app.tickSeconds(3 * 60 + 1);
      expect(app.location, '/hasil/1');
      expect(app.sessions.sessions[1]!.selesai, isNotNull);
    });
  });

  group('siklus hidup app', () {
    testWidgets(
        'ke latar belakang menghentikan penanda; kembali menghitung '
        'ulang dari deadline dan waktu latar tidak dihitung per soal',
        (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await app.tickSeconds(10);
      expect(app.ticker.active, isNotNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(app.ticker.active, isNull,
          reason: 'onPaused menghentikan penanda');

      app.clock.sleep(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(app.ticker.active, isNotNull);
      expect(find.text('02:50'), findsOneWidget,
          reason: '5:00 dikurangi 10 detik dan 2 menit di latar belakang');

      await app.tickSeconds(5);
      await tapOption(tester, 0);
      final saved = app.sessions.answersOf(1)[0]!;
      expect(saved.durasiMs, lessThan(30000),
          reason: 'durasi melihat soal tidak menghitung dua menit di latar');
      expect(saved.durasiMs, greaterThanOrEqualTo(15000));
    });

    testWidgets(
        'waktu habis saat di latar belakang: kembali ke subtes '
        'berikutnya', (tester) async {
      final app =
          await openSession(tester, SessionMode.simulasi, simulasiPlan());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      app.clock.sleep(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Subtes 2 dari 3, soal 1 dari 2'), findsOneWidget);
      expect(find.textContaining('Waktu subtes Numerik habis'), findsOneWidget);
    });
  });

  group('melanjutkan sesi setelah proses mati', () {
    Future<AppHarness> reopen(
      WidgetTester tester,
      FakeSessionRepository sessions,
      FakeClock clock,
    ) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      return pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
        clock: clock,
      );
    }

    testWidgets('latihan: soal terakhir dan jawaban sebelumnya kembali',
        (tester) async {
      final sessions = FakeSessionRepository();
      final clock = FakeClock(appNow);
      final first = await openSession(
          tester, SessionMode.latihan, latihanPlan(),
          sessions: sessions, clock: clock);
      final q = first.sessionState!.question!;
      await tapOption(tester, q.correctIndex);
      await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
      await tapButton(tester, 'Berikutnya');

      final app = await reopen(tester, sessions, clock);
      expect(app.sessionState, isNull, reason: 'keadaan memori hilang');
      await app.go('/sesi/1');
      expect(find.text('Mode Latihan, soal 2 dari 3'), findsOneWidget);
      final bubbles = tester
          .widgetList<NumberBubble>(find.byType(NumberBubble))
          .map((b) => b.state)
          .toList();
      expect(bubbles.first, NumberBubbleState.answered);
    });

    testWidgets('simulasi: posisi, jawaban, dan sisa waktu dari deadline',
        (tester) async {
      final sessions = FakeSessionRepository();
      final clock = FakeClock(appNow);
      final first = await openSession(
          tester, SessionMode.simulasi, simulasiPlan(),
          sessions: sessions, clock: clock);
      await tapOption(tester, 2);
      await tapButton(tester, 'Berikutnya');
      await first.tickSeconds(120);

      clock.advance(const Duration(minutes: 1));
      final app = await reopen(tester, sessions, clock);
      await app.go('/sesi/1');
      expect(find.text('Subtes 1 dari 3, soal 2 dari 3'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget,
          reason: '5:00 dikurangi 2 menit berjalan dan 1 menit tertutup');
      await app.session.goTo(0);
      await tester.pumpAndSettle();
      expect(selected(tester, 2), isTrue, reason: 'jawaban tersimpan kembali');
    });

    testWidgets('kedaluwarsa saat tertutup: subtes berikutnya dengan pesan',
        (tester) async {
      final sessions = FakeSessionRepository();
      final clock = FakeClock(appNow);
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          sessions: sessions, clock: clock);
      await tapOption(tester, 1);

      clock.advance(const Duration(minutes: 6));
      final app = await reopen(tester, sessions, clock);
      await app.go('/sesi/1');
      expect(find.text('Subtes 2 dari 3, soal 1 dari 2'), findsOneWidget);
      expect(find.textContaining('Waktu subtes Numerik habis'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget,
          reason: 'waktu tertutup hanya menghabiskan subtes yang berjalan');
      final answers = sessions.answersOf(1);
      expect(answers[0]!.opsiDipilih, 1);
      expect(answers[1]!.opsiDipilih, isNull);
    });

    testWidgets('kedaluwarsa di subtes terakhir: sesi selesai, S08',
        (tester) async {
      final sessions = FakeSessionRepository();
      final clock = FakeClock(appNow);
      final first = await openSession(
          tester, SessionMode.simulasi, simulasiPlan(),
          sessions: sessions, clock: clock);
      await first.tickSeconds(5 * 60 + 1);
      await first.tickSeconds(4 * 60 + 1);

      clock.advance(const Duration(minutes: 10));
      final app = await reopen(tester, sessions, clock);
      await app.go('/sesi/1');
      expect(app.location, '/hasil/1');
      expect(sessions.sessions[1]!.selesai, isNotNull);
    });

    testWidgets('dari beranda: baris Lanjutkan membuka sesi terakhir',
        (tester) async {
      final sessions = FakeSessionRepository();
      final clock = FakeClock(appNow);
      final first = await openSession(
          tester, SessionMode.latihan, latihanPlan(),
          sessions: sessions, clock: clock);
      final q = first.sessionState!.question!;
      await tapOption(tester, q.correctIndex);
      await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
      await tapButton(tester, 'Berikutnya');

      final app = await reopen(tester, sessions, clock);
      expect(app.location, '/');
      expect(find.text('Lanjutkan latihan'), findsOneWidget);
      expect(find.text('Soal 2 dari 3'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan latihan'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
      expect(find.text('Mode Latihan, soal 2 dari 3'), findsOneWidget);
    });
  });

  group('keluar dari sesi', () {
    testWidgets('Lanjutkan nanti menutup layar; sesi tetap bisa dilanjutkan',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      await tester.tap(find.bySemanticsLabel('Tutup sesi'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Jawabanmu sudah tersimpan. Kamu bisa '
            'melanjutkan sesi ini nanti dari beranda.'),
        findsOneWidget,
      );
      await tapButton(tester, 'Lanjutkan nanti');
      expect(app.location, '/');
      expect(app.sessions.sessions[1]!.selesai, isNull);
      expect(find.text('Lanjutkan latihan'), findsOneWidget,
          reason: 'beranda dihitung ulang sesudah kembali');
    });

    testWidgets('Tetap mengerjakan menutup konfirmasi', (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan());
      await tester.tap(find.bySemanticsLabel('Tutup sesi'));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Tetap mengerjakan');
      expect(find.textContaining('Jawabanmu sudah tersimpan'), findsNothing);
      expect(find.text('Buka petunjuk'), findsOneWidget);
    });

    testWidgets('Akhiri sesi: soal tersisa dilewati dan S08 terbuka',
        (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      final q = app.sessionState!.question!;
      await tapOption(tester, q.correctIndex);
      await tapButton(tester, 'Kirim jawaban ${letter(q.correctIndex)}');
      await tester.tap(find.bySemanticsLabel('Tutup sesi'));
      await tester.pumpAndSettle();
      await tapButton(tester, 'Akhiri sesi');
      expect(app.location, '/hasil/1');
      final s = app.sessions.sessions[1]!;
      expect(s.selesai, isNotNull);
      expect(s.skor, closeTo(100 / 3, 0.01));
      expect(app.sessions.answersOf(1).length, 3);
    });

    testWidgets(
        'tombol kembali sistem meminta konfirmasi, tidak langsung '
        'keluar', (tester) async {
      final app = await openSession(tester, SessionMode.latihan, latihanPlan());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
      expect(find.text('Lanjutkan nanti'), findsOneWidget);
    });

    testWidgets('sesi bertimer: konfirmasi menyebut waktu tetap berjalan',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan());
      await tester.tap(find.bySemanticsLabel('Tutup sesi'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Waktu subtes tetap berjalan'), findsOneWidget);
    });
  });

  group('kondisi', () {
    testWidgets('soal gagal dibuat: teks spek, Ulangi, dan lewati',
        (tester) async {
      var failing = true;
      final app = await openSession(
        tester,
        SessionMode.latihan,
        latihanPlan(),
        overrides: [
          questionBuilderProvider.overrideWithValue((item) {
            if (failing) throw StateError('generator gagal: SEED 41');
            return buildFromRegistry(item);
          }),
        ],
      );
      expect(find.text('Soal tidak bisa dibuat'), findsOneWidget);
      expect(find.text('Coba tipe lain atau ulangi sesi.'), findsOneWidget);
      expect(find.textContaining('SEED'), findsNothing);
      expect(find.byType(OptionTile), findsNothing);
      expect(find.text('Lewati soal'), findsOneWidget);

      await tapButton(tester, 'Ulangi');
      expect(find.text('Soal tidak bisa dibuat'), findsOneWidget,
          reason: 'masih gagal');

      failing = false;
      await tapButton(tester, 'Ulangi');
      expect(find.text('Soal tidak bisa dibuat'), findsNothing);
      expect(find.byType(OptionTile), findsWidgets);
      expect(app.sessionState!.questionFailed, isFalse);
    });

    testWidgets('Lewati soal pindah ke soal berikutnya', (tester) async {
      final app = await openSession(
        tester,
        SessionMode.latihan,
        latihanPlan(),
        overrides: [
          questionBuilderProvider.overrideWithValue((item) {
            if (item.seed == 40) throw StateError('gagal');
            return buildFromRegistry(item);
          }),
        ],
      );
      await tapButton(tester, 'Lewati soal');
      expect(find.text('Mode Latihan, soal 2 dari 3'), findsOneWidget);
      expect(app.sessionState!.questionFailed, isFalse);
    });

    testWidgets('sesi tidak ada: pesan dan jalan ke beranda', (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
      );
      await app.openSession(99);
      expect(find.text('Sesi tidak ditemukan'), findsOneWidget);
      await tester.tap(find.text('Ke beranda'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
    });

    testWidgets('sesi sudah selesai: dialihkan ke hasilnya', (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedSession(
        sessions,
        mode: SessionMode.latihan,
        plan: latihanPlan(),
        finished: true,
      );
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
      );
      await app.openSession(id);
      expect(app.location, '/hasil/$id');
    });

    testWidgets('membaca sesi gagal: sebab, Coba lagi, tanpa teks exception',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedSession(sessions,
          mode: SessionMode.latihan, plan: latihanPlan());
      sessions.failByIdWith = StateError('berkas rusak: SQLITE_CORRUPT');
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
      );
      await app.openSession(id);
      expect(find.text('Sesi tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);

      sessions.failByIdWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Mode Latihan, soal 1 dari 3'), findsOneWidget);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('latihan bergambar di 360 dp, teks ${(scale * 100).round()}%',
          (tester) async {
        final app = await openSession(
          tester,
          SessionMode.latihan,
          SessionPlan(items: [planItem(QuestionType.figMtx, 50, 'figural')]),
          textScale: scale,
        );
        final q = app.sessionState!.question!;
        await tapOption(tester, 0);
        await tapButton(tester, 'Kirim jawaban A');
        expect(find.text(q.explanation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('simulasi di 360 dp, teks ${(scale * 100).round()}%',
          (tester) async {
        await openSession(tester, SessionMode.simulasi, simulasiPlan(),
            textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(NumberBubble).at(2));
        await tester.pumpAndSettle();
        await tapButton(tester, 'Berikutnya');
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Tutup subtes Numerik?'), findsOneWidget);
      });
    }

    testWidgets('soal teks terpanjang (silogisme) terbaca penuh',
        (tester) async {
      final app = await openSession(
        tester,
        SessionMode.latihan,
        SessionPlan(items: [planItem(QuestionType.logSyl, 20, 'logika')]),
        textScale: 1.3,
      );
      final q = app.sessionState!.question!;
      expect(find.text(q.stem.text!), findsOneWidget);
      for (final o in q.options) {
        expect(find.text(o.content.text!), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('target sentuh minimal 48 dp di latihan dan simulasi',
        (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan());
      expectTouchTargets48(tester);
    });

    testWidgets('target sentuh minimal 48 dp di simulasi', (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan());
      expectTouchTargets48(tester);
    });

    testWidgets('semantik: tutup berlabel, soal dan timer terbaca',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openSession(tester, SessionMode.simulasi, simulasiPlan());
      expect(find.bySemanticsLabel('Tutup sesi'), findsOneWidget);
      expect(find.bySemanticsLabel('Sisa waktu 5 menit'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Soal 1, sedang dikerjakan')),
          findsOneWidget);
      handle.dispose();
    });
  });
}
