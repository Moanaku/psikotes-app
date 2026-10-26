import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/quadrant_grid.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/review/result_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'review_test_support.dart';

Future<AppHarness> openResult(
  WidgetTester tester,
  FakeSessionRepository sessions,
  int id, {
  FakeProfileRepository? profiles,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: profiles ?? FakeProfileRepository([activeProfile()]),
    sessions: sessions,
    textScale: textScale,
  );
  await app.go('/hasil/$id');
  return app;
}

const mixed = [
  Outcome.benarCepat,
  Outcome.salahCepat,
  Outcome.benarLambat,
  Outcome.dilewati,
];

void main() {
  group('tampilan', () {
    testWidgets('skor, profil, mode, durasi, per kategori, dan kuadran',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);

      expect(find.text('Hasil sesi'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('QA, CCAT-style'), findsOneWidget);
      expect(find.text('Latihan'), findsOneWidget);
      // 30 + 5 + 90 + 20 detik.
      expect(find.text('Belum ada sesi latihan sebelumnya, durasi 02:25'),
          findsOneWidget);

      final bars = tester.widgetList<ScoreBar>(find.byType(ScoreBar)).toList();
      expect(bars.map((b) => b.valueLabel), ['33%', '100%']);
      expect(bars[0].label, startsWith('Numerik, median'));
      expect(bars[0].weakest, isTrue);
      expect(bars[1].weakest, isFalse);
    });

    testWidgets('empat hitungan kecepatan berupa baris dan menjumlah ke total',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);

      expect(find.byType(QuadrantGrid), findsNothing,
          reason: 'bukan kisi 2x2 kotak seragam');
      final titles = [
        'Benar dan cepat',
        'Benar tapi lambat',
        'Salah dan cepat',
        'Salah dan lambat',
      ];
      var total = 0;
      for (final t in titles) {
        final row = find.widgetWithText(ListRow, t);
        expect(row, findsOneWidget, reason: t);
        final count = tester.widget<ListRow>(row).trailing! as Text;
        total += int.parse(count.data!);
      }
      expect(total, 4);
      expect(find.text('Terburu-buru'), findsOneWidget);
      expect(find.text('Belum paham pola'), findsOneWidget);
      // Satu angka skor dominan: hanya skor yang berukuran display.
      final display = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.fontSize == 36);
      expect(display, hasLength(1));
    });

    testWidgets('jumlah soal salah masuk buku kesalahan dan soal dilewati',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);
      expect(
        find.text('1 soal salah masuk buku kesalahan dan dijadwalkan ulang '
            'besok.'),
        findsOneWidget,
        reason: 'soal tanpa jawaban tidak membuat kartu',
      );
      expect(
        find.text('Tidak dijawab: 1 soal. Dihitung salah pada skor, tidak '
            'masuk buku kesalahan.'),
        findsOneWidget,
      );
    });

    testWidgets('semua benar: tanpa kartu baru dan pembahasan mulai soal 1',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions,
          [Outcome.benarCepat, Outcome.benarCepat, Outcome.benarCepat]);
      final app = await openResult(tester, sessions, id);
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Tidak ada soal salah. Buku kesalahan tidak berubah.'),
          findsOneWidget);
      expect(find.textContaining('tidak dijawab'), findsNothing);
      await tester.tap(find.text('Lihat pembahasan'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/1/soal/1');
    });

    testWidgets('sesi lalu dengan mode dan profil yang sama dibandingkan',
        (tester) async {
      final sessions = FakeSessionRepository();
      await seedFinished(
        sessions,
        [Outcome.benarCepat, Outcome.benarCepat],
        mulai: appNow.subtract(const Duration(days: 2)),
      );
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);
      expect(find.text('Sesi lalu 100%, durasi 02:25'), findsOneWidget);
    });

    testWidgets('Lihat pembahasan membuka soal salah pertama; Beranda ke S04',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      final app = await openResult(tester, sessions, id);
      await tester.tap(find.text('Lihat pembahasan'));
      await tester.pumpAndSettle();
      expect(app.location, '/hasil/1/soal/2');

      await app.go('/hasil/1');
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
    });
  });

  group('kondisi', () {
    testWidgets('memuat: skeleton, bukan spinner', (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      final gated = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await openResult(tester, sessions, id, profiles: gated);
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      gated.watchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('galat: sebab dan Coba lagi tanpa teks exception',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      sessions.failByIdWith = StateError('rusak: SQLITE_CORRUPT');
      await openResult(tester, sessions, id);
      expect(find.text('Hasil sesi tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      sessions.failByIdWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('sesi tidak ada', (tester) async {
      final app = await openResult(tester, FakeSessionRepository(), 99);
      expect(find.text('Hasil sesi tidak ditemukan'), findsOneWidget);
      await tester.tap(find.text('Ke beranda'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
    });

    testWidgets('sesi belum selesai: arahkan melanjutkan', (tester) async {
      final sessions = FakeSessionRepository();
      final id =
          await seedFinished(sessions, [Outcome.benarCepat], finished: false);
      final app = await openResult(tester, sessions, id);
      expect(find.text('Sesi belum selesai'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan sesi'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/$id');
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('360 dp, teks ${(scale * 100).round()}%', (tester) async {
        final sessions = FakeSessionRepository();
        final id = await seedFinished(sessions, mixed);
        await openResult(tester, sessions, id, textScale: scale);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);
      expectTouchTargets48(tester);
    });

    testWidgets('tema gelap memakai token gelap', (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await pumpScreen(
        tester,
        ResultScreen(sessionId: id),
        brightness: Brightness.dark,
        overrides: [
          profileRepositoryProvider
              .overrideWithValue(FakeProfileRepository([activeProfile()])),
          sessionRepositoryProvider.overrideWithValue(sessions),
          answerRepositoryProvider.overrideWithValue(sessions),
          captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
          mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('50%')).style?.color,
          AppColors.dark.ink);
      expect(tester.widget<Text>(find.text('Per kategori')).style?.color,
          AppColors.dark.ink);
    });

    testWidgets('semantik: skor dibaca sebagai persen', (tester) async {
      final handle = tester.ensureSemantics();
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, mixed);
      await openResult(tester, sessions, id);
      expect(find.bySemanticsLabel('Skor 50 persen'), findsOneWidget);
      handle.dispose();
    });
  });

  test('nama mode', () {
    expect(modeName(SessionMode.simulasi), 'Simulasi');
  });
}
