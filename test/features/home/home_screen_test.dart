import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

final nov5 = DateTime.utc(2026, 11, 5);

Future<AppHarness> openHome(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  FakeMistakeRepository? mistakes,
  FakeSessionRepository? sessions,
  List<Override> overrides = const [],
  double textScale = 1,
  DateTime? tanggal,
}) =>
    pumpApp(
      tester,
      profiles: profiles ??
          FakeProfileRepository([activeProfile(tanggalTes: tanggal)]),
      mistakes: mistakes,
      sessions: sessions,
      overrides: overrides,
      textScale: textScale,
    );

void main() {
  group('tampilan normal', () {
    testWidgets('profil, hitung mundur, panel latihan, dan pintasan',
        (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      expect(app.location, '/');
      expect(find.text('Halo'), findsOneWidget);
      expect(find.text('Profil aktif'), findsOneWidget);
      expect(find.text('QA, CCAT-style'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('hari lagi'), findsOneWidget);

      expect(find.text('Latihan hari ini'), findsOneWidget);
      expect(find.text('Sekitar 15 menit'), findsOneWidget);
      expect(find.text('Campuran sesuai bobot profil'), findsOneWidget);
      expect(find.text('21 soal'), findsOneWidget);
      expect(find.text('Mulai latihan hari ini'), findsOneWidget);

      for (final t in [
        'Katalog psikotes',
        'Pengetahuan role',
        'Capture soal',
        'Buku kesalahan',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('belum ada riwayat: kondisi kosong kelemahan dengan teks spek',
        (tester) async {
      await openHome(tester, tanggal: nov5);
      expect(find.text('Belum ada data kelemahan'), findsOneWidget);
      expect(
        find.text('Kerjakan diagnostik agar latihan hari ini bisa disusun.'),
        findsOneWidget,
      );
      expect(find.text('Mulai diagnostik'), findsOneWidget);
      expect(find.byType(ScoreBar), findsNothing);
      expect(find.text('Lihat semua di Statistik'), findsNothing,
          reason: 'statistik belum punya isi tanpa riwayat');
      // Panel latihan tetap ada dengan campuran sesuai bobot profil.
      expect(find.text('Mulai latihan hari ini'), findsOneWidget);
    });

    testWidgets('Mulai diagnostik membuka S03', (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      await tester.ensureVisible(find.text('Mulai diagnostik'));
      await tester.tap(find.text('Mulai diagnostik'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/diagnostik');
    });

    testWidgets('tiga tipe terlemah dengan nilai teks; terlemah bertanda',
        (tester) async {
      await openHome(
        tester,
        tanggal: nov5,
        overrides: [weaknessModelProvider.overrideWithValue(threeWeaknesses)],
      );
      final bars = tester.widgetList<ScoreBar>(find.byType(ScoreBar)).toList();
      expect(bars.map((b) => b.label),
          ['Matriks 3x3', 'Deret angka', 'Silogisme']);
      expect(bars.map((b) => b.valueLabel), ['35%', '52%', '60%']);
      expect(bars.map((b) => b.weakest), [true, false, false]);
      expect(find.text('Belum ada data kelemahan'), findsNothing);
    });

    testWidgets('tautan Statistik membuka tab Statistik', (tester) async {
      final app = await openHome(
        tester,
        tanggal: nov5,
        overrides: [weaknessModelProvider.overrideWithValue(threeWeaknesses)],
      );
      await tester.ensureVisible(find.text('Lihat semua di Statistik'));
      await tester.tap(find.text('Lihat semua di Statistik'));
      await tester.pumpAndSettle();
      expect(app.location, '/statistik');
    });
  });

  group('baris profil', () {
    testWidgets('tanpa tanggal tes: tautan ke S02 mode ubah', (tester) async {
      final app = await openHome(tester);
      expect(find.text('Tanggal tes belum diisi'), findsOneWidget);
      expect(find.text('hari lagi'), findsNothing);
      await tester.tap(find.text('Isi tanggal tes'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/profil?ubah=1');
      expect(find.text('Ubah profil'), findsOneWidget);
      expect(find.text('Simpan profil'), findsOneWidget);
    });

    testWidgets('tanggal tes hari ini', (tester) async {
      await openHome(tester, tanggal: DateTime.utc(2026, 10, 22));
      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Tanggal tes belum diisi'), findsNothing);
    });

    testWidgets('besok: satu hari lagi', (tester) async {
      await openHome(tester, tanggal: DateTime.utc(2026, 10, 23));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('hari lagi'), findsOneWidget);
    });

    testWidgets('tanggal tes sudah lewat: pesan dan tautan ubah',
        (tester) async {
      await openHome(tester, tanggal: DateTime.utc(2026, 10, 1));
      expect(find.text('Tanggal tes sudah lewat'), findsOneWidget);
      expect(find.text('Ubah tanggal tes'), findsOneWidget);
    });

    testWidgets('hitungan hari mengikuti jam palsu', (tester) async {
      final clock = FakeClock(DateTime.utc(2026, 11, 2, 8));
      await pumpApp(
        tester,
        clock: clock,
        profiles: FakeProfileRepository([activeProfile(tanggalTes: nov5)]),
      );
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('kartu buku kesalahan', () {
    testWidgets('hanya kartu aktif yang jatuh tempo dihitung', (tester) async {
      await openHome(
        tester,
        tanggal: nov5,
        mistakes: FakeMistakeRepository([
          card(1),
          card(2, offsetDays: 0),
          card(3, offsetDays: 2),
          card(4, status: CardStatus.dikuasai),
        ]),
      );
      expect(find.text('2 jatuh tempo'), findsOneWidget);
    });

    testWidgets('tanpa kartu jatuh tempo', (tester) async {
      await openHome(tester, tanggal: nov5);
      expect(find.text('Tidak ada kartu jatuh tempo'), findsOneWidget);
    });
  });

  group('kondisi memuat dan galat', () {
    testWidgets('memuat: skeleton berbentuk konten, bukan spinner',
        (tester) async {
      final repo = FakeProfileRepository([activeProfile(tanggalTes: nov5)])
        ..watchGate = Completer<void>();
      final app = await pumpApp(tester, profiles: repo);
      expect(app.location, '/');
      expect(find.byType(SkeletonList), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Latihan hari ini'), findsNothing);
      expect(find.text('Halo'), findsOneWidget, reason: 'kepala tetap ada');

      repo.watchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Latihan hari ini'), findsOneWidget);
    });

    testWidgets('galat: sebab dan Coba lagi, tanpa teks exception',
        (tester) async {
      final planner = FlakyPlanner(emptyHistoryPlanner({
        QuestionType.numSeq,
      }));
      await openHome(
        tester,
        tanggal: nov5,
        overrides: [dailyPlannerProvider.overrideWithValue(planner)],
      );
      expect(find.text('Rencana latihan tidak bisa disusun'), findsOneWidget);
      expect(find.textContaining('Data profil gagal dibaca'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.text('Mulai latihan hari ini'), findsNothing);

      planner.failing = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Rencana latihan tidak bisa disusun'), findsNothing);
      expect(find.text('Mulai latihan hari ini'), findsOneWidget);
    });

    testWidgets('kartu gagal dibaca: galat yang sama', (tester) async {
      final mistakes = FakeMistakeRepository()..failWith = StateError('io');
      await openHome(tester, tanggal: nov5, mistakes: mistakes);
      expect(find.text('Rencana latihan tidak bisa disusun'), findsOneWidget);
    });

    testWidgets(
        'tanpa soal tersedia untuk subtes profil: pesan dan Ubah profil',
        (tester) async {
      final app = await openHome(
        tester,
        tanggal: nov5,
        overrides: [availableTypesProvider.overrideWithValue(<QuestionType>{})],
      );
      expect(find.textContaining('belum tersedia'), findsOneWidget);
      expect(find.text('Mulai latihan hari ini'), findsNothing);
      expect(find.text('Sekitar 15 menit'), findsNothing);
      await tester.tap(find.text('Ubah profil'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/profil?ubah=1');
    });
  });

  group('memulai latihan', () {
    testWidgets('satu ketukan membuat sesi latihan dan membuka layar sesi',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openHome(tester, tanggal: nov5, sessions: sessions);
      await tester.tap(find.text('Mulai latihan hari ini'));
      await tester.pumpAndSettle();

      expect(app.location, '/sesi/1');
      expect(find.text('Mode Latihan, soal 1 dari 21'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing,
          reason: 'sesi layar penuh tanpa bottom nav');
      final s = sessions.sessions[1]!;
      expect(s.mode, SessionMode.latihan);
      expect(s.profileId, 1);
      expect(s.plan.items.length, 21);
      expect(s.plan.subtes, isEmpty, reason: 'latihan tanpa timer');
      expect(s.deadline, isNull);
      expect(s.mulai, appNow);
    });

    testWidgets('kembali dari sesi ke beranda', (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      await tester.tap(find.text('Mulai latihan hari ini'));
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/');
      expect(find.text('Latihan hari ini'), findsOneWidget);
    });

    testWidgets('gagal menulis: pesan tanpa exception, tetap di beranda',
        (tester) async {
      final sessions = FakeSessionRepository()
        ..failStartWith = StateError('disk penuh');
      final app = await openHome(tester, tanggal: nov5, sessions: sessions);
      await tester.tap(find.text('Mulai latihan hari ini'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
      expect(find.textContaining('Sesi belum dimulai'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);

      sessions.failStartWith = null;
      await tester.tap(find.text('Mulai latihan hari ini'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
    });
  });

  group('pintasan dan navigasi', () {
    testWidgets('Katalog psikotes membuka tab Psikotes', (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      await tester.tap(find.text('Katalog psikotes'));
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(find.text('Simulasi penuh'), findsOneWidget);
    });

    testWidgets('Capture soal dan Buku kesalahan', (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      await tester.ensureVisible(find.text('Capture soal'));
      await tester.tap(find.text('Capture soal'));
      await tester.pumpAndSettle();
      expect(app.location, '/capture');
      app.router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buku kesalahan'));
      await tester.tap(find.text('Buku kesalahan'));
      await tester.pumpAndSettle();
      expect(app.location, '/buku-kesalahan');
    });

    testWidgets('Pengetahuan role nonaktif dengan alasan', (tester) async {
      await openHome(tester, tanggal: nov5);
      final row = tester
          .widget<ListRow>(find.widgetWithText(ListRow, 'Pengetahuan role'));
      expect(row.onTap, isNull);
      expect(find.text('Tersedia di v1.1'), findsOneWidget);
    });

    testWidgets('ikon Pengaturan berlabel dan membuka S18', (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      expect(find.byTooltip('Pengaturan'), findsOneWidget);
      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();
      expect(app.location, '/pengaturan');
    });

    testWidgets('bottom nav: Beranda aktif, pindah ke Psikotes',
        (tester) async {
      final app = await openHome(tester, tanggal: nov5);
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 0);
      await tester.tap(find.text('Psikotes').last);
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        1,
      );
    });
  });

  group('tata letak dan aksesibilitas', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('tanpa meluap di 360 dp, skala teks $scale', (tester) async {
        await openHome(
          tester,
          tanggal: nov5,
          textScale: scale,
          overrides: [weaknessModelProvider.overrideWithValue(threeWeaknesses)],
          profiles: FakeProfileRepository([
            activeProfile(
              nama: 'Mobile Dev, Psikotes Bank-style untuk perusahaan target',
              tanggalTes: nov5,
            ),
          ]),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -3000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('profil tanpa tanggal di skala 2,0 tidak meluap',
        (tester) async {
      await openHome(tester, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semua area ketuk minimal 48 x 48', (tester) async {
      await openHome(
        tester,
        tanggal: nov5,
        overrides: [weaknessModelProvider.overrideWithValue(threeWeaknesses)],
      );
      for (final i in tester.widgetList<InkWell>(find.byType(InkWell))) {
        if (i.onTap == null) continue;
        final size = tester.getSize(find.byWidget(i));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$i');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$i');
      }
    });

    testWidgets('nilai kelemahan dibaca sebagai teks oleh pembaca layar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openHome(
        tester,
        tanggal: nov5,
        overrides: [weaknessModelProvider.overrideWithValue(threeWeaknesses)],
      );
      expect(
        find.bySemanticsLabel('Matriks 3x3: 35%, kelemahan terbesar'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('14 hari lagi'), findsOneWidget);
      handle.dispose();
    });
  });
}
