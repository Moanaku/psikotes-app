import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/option_tile.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/session_controller.dart';
import 'package:simulator_psikotes_it/features/session/session_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/manual_ticker.dart';
import '../../support/pump_app.dart';

/// Memasang layar sesi untuk sesi yang sudah ada di repository palsu.
Future<FakeSessionRepository> pumpSession(
  WidgetTester tester,
  SessionMode mode,
  SessionPlan plan, {
  Brightness brightness = Brightness.light,
  double height = 900,
  List<Override> extra = const [],
}) async {
  final sessions = FakeSessionRepository();
  final first = plan.subtes.isEmpty ? null : plan.subtes.first.menit;
  await seedSession(
    sessions,
    mode: mode,
    plan: plan,
    deadline: first == null ? null : appNow.add(Duration(minutes: first)),
  );
  await pumpScreen(
    tester,
    const SessionScreen(sessionId: 1),
    brightness: brightness,
    height: height,
    overrides: [
      profileRepositoryProvider
          .overrideWithValue(FakeProfileRepository([activeProfile()])),
      sessionRepositoryProvider.overrideWithValue(sessions),
      answerRepositoryProvider.overrideWithValue(sessions),
      captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
      mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
      tickerFactoryProvider.overrideWithValue(ManualTicker().factory),
      ...extra,
    ],
  );
  return sessions;
}

Future<void> choose(WidgetTester tester, int i) async {
  final tile = find.byType(OptionTile).at(i);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, String label) async {
  final b = find.widgetWithText(AppButton, label);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  group('golden sesi', () {
    goldenTest('S06 soal teks dengan opsi terpilih 360', (tester) async {
      await pumpSession(tester, SessionMode.latihan, timedLatihanPlan());
      await choose(tester, 1);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_latihan_teks_360.png'));
    });

    goldenTest('S06 soal teks gelap 360', (tester) async {
      await pumpSession(tester, SessionMode.latihan, latihanPlan(),
          brightness: Brightness.dark);
      await choose(tester, 0);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_latihan_teks_360_gelap.png'));
    });

    goldenTest('S06 matriks bergambar 360', (tester) async {
      await pumpSession(
        tester,
        SessionMode.latihan,
        SessionPlan(items: [planItem(QuestionType.figMtx, 50, 'figural')]),
        height: 1500,
      );
      await choose(tester, 1);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_latihan_gambar_360.png'));
    });

    goldenTest('S06 salah dengan pembahasan 360', (tester) async {
      await pumpSession(
        tester,
        SessionMode.latihan,
        SessionPlan(items: [planItem(QuestionType.numSeq, 10, 'numerik')]),
        height: 1000,
      );
      final q = buildFromRegistry(planItem(QuestionType.numSeq, 10, 'numerik'));
      final wrong = q.correctIndex == 0 ? 1 : 0;
      await choose(tester, wrong);
      await submit(
          tester, 'Kirim jawaban ${String.fromCharCode(0x41 + wrong)}');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_salah_pembahasan_360.png'));
    });

    goldenTest('S06 petunjuk terbuka 360', (tester) async {
      await pumpSession(tester, SessionMode.latihan, latihanPlan());
      await submit(tester, 'Buka petunjuk');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_petunjuk_360.png'));
    });

    goldenTest('S06 soal gagal dibuat 360', (tester) async {
      await pumpSession(
        tester,
        SessionMode.latihan,
        latihanPlan(),
        extra: [
          questionBuilderProvider.overrideWithValue(
            (item) => throw StateError('gagal'),
          ),
        ],
      );
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_soal_gagal_360.png'));
    });

    goldenTest('S06 konfirmasi keluar 360', (tester) async {
      await pumpSession(tester, SessionMode.latihan, latihanPlan());
      await tester.tap(find.bySemanticsLabel('Tutup sesi'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s06_keluar_360.png'));
    });

    goldenTest('S07 simulasi soal teks 360', (tester) async {
      await pumpSession(tester, SessionMode.simulasi, simulasiPlan());
      await choose(tester, 0);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s07_simulasi_360.png'));
    });

    goldenTest('S07 simulasi gelap 360', (tester) async {
      await pumpSession(tester, SessionMode.simulasi, simulasiPlan(),
          brightness: Brightness.dark);
      await choose(tester, 2);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s07_simulasi_360_gelap.png'));
    });

    goldenTest('S07 konfirmasi menutup subtes 360', (tester) async {
      await pumpSession(tester, SessionMode.simulasi, simulasiPlan());
      await tester.tap(find.byType(OptionTile).first);
      await tester.pumpAndSettle();
      final container =
          ProviderScope.containerOf(tester.element(find.byType(SessionScreen)));
      await container.read(sessionControllerProvider.notifier).goTo(2);
      await tester.pumpAndSettle();
      await submit(tester, 'Berikutnya');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s07_tutup_subtes_360.png'));
    });
  });

  group('tema gelap sesi memakai token gelap', () {
    testWidgets('latihan', (tester) async {
      await pumpSession(tester, SessionMode.latihan, latihanPlan(),
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Hitungan cepat'), AppColors.dark.ink);
      expect(colorOf(tester, 'Mode Latihan, soal 1 dari 3'),
          AppColors.dark.inkMuted);
    });

    testWidgets('simulasi', (tester) async {
      await pumpSession(tester, SessionMode.simulasi, simulasiPlan(),
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Simulasi QA, CCAT-style'), AppColors.dark.ink);
      expect(colorOf(tester, 'Subtes 1 dari 3, soal 1 dari 3'),
          AppColors.dark.inkMuted);
    });
  });
}
