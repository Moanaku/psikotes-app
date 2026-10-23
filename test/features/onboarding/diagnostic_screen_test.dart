import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/score_bar.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/diagnostic_planner.dart';
import 'package:simulator_psikotes_it/features/onboarding/diagnostic_screen.dart';

import '../../core/golden_helper.dart' show expectTouchTargets48;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const path = '/onboarding/diagnostik';

SessionPlan diagnosticPlan([TestProfile? profile]) => DiagnosticPlanner.build(
      (profile ?? activeProfile()).blueprint,
      now: appNow,
      available: GeneratorRegistry.types.toSet(),
    )!
        .plan;

Future<AppHarness> openDiagnostic(
  WidgetTester tester, {
  FakeSessionRepository? sessions,
  FakeProfileRepository? profiles,
  double textScale = 1,
  double width = 360,
}) async {
  final app = await pumpApp(
    tester,
    profiles: profiles ?? FakeProfileRepository([activeProfile()]),
    sessions: sessions,
    textScale: textScale,
    width: width,
  );
  await app.go(path);
  return app;
}

void main() {
  group('sebelum diagnostik', () {
    testWidgets('pengantar, progres per subtes, pratinjau tanpa angka contoh',
        (tester) async {
      await openDiagnostic(tester);
      expect(find.text('Diagnostik'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Kenali titik awalmu'), findsOneWidget);
      expect(
        find.text(
            'Maksimal 20 menit. Hasilnya menentukan urutan latihan pertamamu.'),
        findsOneWidget,
      );
      expect(find.text('Progres'), findsOneWidget);
      for (final k in ['Numerik', 'Logika', 'Figural']) {
        expect(find.text(k), findsWidgets, reason: k);
      }
      expect(find.text('Belum'), findsNWidgets(3));
      expect(find.text('Verbal'), findsNothing,
          reason: 'belum punya soal, jadi dilewati (A59)');
      expect(find.textContaining('6 menit'), findsNWidgets(3));
      expect(find.text('Setelah selesai'), findsOneWidget);
      expect(find.byType(ScoreBar), findsNWidgets(3));
      expect(find.text('Belum ada'), findsNWidgets(3));
      expect(find.text('Lewati, nanti saja'), findsOneWidget);
      expect(find.text('Mulai diagnostik'), findsOneWidget);
      expect(find.text('Ke beranda'), findsOneWidget);
    });

    testWidgets('Lewati dan Ke beranda menuju beranda', (tester) async {
      final app = await openDiagnostic(tester);
      await tester.tap(find.text('Lewati, nanti saja'));
      await tester.pumpAndSettle();
      expect(app.location, '/');

      await app.go(path);
      await tester.ensureVisible(find.text('Ke beranda'));
      await tester.tap(find.text('Ke beranda'));
      await tester.pumpAndSettle();
      expect(app.location, '/');
    });

    testWidgets('Mulai diagnostik membuat sesi diagnostik dan membukanya',
        (tester) async {
      final sessions = FakeSessionRepository();
      final app = await openDiagnostic(tester, sessions: sessions);
      await tester.tap(find.text('Mulai diagnostik'));
      await tester.pumpAndSettle();

      expect(sessions.sessions.length, 1);
      final s = sessions.sessions[1]!;
      expect(s.mode, SessionMode.diagnostik);
      expect(s.profileId, 1);
      expect(s.plan.subtes.map((x) => x.kategori),
          ['numerik', 'logika', 'figural']);
      expect(
        s.plan.subtes.fold<int>(0, (a, x) => a + (x.menit ?? 0)),
        lessThanOrEqualTo(20),
      );
      expect(app.location, '/sesi/1');
    });

    testWidgets('gagal menulis sesi: pesan, tetap di layar, bisa diulang',
        (tester) async {
      final sessions = FakeSessionRepository()
        ..failStartWith = StateError('disk penuh: SQLITE_FULL');
      final app = await openDiagnostic(tester, sessions: sessions);
      await tester.tap(find.text('Mulai diagnostik'));
      await tester.pumpAndSettle();
      expect(app.location, path);
      expect(find.textContaining('Diagnostik belum dimulai'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);

      sessions.failStartWith = null;
      await tester.tap(find.text('Mulai diagnostik'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/1');
    });
  });

  group('diagnostik yang terputus', () {
    testWidgets('progres dari posisi terakhir dan bisa dilanjutkan',
        (tester) async {
      final sessions = FakeSessionRepository();
      final plan = diagnosticPlan();
      // Posisi di subtes kedua (logika).
      final second = plan.subtes.first.jumlah + 1;
      final id = await seedSession(
        sessions,
        mode: SessionMode.diagnostik,
        plan: plan,
        answered: second,
        posisi: second,
      );
      final app = await openDiagnostic(tester, sessions: sessions);

      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Berjalan'), findsOneWidget);
      expect(find.text('Belum'), findsOneWidget);
      expect(find.text('Lanjutkan diagnostik'), findsOneWidget);
      expect(find.text('Mulai diagnostik'), findsNothing);

      await tester.tap(find.text('Lanjutkan diagnostik'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/$id');
      expect(sessions.sessions.length, 1, reason: 'tidak membuat sesi baru');
    });

    testWidgets('sesi latihan yang terputus tidak dianggap diagnostik',
        (tester) async {
      final sessions = FakeSessionRepository();
      await seedSession(
        sessions,
        mode: SessionMode.latihan,
        plan: diagnosticPlan(),
        answered: 2,
        posisi: 2,
      );
      await openDiagnostic(tester, sessions: sessions);
      expect(find.text('Mulai diagnostik'), findsOneWidget);
      expect(find.text('Lanjutkan diagnostik'), findsNothing);
    });
  });

  group('sesudah diagnostik', () {
    Future<(AppHarness, FakeSessionRepository, int)> finished(
      WidgetTester tester,
    ) async {
      final sessions = FakeSessionRepository();
      final plan = diagnosticPlan();
      final figuralStart = plan.items.indexWhere((i) => i.subtes == 'figural');
      final id = await seedSession(
        sessions,
        mode: SessionMode.diagnostik,
        plan: plan,
        finished: true,
        // Numerik dan logika benar semua, figural benar sepertiga.
        correct: (p) => p < figuralStart || p % 3 == 0,
      );
      final app = await openDiagnostic(tester, sessions: sessions);
      return (app, sessions, id);
    }

    testWidgets('hasil nyata menggantikan pratinjau dengan kategori terlemah',
        (tester) async {
      await finished(tester);
      expect(find.text('3 / 3'), findsNothing);
      expect(find.text('Hasil diagnostik'), findsOneWidget);
      expect(find.text('Setelah selesai'), findsNothing);
      expect(find.text('Selesai'), findsNWidgets(3));

      final bars = tester.widgetList<ScoreBar>(find.byType(ScoreBar)).toList();
      expect(bars.length, 3);
      expect(bars[0].valueLabel, '100%');
      expect(bars[1].valueLabel, '100%');
      expect(bars[2].weakest, isTrue);
      expect(bars[2].label, startsWith('Figural, median 30 dtk'));
      expect(bars[0].weakest, isFalse);
      expect(find.text('Terlemah: Figural'), findsOneWidget);
    });

    testWidgets(
        'tombol utama Ke beranda; ulang membuat sesi baru tanpa menghapus '
        'hasil lama', (tester) async {
      final (app, sessions, oldId) = await finished(tester);
      expect(find.text('Ke beranda'), findsOneWidget);
      expect(find.text('Ulangi diagnostik'), findsOneWidget);
      expect(find.text('Lewati, nanti saja'), findsNothing);

      await tester.tap(find.text('Ulangi diagnostik'));
      await tester.pumpAndSettle();
      expect(app.location, '/sesi/2');
      expect(sessions.sessions.length, 2);
      expect(sessions.sessions[oldId]!.selesai, isNotNull);
      expect(sessions.sessions[oldId]!.skor, isNotNull,
          reason: 'hasil lama tetap tersimpan');
    });
  });

  group('kondisi', () {
    testWidgets('kosong: profil tanpa subtes yang punya soal', (tester) async {
      final verbalOnly = activeProfile(
        blueprint: const ProfileBlueprint(
          subtes: [
            SubtestSpec(kategori: 'verbal', aktif: true, jumlah: 15, menit: 4),
          ],
          bobot: {'verbal': 1.0},
        ),
      );
      final app = await openDiagnostic(
        tester,
        profiles: FakeProfileRepository([verbalOnly]),
      );
      expect(
          find.text('Belum ada subtes yang bisa didiagnosis'), findsOneWidget);
      expect(find.textContaining('Nyalakan Numerik, Logika, atau Figural'),
          findsOneWidget);
      expect(find.text('Mulai diagnostik'), findsNothing);
      await tester.tap(find.text('Ubah profil'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/onboarding/profil'));
    });

    testWidgets('tanpa profil aktif: arahkan membuat profil', (tester) async {
      final app = await pumpApp(tester);
      await app.go(path);
      expect(find.text('Belum ada profil aktif'), findsOneWidget);
      await tester.tap(find.text('Buat profil tes'));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding/role');
    });

    testWidgets('memuat: skeleton berbentuk baris, bukan spinner',
        (tester) async {
      final gated = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await openDiagnostic(tester, profiles: gated);
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Lewati, nanti saja'), findsOneWidget);

      gated.watchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Mulai diagnostik'), findsOneWidget);
    });

    testWidgets('galat: sebab dan Coba lagi, tanpa teks exception',
        (tester) async {
      final sessions = FakeSessionRepository()
        ..failSinceWith = StateError('tabel rusak: SQLITE_CORRUPT');
      await openDiagnostic(tester, sessions: sessions);
      expect(find.text('Diagnostik tidak bisa disiapkan'), findsOneWidget);
      expect(find.textContaining('SQLITE'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.text('Lewati, nanti saja'), findsOneWidget);

      sessions.failSinceWith = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai diagnostik'), findsOneWidget);
    });
  });

  group('keterbacaan', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
          '360 dp, teks sistem ${(scale * 100).round()}%: tanpa overflow',
          (tester) async {
        await openDiagnostic(tester, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('Mulai diagnostik'), findsOneWidget);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('target sentuh minimal 48 dp', (tester) async {
      await openDiagnostic(tester);
      expectTouchTargets48(tester);
    });

    testWidgets('tema gelap memakai token gelap', (tester) async {
      final sessions = FakeSessionRepository();
      await pumpScreen(
        tester,
        const DiagnosticScreen(),
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
      final title = tester.widget<Text>(find.text('Kenali titik awalmu'));
      expect(title.style?.color, AppColors.dark.ink);
      final body = tester.widget<Text>(find.textContaining('Maksimal 20'));
      expect(body.style?.color, AppColors.dark.inkMuted);
    });
  });
}
