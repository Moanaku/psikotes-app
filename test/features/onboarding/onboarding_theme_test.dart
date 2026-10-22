import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/onboarding/profile_screen.dart';
import 'package:simulator_psikotes_it/features/onboarding/role_screen.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_app.dart';
import '../../core/golden_helper.dart' show goldenTest;

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

List<Override> repo() => [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
    ];

void main() {
  group('tema gelap per layar (token gelap dipakai, tanpa galat)', () {
    testWidgets('S01', (tester) async {
      await pumpScreen(tester, const RoleScreen(),
          brightness: Brightness.dark, overrides: repo());
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Kamu melamar sebagai apa?'), AppColors.dark.ink);
      expect(colorOf(tester, 'Langkah 1 dari 3'), AppColors.dark.inkMuted);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        AppColors.dark.surface,
      );
    });

    testWidgets('S02', (tester) async {
      await pumpScreen(tester, const ProfileScreen(),
          brightness: Brightness.dark, overrides: repo());
      expect(tester.takeException(), isNull);
      expect(colorOf(tester, 'Format tes'), AppColors.dark.ink);
      expect(colorOf(tester, 'Bobot 27% di latihan campuran'),
          AppColors.dark.inkMuted);
    });
  });

  group('golden layar onboarding', () {
    goldenTest('S01 terang 360', (tester) async {
      await pumpScreen(tester, const RoleScreen(), overrides: repo());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s01_role_360.png'));
    });

    goldenTest('S01 gelap 360', (tester) async {
      await pumpScreen(tester, const RoleScreen(),
          brightness: Brightness.dark, overrides: repo());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s01_role_360_gelap.png'));
    });

    goldenTest('S02 terang 360', (tester) async {
      await pumpScreen(tester, const ProfileScreen(),
          height: 1700, overrides: repo());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s02_profil_360.png'));
    });

    goldenTest('S02 gelap 360', (tester) async {
      await pumpScreen(tester, const ProfileScreen(),
          brightness: Brightness.dark, height: 1700, overrides: repo());
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s02_profil_360_gelap.png'));
    });

    goldenTest('S02 dengan galat isian 360', (tester) async {
      await pumpScreen(tester, const ProfileScreen(),
          height: 1700, overrides: repo());
      await tester.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('tanggal')),
              matching: find.byType(TextField)),
          '21/10/2026');
      await tester.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('jumlah-verbal')),
              matching: find.byType(TextField)),
          '');
      await tester.tap(find.text('Simpan dan lanjut'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/s02_profil_galat_360.png'));
    });
  });
}
