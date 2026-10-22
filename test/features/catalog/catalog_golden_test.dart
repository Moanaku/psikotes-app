import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/catalog/catalog_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

List<Override> catalog({
  FakeCaptureRepository? captures,
  List<Override> extra = const [],
}) =>
    [
      profileRepositoryProvider
          .overrideWithValue(FakeProfileRepository([activeProfile()])),
      mistakeRepositoryProvider.overrideWithValue(FakeMistakeRepository()),
      captureRepositoryProvider
          .overrideWithValue(captures ?? FakeCaptureRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      answerRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      ...extra,
    ];

Future<void> pumpCatalog(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double height = 2300,
  CatalogMode mode = CatalogMode.latihan,
  List<Override> overrides = const [],
}) async {
  await pumpScreen(
    tester,
    tabScreen('/psikotes', const CatalogScreen()),
    brightness: brightness,
    height: height,
    overrides: [
      catalogModeProvider.overrideWith((ref) => mode),
      ...overrides,
    ],
  );
}

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  group('tema gelap katalog (token gelap dipakai, tanpa galat)', () {
    testWidgets('latihan', (tester) async {
      await pumpCatalog(tester,
          brightness: Brightness.dark, overrides: catalog());
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Numerik dan logika'), AppColors.dark.ink);
      expect(colorOf(tester, 'Tersedia di v1.1'), AppColors.dark.inkMuted);
    });

    testWidgets('simulasi', (tester) async {
      await pumpCatalog(tester,
          brightness: Brightness.dark,
          mode: CatalogMode.simulasi,
          overrides: catalog());
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Subtes simulasi'), AppColors.dark.ink);
    });
  });

  group('golden katalog', () {
    goldenTest('S05 latihan terang 360', (tester) async {
      await pumpCatalog(tester, overrides: catalog());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_katalog_360.png'));
    });

    goldenTest('S05 latihan gelap 360', (tester) async {
      await pumpCatalog(tester,
          brightness: Brightness.dark, overrides: catalog());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_katalog_360_gelap.png'));
    });

    goldenTest('S05 simulasi terang 360', (tester) async {
      await pumpCatalog(
        tester,
        height: 900,
        mode: CatalogMode.simulasi,
        overrides: catalog(),
      );
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_simulasi_360.png'));
    });

    goldenTest('S05 bank pribadi berisi 360', (tester) async {
      await pumpCatalog(
        tester,
        overrides: catalog(
          captures: FakeCaptureRepository([captured(1), captured(2)]),
        ),
      );
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_katalog_bank_360.png'));
    });

    goldenTest('S05 bank pribadi memuat 360', (tester) async {
      final captures = FakeCaptureRepository()..gate = Completer<void>();
      await pumpCatalog(tester, overrides: catalog(captures: captures));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_katalog_bank_memuat_360.png'));
    });

    goldenTest('S05 bank pribadi galat 360', (tester) async {
      final captures = FakeCaptureRepository()..failWith = StateError('x');
      await pumpCatalog(tester, overrides: catalog(captures: captures));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s05_katalog_bank_galat_360.png'));
    });
  });
}
