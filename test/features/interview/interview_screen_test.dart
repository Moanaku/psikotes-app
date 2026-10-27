import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/ai/ai_coach.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/choice_row.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';
import 'package:simulator_psikotes_it/features/interview/interview_providers.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fake_settings.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../../support/text_fit.dart';

Future<AppHarness> openS15(
  WidgetTester tester, {
  bool key = true,
  int used = 0,
  bool online = true,
  FakeCoach? coach,
  double textScale = 1,
}) async {
  final secrets = MemorySecretStore();
  if (key) await secrets.write(AiProvider.gemini.secretName, 'rahasia');
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    textScale: textScale,
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        FakeSettingsRepository({'penyedia_ai': 'gemini'}),
      ),
      secretStoreProvider.overrideWithValue(secrets),
      interviewSessionsUsedProvider.overrideWithValue(used),
      interviewOnlineProvider.overrideWithValue(online),
      aiCoachProvider.overrideWithValue(coach ?? FakeCoach()),
    ],
  );
  await app.go(Routes.wawancara);
  return app;
}

Finder button(String label) => find.widgetWithText(AppButton, label);

Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tap(tester, find.byTooltip('Kirim jawaban'));
}

void main() {
  group('S15 setup', () {
    testWidgets('siap: pilihan, CV, lowongan, bahasa, mode, bottom nav',
        (tester) async {
      await openS15(tester);
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text('Wawancara berbasis CV'), findsOneWidget);
      expect(find.text('Data contoh'), findsOneWidget);
      expect(find.text('Sisa 3 / 3 hari ini'), findsOneWidget);
      expect(find.byType(ChoiceRow), findsNWidgets(2));
      expect(find.text('Deskripsi lowongan'), findsOneWidget);
      for (final t in [
        'Indonesia',
        'English',
        'Campuran',
        'Latihan',
        'Simulasi'
      ]) {
        expect(find.widgetWithText(AppChip, t), findsOneWidget, reason: t);
      }
      expect(button('Mulai wawancara'), findsOneWidget);
      expect(find.textContaining('belum ada AI yang menjawab'), findsOneWidget);
    });

    testWidgets('tanpa key: pesan dan tombol ke Pengaturan', (tester) async {
      final app = await openS15(tester, key: false);
      expect(find.text('Wawancara butuh API key Gemini atau Groq milikmu.'),
          findsOneWidget);
      expect(button('Pakai kartu template'), findsOneWidget);
      await tap(tester, button('Isi key di Pengaturan'));
      expect(app.location, '/pengaturan');
    });

    testWidgets('batas harian habis', (tester) async {
      await openS15(tester, used: 3);
      expect(find.textContaining('Batas 3 sesi hari ini sudah terpakai'),
          findsOneWidget);
      expect(find.text('Sisa 0 / 3 hari ini'), findsOneWidget);
      expect(button('Pakai kartu template'), findsOneWidget);
      expect(button('Mulai wawancara'), findsNothing);
    });

    testWidgets('offline: tampilan khusus dengan yang tetap jalan',
        (tester) async {
      final app = await openS15(tester, online: false);
      expect(find.text('Tidak ada internet'), findsOneWidget);
      expect(find.textContaining('Psikotes tetap jalan seperti biasa'),
          findsOneWidget);
      await tap(tester, button('Pakai kartu template'));
      expect(app.location, startsWith('/wawancara/'));
    });

    testWidgets('memuat: skeleton, bukan spinner', (tester) async {
      final settings = FakeSettingsRepository({'penyedia_ai': 'gemini'})
        ..gate = Completer<void>();
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
        ],
      );
      unawaited(app.router.push(Routes.wawancara));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Wawancara berbasis CV'), findsWidgets);
    });

    testWidgets('galat membaca: Coba lagi tanpa teks exception',
        (tester) async {
      final settings = FakeSettingsRepository()..failWith = StateError('io');
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
        ],
      );
      await app.go(Routes.wawancara);
      expect(find.text('Pengaturan wawancara tidak terbaca'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('pilihan pewawancara, bahasa, dan mode tersimpan',
        (tester) async {
      final app = await openS15(tester);
      await tap(tester, find.widgetWithText(ChoiceRow, 'User teknis'));
      await tap(tester, find.widgetWithText(AppChip, 'Simulasi'));
      final s = app.container.read(interviewSetupProvider);
      expect(s.persona, InterviewPersona.teknis);
      expect(s.mode, InterviewMode.simulasi);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('skala $scale: tanpa meluap, kata utuh, sentuh 48 dp',
          (tester) async {
        await openS15(tester, key: false, textScale: scale);
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        expectTouchTargets48(tester);
      });
    }
  });

  group('S16 dialog dan S17 laporan', () {
    Future<AppHarness> startDialog(WidgetTester tester,
        {FakeCoach? coach, double scale = 1}) async {
      final app = await openS15(tester, coach: coach, textScale: scale);
      await tap(tester, button('Mulai wawancara'));
      return app;
    }

    testWidgets('pembuka, penanda Data contoh, tombol suara nonaktif',
        (tester) async {
      final app = await startDialog(tester);
      expect(app.location, '/wawancara/1');
      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.text('Wawancara HR'), findsOneWidget);
      expect(find.text('Data contoh'), findsOneWidget);
      expect(find.text('Topik 1 dari 7, mode Latihan'), findsOneWidget);
      expect(find.textContaining('Flutter developer'), findsOneWidget);
      expect(find.textContaining('Petunjuk (hanya di mode Latihan)'),
          findsOneWidget);
      final mic = find.byTooltip('Jawab dengan suara, tersedia di v1.3');
      expect(mic, findsOneWidget);
    });

    testWidgets('kirim jawaban memajukan topik sampai penutup', (tester) async {
      final app = await startDialog(tester);
      for (var i = 1; i <= 7; i++) {
        await send(tester, 'Jawaban saya nomor $i');
      }
      expect(find.textContaining('itu pertanyaan terakhir'), findsOneWidget);
      expect(find.text('Topik 7 dari 7, mode Latihan'), findsOneWidget);
      expect(find.byTooltip('Kirim jawaban'), findsNothing);
      expect(button('Lihat laporan'), findsOneWidget);
      expect(app.container.read(interviewDialogProvider).turns, hasLength(15));
    });

    testWidgets('mode Simulasi tanpa petunjuk', (tester) async {
      final app = await openS15(tester);
      await tap(tester, find.widgetWithText(AppChip, 'Simulasi'));
      await tap(tester, button('Mulai wawancara'));
      expect(app.location, startsWith('/wawancara/'));
      expect(find.textContaining('Petunjuk'), findsNothing);
    });

    testWidgets('galat kirim: jawaban tersimpan, Kirim ulang berhasil',
        (tester) async {
      final coach = FakeCoach()..failNext = const CoachUnavailable('x');
      await startDialog(tester, coach: coach);
      await send(tester, 'Jawaban pertama');
      expect(find.text('Jawaban pertama'), findsOneWidget);
      expect(
          find.text('Pewawancara tidak menjawab. Jawabanmu tersimpan. Coba '
              'kirim lagi.'),
          findsOneWidget);
      expect(find.textContaining('CoachUnavailable'), findsNothing);
      await tap(tester, button('Kirim ulang'));
      expect(find.textContaining('Pewawancara tidak menjawab'), findsNothing);
      expect(find.text('Jawaban pertama'), findsOneWidget);
      expect(find.textContaining('Halaman apa saja'), findsOneWidget);
    });

    testWidgets('Akhiri membuka laporan contoh dengan transkrip',
        (tester) async {
      final app = await startDialog(tester);
      await send(tester, 'Saya membuat halaman pemesanan');
      await tap(tester, button('Akhiri'));
      expect(app.location, '/wawancara/1/laporan');
      expect(find.text('Data contoh'), findsOneWidget);
      expect(find.text('Laporan wawancara hr'), findsOneWidget);
      expect(tester.widgetList<ScoreBar>(find.byType(ScoreBar)), hasLength(4));
      expect(find.text('Goyah'), findsNWidgets(2));
      expect(find.text('Kuat'), findsOneWidget);
      expect(find.textContaining('Contoh ini belum menambah kartu'),
          findsOneWidget);
      await tap(tester, button('Lihat transkrip'));
      expect(find.text('Saya membuat halaman pemesanan'), findsOneWidget);
      await tap(tester, button('Selesai'));
      expect(app.location, '/');
    });

    testWidgets('laporan tanpa dialog: kondisi kosong', (tester) async {
      final app = await openS15(tester);
      await app.go('/wawancara/1/laporan');
      expect(find.text('Belum ada wawancara'), findsOneWidget);
    });

    testWidgets('laporan gagal dibuat: Coba lagi', (tester) async {
      final coach = FakeCoach()..failReport = const CoachUnavailable('x');
      final app = await startDialog(tester, coach: coach);
      await tap(tester, button('Akhiri'));
      expect(app.location, '/wawancara/1/laporan');
      expect(find.text('Laporan tidak bisa dibuat'), findsOneWidget);
      await tap(tester, find.text('Coba lagi'));
      expect(find.text('Peta klaim CV'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('skala $scale: S16 dan S17 tanpa meluap', (tester) async {
        await startDialog(tester, scale: scale);
        await send(tester, 'Jawaban saya yang cukup panjang untuk diuji');
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        expectTouchTargets48(tester);
        await tap(tester, button('Akhiri'));
        expect(tester.takeException(), isNull);
        expectNoMidWordBreaks(tester);
        await tester.drag(
            find.byType(SingleChildScrollView).last, const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expectTouchTargets48(tester);
      });
    }
  });
}
