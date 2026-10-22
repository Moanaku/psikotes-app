import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/core/widgets/skeleton_list.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/home/home_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

final nov5 = DateTime.utc(2026, 11, 5);

List<Override> home({
  FakeProfileRepository? profiles,
  bool weaknesses = false,
  List<Override> extra = const [],
}) =>
    [
      profileRepositoryProvider.overrideWithValue(
        profiles ?? FakeProfileRepository([activeProfile(tanggalTes: nov5)]),
      ),
      mistakeRepositoryProvider.overrideWithValue(
        FakeMistakeRepository([card(1), card(2)]),
      ),
      captureRepositoryProvider.overrideWithValue(FakeCaptureRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      answerRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      if (weaknesses) weaknessModelProvider.overrideWithValue(threeWeaknesses),
      ...extra,
    ];

Future<void> pumpHome(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double height = 900,
  List<Override> overrides = const [],
}) =>
    pumpScreen(
      tester,
      tabScreen('/', const HomeScreen()),
      brightness: brightness,
      height: height,
      overrides: overrides,
    );

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  group('tema gelap beranda (token gelap dipakai, tanpa galat)', () {
    testWidgets('data lengkap', (tester) async {
      await pumpHome(
        tester,
        brightness: Brightness.dark,
        overrides: home(weaknesses: true),
      );
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Latihan hari ini'), AppColors.dark.ink);
      expect(colorOf(tester, 'Sekitar 15 menit'), AppColors.dark.inkMuted);
      expect(colorOf(tester, 'Profil aktif'), AppColors.dark.inkMuted);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first))
            .scaffoldBackgroundColor,
        AppColors.dark.surface,
      );
    });

    testWidgets('kosong', (tester) async {
      await pumpHome(tester, brightness: Brightness.dark, overrides: home());
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Belum ada data kelemahan'), AppColors.dark.ink);
    });

    testWidgets('memuat', (tester) async {
      final gated = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await pumpHome(tester,
          brightness: Brightness.dark, overrides: home(profiles: gated));
      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonList), findsNWidgets(3));
    });

    testWidgets('galat', (tester) async {
      await pumpHome(
        tester,
        brightness: Brightness.dark,
        overrides: home(extra: [
          dailyPlannerProvider
              .overrideWithValue(FlakyPlanner(emptyHistoryPlanner({}))),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Rencana latihan tidak bisa disusun'),
          AppColors.dark.ink);
    });
  });

  group('golden beranda', () {
    goldenTest('S04 dengan kelemahan terang 360', (tester) async {
      await pumpHome(tester, overrides: home(weaknesses: true));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s04_beranda_360.png'));
    });

    goldenTest('S04 dengan kelemahan gelap 360', (tester) async {
      await pumpHome(tester,
          brightness: Brightness.dark, overrides: home(weaknesses: true));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s04_beranda_360_gelap.png'));
    });

    goldenTest('S04 kosong tanpa tanggal tes 360', (tester) async {
      await pumpHome(
        tester,
        overrides: home(profiles: FakeProfileRepository([activeProfile()])),
      );
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s04_beranda_kosong_360.png'));
    });

    goldenTest('S04 memuat 360', (tester) async {
      final gated = FakeProfileRepository([activeProfile()])
        ..watchGate = Completer<void>();
      await pumpHome(tester, overrides: home(profiles: gated));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s04_beranda_memuat_360.png'));
    });

    goldenTest('S04 galat 360', (tester) async {
      await pumpHome(
        tester,
        overrides: home(extra: [
          dailyPlannerProvider
              .overrideWithValue(FlakyPlanner(emptyHistoryPlanner({
            QuestionType.numSeq,
          }))),
        ]),
      );
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s04_beranda_galat_360.png'));
    });
  });
}
