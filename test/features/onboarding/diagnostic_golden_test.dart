import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/diagnostic_planner.dart';
import 'package:simulator_psikotes_it/features/onboarding/diagnostic_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

List<Override> repos({
  FakeProfileRepository? profiles,
  FakeSessionRepository? sessions,
}) {
  final s = sessions ?? FakeSessionRepository();
  return [
    profileRepositoryProvider.overrideWithValue(
      profiles ?? FakeProfileRepository([activeProfile()]),
    ),
    sessionRepositoryProvider.overrideWithValue(s),
    answerRepositoryProvider.overrideWithValue(s),
    mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
  ];
}

Future<FakeSessionRepository> finishedDiagnostic() async {
  final sessions = FakeSessionRepository();
  final plan = DiagnosticPlanner.build(
    activeProfile().blueprint,
    now: appNow,
    available: GeneratorRegistry.types.toSet(),
  )!
      .plan;
  final figuralStart = plan.items.indexWhere((i) => i.subtes == 'figural');
  await seedSession(
    sessions,
    mode: SessionMode.diagnostik,
    plan: plan,
    finished: true,
    correct: (p) => p < figuralStart ? p % 5 != 0 : p % 3 == 0,
  );
  return sessions;
}

void main() {
  goldenTest('S03 sebelum diagnostik terang 360', (tester) async {
    await pumpScreen(
      tester,
      const DiagnosticScreen(),
      height: 900,
      overrides: repos(),
    );
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s03_diagnostik_360.png'));
  });

  goldenTest('S03 sebelum diagnostik gelap 360', (tester) async {
    await pumpScreen(
      tester,
      const DiagnosticScreen(),
      brightness: Brightness.dark,
      height: 900,
      overrides: repos(),
    );
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s03_diagnostik_360_gelap.png'));
  });

  goldenTest('S03 hasil nyata terang 360', (tester) async {
    await pumpScreen(
      tester,
      const DiagnosticScreen(),
      height: 900,
      overrides: repos(sessions: await finishedDiagnostic()),
    );
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s03_diagnostik_hasil_360.png'));
  });

  goldenTest('S03 memuat 360', (tester) async {
    final gated = FakeProfileRepository([activeProfile()])
      ..watchGate = Completer<void>();
    await pumpScreen(
      tester,
      const DiagnosticScreen(),
      height: 900,
      overrides: repos(profiles: gated),
    );
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s03_diagnostik_memuat_360.png'));
  });

  goldenTest('S03 galat 360', (tester) async {
    final sessions = FakeSessionRepository()
      ..failSinceWith = StateError('tabel rusak');
    await pumpScreen(
      tester,
      const DiagnosticScreen(),
      height: 900,
      overrides: repos(sessions: sessions),
    );
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s03_diagnostik_galat_360.png'));
  });
}
