import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/segmented_control.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/catalog.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';
import 'package:simulator_psikotes_it/features/catalog/catalog_entries.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

Future<AppHarness> openCatalog(
  WidgetTester tester, {
  FakeProfileRepository? profiles,
  FakeCaptureRepository? captures,
  FakeSessionRepository? sessions,
  List<Override> overrides = const [],
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    profiles: profiles ?? FakeProfileRepository([activeProfile()]),
    captures: captures,
    sessions: sessions,
    overrides: overrides,
    textScale: textScale,
  );
  await app.go('/psikotes');
  return app;
}

ListRow row(WidgetTester tester, String title) =>
    tester.widget<ListRow>(find.widgetWithText(ListRow, title));

Future<void> show(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

ProfileBlueprint only(String kategori, {int jumlah = 10, int menit = 5}) =>
    ProfileBlueprint(
      subtes: [
        SubtestSpec(
          kategori: kategori,
          aktif: true,
          jumlah: jumlah,
          menit: menit,
        ),
      ],
      bobot: {kategori: 1.0},
    );

void main() {
  group('katalog latihan', () {
    testWidgets('judul, segmen, tujuh kelompok, dan bottom nav Psikotes',
        (tester) async {
      await openCatalog(tester);
      expect(find.text('Psikotes'), findsWidgets);
      final seg =
          tester.widget<SegmentedControl>(find.byType(SegmentedControl));
      expect(seg.options, ['Latihan', 'Simulasi']);
      expect(seg.selectedIndex, 0);
      for (final t in [
        'Numerik dan logika',
        'Figural',
        'Verbal',
        'Ketelitian dan kepribadian',
        'Modul IT',
        'Pengetahuan role',
        'Bank pribadi',
      ]) {
        await show(tester, t);
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        1,
      );
    });

    testWidgets('tipe yang terdaftar di registry bisa dibuka', (tester) async {
      await openCatalog(tester);
      for (final t in GeneratorRegistry.types) {
        final name = questionTypeName(t);
        await show(tester, name);
        expect(row(tester, name).onTap, isNotNull, reason: name);
      }
    });

    testWidgets('tipe belum rilis nonaktif dengan alasan dan tag',
        (tester) async {
      await openCatalog(tester);
      for (final name in [
        'Bacaan',
        'Kraepelin / Pauli',
        'Papi-style',
        'DISC-style',
        'Pseudocode',
        'Flowchart',
        'Excel',
      ]) {
        await show(tester, name);
        final r = row(tester, name);
        expect(r.onTap, isNull, reason: name);
        expect(r.subtitle, 'Tersedia di v1.1', reason: name);
      }
      for (final name in ['QA Engineer', 'Mobile Dev', 'IT BA', 'Umum']) {
        await show(tester, name);
        expect(row(tester, name).onTap, isNull, reason: name);
        expect(row(tester, name).subtitle, 'Tersedia di v1.1');
      }
    });

    testWidgets('verbal v1 belum ada bank: nonaktif, alasan, tag Segera',
        (tester) async {
      await openCatalog(tester);
      for (final name in ['Sinonim / antonim', 'Analogi']) {
        await show(tester, name);
        final r = row(tester, name);
        expect(r.onTap, isNull);
        expect(r.subtitle, 'Bank soal sedang disiapkan');
      }
    });

    testWidgets('ketersediaan mengikuti provider tipe yang tersedia',
        (tester) async {
      await openCatalog(
        tester,
        overrides: [
          availableTypesProvider.overrideWithValue({QuestionType.numSeq}),
        ],
      );
      expect(row(tester, 'Deret angka').onTap, isNotNull);
      expect(row(tester, 'Hitungan cepat').onTap, isNull);
      expect(
          row(tester, 'Hitungan cepat').subtitle, 'Bank soal sedang disiapkan');
    });

    testWidgets('semua tipe engine muncul tepat satu kali di katalog',
        (tester) async {
      final types = [
        for (final g in catalogGroups)
          for (final e in g.entries)
            if (e.type != null) e.type!,
      ];
      expect(types.toSet(), QuestionType.values.toSet());
      expect(types.length, QuestionType.values.length);
    });

    testWidgets('tipe yang terdaftar selalu dianggap tersedia', (tester) async {
      final reg = GeneratorRegistry.types.toSet();
      for (final g in catalogGroups) {
        for (final e in g.entries) {
          final why = CatalogAvailability.of(e, reg);
          expect(why == null, e.type != null && reg.contains(e.type),
              reason: e.label);
        }
      }
    });
  });

  group('memulai latihan satu tipe', () {
    testWidgets('membuat sesi latihan 10 soal medium dan membuka S06',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openCatalog(tester, sessions: sessions);
      await tester.tap(find.text('Matriks 3x3'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
      expect(find.byType(AppBottomNav), findsNothing);
      final s = sessions.sessions[1]!;
      expect(s.mode, SessionMode.latihan);
      expect(s.plan.items.length, 10);
      expect(s.plan.items.every((i) => i.type == QuestionType.figMtx), isTrue);
      expect(
          s.plan.items.every((i) => i.difficulty == Difficulty.medium), isTrue);
      expect(s.plan.subtes, isEmpty);
      expect(s.deadline, isNull);
    });

    testWidgets('soal yang muncul 30 hari terakhir tidak dipakai lagi',
        (tester) async {
      final first =
          SessionPlanBuilder.practice(QuestionType.figMtx, now: appNow);
      final sessions = FakeSessionRepository()
        ..history = [
          for (final i in first.items)
            AnswerRecord(
              sessionId: 99,
              posisi: 0,
              tipe: i.tipeCode,
              kategori: 'figural',
              seed: i.seed,
              kesulitan: i.difficulty,
              genVersi: i.genVersi,
              opsiDipilih: 0,
              benar: true,
              durasiMs: 30000,
              label: SpeedLabel.benarCepat,
            ),
        ];
      await openCatalog(tester, sessions: sessions);
      await tester.tap(find.text('Matriks 3x3'));
      await tester.pumpAndSettle();
      final seeds = {for (final i in sessions.sessions[1]!.plan.items) i.seed};
      expect(seeds.length, 10);
      expect(
          seeds.intersection({for (final i in first.items) i.seed}), isEmpty);
    });

    testWidgets('gagal menulis: pesan dan tetap di katalog', (tester) async {
      final sessions = FakeSessionRepository()
        ..failStartWith = StateError('disk penuh');
      final app = await openCatalog(tester, sessions: sessions);
      await tester.tap(find.text('Deret angka'));
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(find.textContaining('Sesi belum dimulai'), findsOneWidget);
      expect(find.textContaining('disk penuh'), findsNothing);
    });

    testWidgets('kembali dari sesi: katalog tetap di mode yang sama',
        (tester) async {
      final app = await openCatalog(tester);
      await tester.tap(find.text('Simulasi'));
      await tester.pumpAndSettle();
      await show(tester, 'Mulai simulasi');
      await tester.tap(find.text('Mulai simulasi'));
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(
        tester
            .widget<SegmentedControl>(find.byType(SegmentedControl))
            .selectedIndex,
        1,
      );
    });
  });

  group('mode Simulasi', () {
    testWidgets('daftar tipe diganti ringkasan subtes profil aktif',
        (tester) async {
      await openCatalog(tester);
      await tester.tap(find.text('Simulasi'));
      await tester.pumpAndSettle();
      expect(find.text('Matriks 3x3'), findsNothing);
      expect(find.text('Bank pribadi'), findsNothing);
      expect(find.text('Subtes simulasi'), findsOneWidget);
      expect(find.textContaining('"QA, CCAT-style"'), findsOneWidget);
      expect(find.text('Verbal'), findsOneWidget);
      expect(find.text('15 soal, 4 menit'), findsNWidgets(2));
      expect(find.text('10 soal, 4 menit'), findsOneWidget);
      expect(find.text('10 soal, 3 menit'), findsOneWidget);
      // Verbal belum punya bank soal: ditandai dan dijelaskan.
      expect(find.text('Belum tersedia'), findsOneWidget);
      expect(
        find.text('Subtes yang belum tersedia dilewati saat simulasi dimulai.'),
        findsOneWidget,
      );
    });

    testWidgets('satuan Kraepelin dan kepribadian', (tester) async {
      await openCatalog(
        tester,
        profiles: FakeProfileRepository([
          activeProfile(
            nama: 'Bank',
            format: TestFormat.bank,
          ),
        ]),
      );
      await tester.tap(find.text('Simulasi'));
      await tester.pumpAndSettle();
      await show(tester, 'Kepribadian');
      expect(find.text('15 kolom, 15 menit'), findsOneWidget);
      expect(find.text('36 item, 15 menit'), findsOneWidget);
    });

    testWidgets('mode bertahan saat pindah tab', (tester) async {
      final app = await openCatalog(tester);
      await tester.tap(find.text('Simulasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beranda').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Psikotes').last);
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(find.text('Subtes simulasi'), findsOneWidget);
    });

    testWidgets(
        'Mulai simulasi membuat sesi bertimer per subtes dan membuka S07',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openCatalog(tester, sessions: sessions);
      expect(find.text('Simulasi penuh'), findsOneWidget);
      expect(find.text('QA, CCAT-style'), findsOneWidget);
      await show(tester, 'Mulai simulasi');
      await tester.tap(find.text('Mulai simulasi'));
      await tester.pumpAndSettle();

      expect(app.location, '/sesi/1');
      final s = sessions.sessions[1]!;
      expect(s.mode, SessionMode.simulasi);
      expect([for (final t in s.plan.subtes) t.kategori],
          ['numerik', 'logika', 'figural']);
      expect(s.plan.items.length, 35);
      // Deadline mutlak subtes pertama: 4 menit dari mulai.
      expect(s.deadline, appNow.add(const Duration(minutes: 4)));
    });

    testWidgets('profil tanpa subtes yang bisa disusun: pesan, tanpa sesi',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openCatalog(
        tester,
        sessions: sessions,
        profiles: FakeProfileRepository([
          activeProfile(blueprint: only('verbal')),
        ]),
      );
      await show(tester, 'Mulai simulasi');
      await tester.tap(find.text('Mulai simulasi'));
      await tester.pumpAndSettle();
      expect(app.location, '/psikotes');
      expect(sessions.sessions, isEmpty);
      expect(
          find.textContaining('Simulasi belum bisa disusun'), findsOneWidget);
    });

    testWidgets('gagal menulis sesi: pesan tanpa exception', (tester) async {
      final sessions = FakeSessionRepository()
        ..failStartWith = StateError('io error');
      await openCatalog(tester, sessions: sessions);
      await show(tester, 'Mulai simulasi');
      await tester.tap(find.text('Mulai simulasi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sesi belum dimulai'), findsOneWidget);
      expect(find.textContaining('io error'), findsNothing);
    });

    testWidgets('profil tidak bisa dibaca: Mulai simulasi nonaktif',
        (tester) async {
      final repo = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await openCatalog(tester, profiles: repo);
      await tester.tap(find.text('Simulasi'));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final button = find.widgetWithText(InkWell, 'Mulai simulasi');
      expect(tester.widget<InkWell>(button).onTap, isNull);
    });
  });

  group('bank pribadi', () {
    testWidgets('kosong: teks spek dan tombol Buka Capture', (tester) async {
      final app = await openCatalog(tester);
      await show(tester, 'Belum ada soal Capture');
      expect(find.text('Belum ada soal Capture'), findsOneWidget);
      expect(find.text('Simpan soal dari tes asli lewat Capture soal.'),
          findsOneWidget);
      await tester.tap(find.text('Buka Capture'));
      await tester.pumpAndSettle();
      expect(app.location, '/capture');
    });

    testWidgets('berisi: jumlah soal Capture', (tester) async {
      await openCatalog(
        tester,
        captures:
            FakeCaptureRepository([captured(1), captured(2), captured(3)]),
      );
      await show(tester, 'Soal hasil Capture: 3');
      expect(find.text('Soal hasil Capture: 3'), findsOneWidget);
      expect(find.text('Belum ada soal Capture'), findsNothing);
    });

    testWidgets('baris soal Capture memulai latihan dari bank pribadi',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openCatalog(
        tester,
        sessions: sessions,
        captures: FakeCaptureRepository(
          [captured(1), captured(2), captured(3)],
        ),
      );
      await show(tester, 'Soal hasil Capture: 3');
      await tester.tap(find.text('Soal hasil Capture: 3'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/sesi/'));
      final plan = sessions.sessions.values.single.plan;
      expect(plan.items.map((i) => i.refId).toSet(), {1, 2, 3});
      expect(plan.items.every((i) => i.isCapture), isTrue);
      expect(sessions.sessions.values.single.mode, SessionMode.latihan);
      expect(find.textContaining('Soal '), findsWidgets,
          reason: 'soal Capture tampil di layar sesi');
    });

    testWidgets('tidak ada tag Segera di baris soal Capture', (tester) async {
      await openCatalog(
        tester,
        captures: FakeCaptureRepository([captured(1)]),
      );
      await show(tester, 'Soal hasil Capture: 1');
      final r = row(tester, 'Soal hasil Capture: 1');
      expect(r.trailing, isNull);
      expect(r.onTap, isNotNull);
    });

    testWidgets('baris tiap soal membuka S12 mode ubah; Tambah soal ke S12',
        (tester) async {
      final app = await openCatalog(
        tester,
        captures: FakeCaptureRepository([captured(4)]),
      );
      await show(tester, 'Tambah soal Capture');
      await tester.tap(find.text('Tambah soal Capture'));
      await tester.pumpAndSettle();
      expect(app.location, '/capture');
      app.router.pop();
      await tester.pumpAndSettle();

      await show(tester, 'Soal 4');
      await tester.tap(find.text('Soal 4'));
      await tester.pumpAndSettle();
      expect(app.location, '/capture/4');
      expect(find.text('Ubah soal Capture'), findsOneWidget);
    });

    testWidgets('baris Catatan psikotes membuka S13', (tester) async {
      final app = await openCatalog(tester);
      await show(tester, 'Catatan psikotes');
      await tester.tap(find.text('Catatan psikotes'));
      await tester.pumpAndSettle();
      expect(app.location, '/catatan-tes');
    });

    testWidgets('memuat: skeleton', (tester) async {
      final captures = FakeCaptureRepository()..gate = Completer<void>();
      await openCatalog(tester, captures: captures);
      await show(tester, 'Bank pribadi');
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.text('Belum ada soal Capture'), findsNothing);
      captures.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Belum ada soal Capture'), findsOneWidget);
    });

    testWidgets('galat: sebab dan Coba lagi, tanpa teks exception',
        (tester) async {
      final captures = FakeCaptureRepository()..failWith = StateError('sqlite');
      await openCatalog(tester, captures: captures);
      await show(tester, 'Soal Capture tidak bisa dibaca');
      expect(find.text('Soal Capture tidak bisa dibaca'), findsOneWidget);
      expect(find.textContaining('sqlite'), findsNothing);
      captures.failWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Soal Capture tidak bisa dibaca'), findsNothing);
      expect(find.text('Belum ada soal Capture'), findsOneWidget);
    });
  });

  group('tata letak dan aksesibilitas', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('tanpa meluap di 360 dp, skala teks $scale', (tester) async {
        await openCatalog(tester, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -6000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Simulasi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('panel Simulasi penuh dengan nama profil terpanjang',
        (tester) async {
      await openCatalog(
        tester,
        textScale: 2,
        profiles: FakeProfileRepository([
          activeProfile(
            nama: 'Mobile Dev, Psikotes Bank-style untuk perusahaan target',
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Mulai simulasi'), findsOneWidget);
    });

    testWidgets('semua area ketuk minimal 48 x 48', (tester) async {
      await openCatalog(tester);
      for (final i in tester.widgetList<InkWell>(find.byType(InkWell))) {
        if (i.onTap == null) continue;
        final size = tester.getSize(find.byWidget(i));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$i');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$i');
      }
    });

    testWidgets('judul kelompok adalah header untuk pembaca layar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openCatalog(tester);
      final s = tester.getSemantics(find.text('Numerik dan logika'));
      expect(s.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });
  });
}
