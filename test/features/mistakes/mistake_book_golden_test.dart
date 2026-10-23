import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/mistakes/mistake_book_screen.dart';
import 'package:simulator_psikotes_it/features/mistakes/mistake_card_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'mistake_book_screen_test.dart' show mc;

List<Override> repos(FakeMistakeRepository m) => [
      profileRepositoryProvider
          .overrideWithValue(FakeProfileRepository([activeProfile()])),
      mistakeRepositoryProvider.overrideWithValue(m),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      answerRepositoryProvider.overrideWithValue(FakeSessionRepository()),
    ];

final varied = [
  mc(1, days: -2),
  mc(2, tipe: 'NUM-SEQ'),
  mc(3, days: 1, streak: 1, interval: 3, tipe: 'LOG-SYL'),
  mc(4, days: 3, streak: 2, interval: 7, tipe: 'NUM-ARI'),
  mc(5, days: 5, source: AnswerSource.capture, tipe: 'lipat-kertas'),
  mc(6, status: CardStatus.dikuasai, streak: 3, interval: 0, days: -20),
];

void main() {
  goldenTest('S10 buku kesalahan terang 360', (tester) async {
    await pumpScreen(tester, const MistakeBookScreen(),
        height: 800, overrides: repos(FakeMistakeRepository(varied)));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_360.png'));
  });

  goldenTest('S10 buku kesalahan gelap 360', (tester) async {
    await pumpScreen(tester, const MistakeBookScreen(),
        brightness: Brightness.dark,
        height: 800,
        overrides: repos(FakeMistakeRepository(varied)));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_360_gelap.png'));
  });

  goldenTest('S10 kosong pertama kali 360', (tester) async {
    await pumpScreen(tester, const MistakeBookScreen(),
        overrides: repos(FakeMistakeRepository()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_kosong_360.png'));
  });

  goldenTest('S10 memuat 360', (tester) async {
    final repo = FakeMistakeRepository(varied)..gate = Completer<void>();
    await pumpScreen(tester, const MistakeBookScreen(), overrides: repos(repo));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_memuat_360.png'));
  });

  goldenTest('S10 galat 360', (tester) async {
    final repo = FakeMistakeRepository(varied)
      ..failWith = StateError('SQLITE_CORRUPT');
    await pumpScreen(tester, const MistakeBookScreen(), overrides: repos(repo));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_galat_360.png'));
  });

  goldenTest('S10 filter kosong 360', (tester) async {
    await pumpScreen(tester, const MistakeBookScreen(),
        overrides: repos(FakeMistakeRepository([mc(1), mc(2, days: 2)])));
    await tester.tap(find.widgetWithText(AppChip, 'Capture'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_filter_kosong_360.png'));
  });

  goldenTest('S10 semua sudah dikerjakan hari ini 360', (tester) async {
    await pumpScreen(tester, const MistakeBookScreen(),
        overrides: repos(FakeMistakeRepository([
          mc(1, days: 3, tipe: 'NUM-SEQ'),
          mc(2, days: 5, streak: 1, interval: 3),
          mc(3, status: CardStatus.dikuasai, streak: 3, interval: 0, days: -9),
        ])));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_buku_selesai_hari_ini_360.png'));
  });

  goldenTest('S10 pembahasan kartu terang 360', (tester) async {
    await pumpScreen(tester, const MistakeCardScreen(cardId: 1),
        height: 1100,
        overrides: repos(FakeMistakeRepository(
            [mc(1, days: 0, streak: 1, interval: 3, tipe: 'NUM-ARI')])));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_kartu_360.png'));
  });

  goldenTest('S10 pembahasan kartu gelap 360', (tester) async {
    await pumpScreen(tester, const MistakeCardScreen(cardId: 1),
        brightness: Brightness.dark,
        height: 1100,
        overrides: repos(FakeMistakeRepository(
            [mc(1, days: 0, streak: 1, interval: 3, tipe: 'NUM-ARI')])));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s10_kartu_360_gelap.png'));
  });
}
