import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/error_view.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/segmented_control.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/core/widgets/stat_row.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/features/stats/stats_provider.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

class FakeCsvSharer implements CsvSharer {
  final List<({String fileName, String content})> shared = [];
  Object? failWith;

  @override
  Future<void> share(
      {required String fileName, required String content}) async {
    if (failWith != null) throw failWith!;
    shared.add((fileName: fileName, content: content));
  }
}

/// Simulasi selesai [daysAgo] hari lalu dengan jawaban benar menurut [correct].
Future<int> finished(
  FakeSessionRepository repo,
  int daysAgo, {
  SessionMode mode = SessionMode.simulasi,
  bool Function(int)? correct,
}) =>
    seedSession(
      repo,
      mode: mode,
      plan: latihanPlan(),
      finished: true,
      mulai: appNow.subtract(Duration(days: daysAgo)),
      correct: correct,
    );

Future<AppHarness> openStats(
  WidgetTester tester,
  FakeSessionRepository sessions, {
  FakeCsvSharer? sharer,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: FakeProfileRepository([activeProfile()]),
    sessions: sessions,
    textScale: textScale,
    overrides: [
      if (sharer != null) csvSharerProvider.overrideWithValue(sharer),
    ],
  );
  await app.go(Routes.statistik);
  return app;
}

void main() {
  group('tampilan normal', () {
    testWidgets('tiga angka, grafik dua titik, per kategori, ekspor, dan nav',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 7, correct: (i) => i == 0); // minggu lalu, 33%
      await finished(repo, 1); // minggu ini, 100%
      await finished(repo, 0, mode: SessionMode.latihan, correct: (i) => i < 2);
      await openStats(tester, repo);

      expect(find.text('Statistik'), findsWidgets);
      expect(find.byType(SegmentedControl), findsOneWidget);
      final row = tester.widget<StatRow>(find.byType(StatRow));
      // Minggu ini: sesi 1 hari lalu dan latihan hari ini, 3 jawaban 30 dtk.
      expect(row.items.map((i) => i.label),
          ['menit minggu ini', 'sesi selesai', 'hari beruntun']);
      expect(row.items[0].value, '3'); // 180 detik
      expect(row.items[1].value, '2');
      expect(row.items[2].value, '2', reason: 'hari ini dan kemarin');

      expect(find.text('Skor simulasi per minggu'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Terakhir 100%, naik 67 poin dari minggu sebelumnya.'),
          findsOneWidget);
      expect(find.textContaining('Butuh minimal'), findsNothing);

      expect(find.text('Per kategori'), findsOneWidget);
      expect(find.byType(ScoreBar), findsWidgets);
      expect(find.textContaining('Numerik, median'), findsOneWidget);
      expect(find.text('Ekspor CSV untuk laporan hasil'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('segmen Bulanan mengganti periode dan judul', (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 20); // 2 Oktober
      await finished(repo, 1);
      await openStats(tester, repo);
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();
      expect(find.text('Skor simulasi per bulan'), findsOneWidget);
      expect(find.text('menit bulan ini'), findsOneWidget);
      final row = tester.widget<StatRow>(find.byType(StatRow));
      expect(row.items[1].value, '2');
      expect(find.text('Terakhir 100%, sama dengan bulan sebelumnya.'),
          findsNothing,
          reason: 'keduanya di bulan yang sama: satu titik');
      expect(find.textContaining('Butuh simulasi di minimal dua bulan'),
          findsOneWidget);
    });

    testWidgets('tab Statistik aktif di bottom nav', (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1);
      final app = await openStats(tester, repo);
      expect(app.location, Routes.statistik);
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 3);
    });
  });

  group('kondisi', () {
    testWidgets('kosong: teks spek, tombol Mulai latihan, tanpa kontrol',
        (tester) async {
      final app = await openStats(tester, FakeSessionRepository());
      expect(find.text('Belum ada sesi'), findsOneWidget);
      expect(find.text('Statistik muncul setelah sesi pertama selesai.'),
          findsOneWidget);
      expect(find.byType(SegmentedControl), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Ekspor CSV untuk laporan hasil'), findsNothing);
      await tester.tap(find.text('Mulai latihan'));
      await tester.pumpAndSettle();
      expect(app.location, Routes.psikotes);
    });

    testWidgets('grafik dengan satu titik: titik tunggal dan teks spek',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1, correct: (i) => i < 2);
      await openStats(tester, repo);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Terakhir 67%.'), findsOneWidget);
      expect(find.text('Butuh minimal dua simulasi untuk melihat tren.'),
          findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dua simulasi di satu minggu: teks tidak menyesatkan',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1);
      await finished(repo, 2);
      await openStats(tester, repo);
      expect(
          find.text('Butuh simulasi di minimal dua minggu untuk melihat tren.'),
          findsOneWidget);
    });

    testWidgets('ada sesi tetapi belum ada simulasi: catatan, bukan grafik',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1, mode: SessionMode.latihan);
      await openStats(tester, repo);
      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Belum ada simulasi di rentang ini'),
          findsOneWidget);
      expect(find.byType(StatRow), findsOneWidget);
      expect(find.byType(ScoreBar), findsWidgets);
    });

    testWidgets('memuat: skeleton untuk angka, grafik, dan kategori',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1);
      repo.finishedGate = Completer<void>();
      await openStats(tester, repo);
      expect(find.bySemanticsLabel('Memuat statistik'), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      repo.finishedGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('galat: sebab tanpa exception, Coba lagi memulihkan',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1);
      repo.failFinishedWith = StateError('SQLITE_CORRUPT: tabel session');
      await openStats(tester, repo);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Statistik tidak bisa dibuka'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      repo.failFinishedWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(StatRow), findsOneWidget);
    });
  });

  group('ekspor CSV', () {
    testWidgets('membagikan berkas CSV dengan kolom spek dan nama bertanggal',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1, correct: (i) => i == 0);
      final sharer = FakeCsvSharer();
      await openStats(tester, repo, sharer: sharer);
      await tester.tap(find.text('Ekspor CSV untuk laporan hasil'));
      await tester.pumpAndSettle();
      expect(sharer.shared, hasLength(1));
      expect(
          sharer.shared.single.fileName, 'statistik-psikotes-2026-10-22.csv');
      final lines = sharer.shared.single.content.split('\r\n');
      expect(lines.first, 'tanggal,mode,skor,kategori,akurasi,median detik');
      expect(lines.where((l) => l.isNotEmpty), hasLength(3));
      expect(lines[1], startsWith('2026-10-21,simulasi,33.3,figural,'));
      expect(find.textContaining('belum dibagikan'), findsNothing);
    });

    testWidgets('gagal: pesan tanpa exception dan bisa diulang',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 1);
      final sharer = FakeCsvSharer()
        ..failWith = StateError('tidak ada aplikasi');
      await openStats(tester, repo, sharer: sharer);
      await tester.tap(find.text('Ekspor CSV untuk laporan hasil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Berkas CSV belum dibagikan'), findsOneWidget);
      expect(find.textContaining('tidak ada aplikasi'), findsNothing);

      sharer.failWith = null;
      await tester.tap(find.text('Ekspor CSV untuk laporan hasil'));
      await tester.pumpAndSettle();
      expect(sharer.shared, hasLength(1));
      expect(find.textContaining('Berkas CSV belum dibagikan'), findsNothing);
    });
  });

  group('aksesibilitas dan teks panjang', () {
    testWidgets('grafik punya label semantik berisi semua nilai; target 48 dp',
        (tester) async {
      final repo = FakeSessionRepository();
      await finished(repo, 7, correct: (i) => i == 0);
      await finished(repo, 1);
      await openStats(tester, repo);
      expect(
        find.bySemanticsLabel(
            RegExp(r'Grafik skor simulasi: 12/10 33 persen, 19/10 100 persen')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.widgetWithText(
                AppButton, 'Ekspor CSV untuk laporan hasil'))
            .height,
        greaterThanOrEqualTo(48),
      );
      for (final seg in ['Mingguan', 'Bulanan']) {
        expect(
            tester
                .getSize(find
                    .ancestor(
                        of: find.text(seg), matching: find.byType(InkWell))
                    .first)
                .height,
            greaterThanOrEqualTo(48));
      }
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('360 dp, skala teks $scale: tanpa overflow', (tester) async {
        final repo = FakeSessionRepository();
        await finished(repo, 7, correct: (i) => i == 0);
        await finished(repo, 1);
        await finished(repo, 0, mode: SessionMode.latihan);
        await openStats(tester, repo, textScale: scale);
        await tester.scrollUntilVisible(
          find.text('Ekspor CSV untuk laporan hasil'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
