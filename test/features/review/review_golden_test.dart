import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/review/result_screen.dart';
import 'package:simulator_psikotes_it/features/review/review_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'review_test_support.dart';

const mixed = [
  Outcome.benarCepat,
  Outcome.salahCepat,
  Outcome.benarLambat,
  Outcome.dilewati,
];

List<Override> repos(
  FakeSessionRepository s, {
  FakeProfileRepository? profiles,
  FakeMistakeRepository? mistakes,
  List<Override> extra = const [],
}) =>
    [
      profileRepositoryProvider.overrideWithValue(
        profiles ?? FakeProfileRepository([activeProfile()]),
      ),
      sessionRepositoryProvider.overrideWithValue(s),
      answerRepositoryProvider.overrideWithValue(s),
      mistakeRepositoryProvider
          .overrideWithValue(mistakes ?? FakeMistakeRepository()),
      ...extra,
    ];

void main() {
  goldenTest('S08 hasil terang 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    await pumpScreen(tester, ResultScreen(sessionId: id),
        height: 1000, overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s08_hasil_360.png'));
  });

  goldenTest('S08 hasil gelap 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    await pumpScreen(tester, ResultScreen(sessionId: id),
        brightness: Brightness.dark, height: 1000, overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s08_hasil_360_gelap.png'));
  });

  goldenTest('S08 memuat 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    final gated = FakeProfileRepository([activeProfile()])
      ..watchGate = Completer<void>();
    await pumpScreen(tester, ResultScreen(sessionId: id),
        overrides: repos(s, profiles: gated));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s08_hasil_memuat_360.png'));
  });

  goldenTest('S08 galat 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    s.failByIdWith = StateError('rusak');
    await pumpScreen(tester, ResultScreen(sessionId: id), overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s08_hasil_galat_360.png'));
  });

  goldenTest('S09 soal salah terang 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    final m = FakeMistakeRepository();
    await m.upsertFromAnswer(s.answersOf(id)[1]!, appNow);
    await pumpScreen(tester, ReviewScreen(sessionId: id, number: 2),
        height: 1300, overrides: repos(s, mistakes: m));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s09_pembahasan_360.png'));
  });

  goldenTest('S09 soal salah gelap 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    await pumpScreen(tester, ReviewScreen(sessionId: id, number: 2),
        brightness: Brightness.dark, height: 1300, overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s09_pembahasan_360_gelap.png'));
  });

  goldenTest('S09 soal bergambar 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    await pumpScreen(tester, ReviewScreen(sessionId: id, number: 3),
        height: 1800, overrides: repos(s));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s09_pembahasan_gambar_360.png'));
  });

  goldenTest('S09 soal tidak bisa dibuat ulang 360', (tester) async {
    final s = FakeSessionRepository();
    final id = await seedFinished(s, mixed);
    await pumpScreen(tester, ReviewScreen(sessionId: id, number: 2),
        overrides: repos(s, extra: [
          questionBuilderProvider.overrideWithValue(
            (item) => throw QuestionUnavailable(item, 'versi beda'),
          ),
        ]));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s09_tidak_bisa_dibuat_360.png'));
  });
}
