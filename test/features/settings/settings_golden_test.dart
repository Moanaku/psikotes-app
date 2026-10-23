import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/backup.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';
import 'package:simulator_psikotes_it/features/settings/settings_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/fake_settings.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'settings_screen_test.dart' show Rig, summary;

List<Override> repos(Rig rig) => [
      profileRepositoryProvider.overrideWithValue(rig.profiles),
      ...rig.overrides,
    ];

Rig filled() => Rig(
      profiles: FakeProfileRepository([
        activeProfile(),
        activeProfile(id: 2, nama: 'Mobile Dev, Bank-style', aktif: false),
      ]),
      settings: FakeSettingsRepository({
        SettingKeys.penyediaAi: 'gemini',
        SettingKeys.tema: 'gelap',
      }),
    );

void main() {
  goldenTest('S18 pengaturan terang 360', (tester) async {
    await pumpScreen(tester, const SettingsScreen(),
        height: 2000, overrides: repos(filled()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_pengaturan_360.png'));
  });

  goldenTest('S18 pengaturan gelap 360', (tester) async {
    await pumpScreen(tester, const SettingsScreen(),
        brightness: Brightness.dark, height: 2000, overrides: repos(filled()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_pengaturan_360_gelap.png'));
  });

  goldenTest('S18 key tersimpan 360', (tester) async {
    final secrets = MemorySecretStore(persistent: true);
    await secrets.write('api_key_gemini', 'AIza-rahasia');
    final rig = Rig(
      settings: FakeSettingsRepository({SettingKeys.penyediaAi: 'gemini'}),
      secrets: secrets,
    );
    await pumpScreen(tester, const SettingsScreen(),
        height: 2000, overrides: repos(rig));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_key_tersimpan_360.png'));
  });

  goldenTest('S18 ringkasan impor 360', (tester) async {
    final rig = Rig(pick: '{}');
    rig.backup.summary = summary(added: 1, updated: 1);
    await pumpScreen(tester, const SettingsScreen(),
        height: 2200, overrides: repos(rig));
    await tester.ensureVisible(find.text('Impor backup'));
    await tester.tap(find.text('Impor backup'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_impor_ringkasan_360.png'));
  });

  goldenTest('S18 galat impor 360', (tester) async {
    final rig = Rig(pick: 'bukan backup');
    rig.backup.previewFailWith =
        const BackupException(BackupProblem.unreadable);
    await pumpScreen(tester, const SettingsScreen(),
        height: 2000, overrides: repos(rig));
    await tester.ensureVisible(find.text('Impor backup'));
    await tester.tap(find.text('Impor backup'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_impor_galat_360.png'));
  });

  goldenTest('S18 memuat 360', (tester) async {
    final settings = FakeSettingsRepository()..gate = Completer<void>();
    await pumpScreen(tester, const SettingsScreen(),
        height: 800, overrides: repos(Rig(settings: settings)));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_memuat_360.png'));
  });

  goldenTest('S18 galat 360', (tester) async {
    final settings = FakeSettingsRepository()..failWith = StateError('x');
    await pumpScreen(tester, const SettingsScreen(),
        height: 800, overrides: repos(Rig(settings: settings)));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s18_galat_360.png'));
  });
}
