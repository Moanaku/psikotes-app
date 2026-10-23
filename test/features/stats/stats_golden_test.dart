import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/stats/stats_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'stats_screen_test.dart' show finished;

List<Override> repos(FakeSessionRepository s) => [
      profileRepositoryProvider
          .overrideWithValue(FakeProfileRepository([activeProfile()])),
      sessionRepositoryProvider.overrideWithValue(s),
      answerRepositoryProvider.overrideWithValue(s),
      mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
    ];

Widget screen() => tabScreen(Routes.statistik, const StatsScreen());

/// Lima minggu dengan skor naik, ditambah latihan hari ini.
Future<FakeSessionRepository> trending() async {
  final s = FakeSessionRepository();
  await finished(s, 28, correct: (i) => i == 0);
  await finished(s, 21, correct: (i) => i < 2);
  await finished(s, 14, correct: (i) => i == 1);
  await finished(s, 7, correct: (i) => i < 2);
  await finished(s, 1);
  await finished(s, 0, mode: SessionMode.latihan, correct: (i) => i < 2);
  return s;
}

void main() {
  goldenTest('S11 statistik terang 360', (tester) async {
    await pumpScreen(tester, screen(),
        height: 800, overrides: repos(await trending()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_statistik_360.png'));
  });

  goldenTest('S11 statistik gelap 360', (tester) async {
    await pumpScreen(tester, screen(),
        brightness: Brightness.dark,
        height: 800,
        overrides: repos(await trending()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_statistik_360_gelap.png'));
  });

  goldenTest('S11 satu titik 360', (tester) async {
    final s = FakeSessionRepository();
    await finished(s, 1, correct: (i) => i < 2);
    await pumpScreen(tester, screen(), height: 800, overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_satu_titik_360.png'));
  });

  goldenTest('S11 kosong 360', (tester) async {
    await pumpScreen(tester, screen(),
        overrides: repos(FakeSessionRepository()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_kosong_360.png'));
  });

  goldenTest('S11 memuat 360', (tester) async {
    final s = await trending();
    s.finishedGate = Completer<void>();
    await pumpScreen(tester, screen(), overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_memuat_360.png'));
  });

  goldenTest('S11 galat 360', (tester) async {
    final s = await trending();
    s.failFinishedWith = StateError('SQLITE_CORRUPT');
    await pumpScreen(tester, screen(), overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s11_galat_360.png'));
  });
}
