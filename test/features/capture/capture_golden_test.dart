import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/features/capture/capture_screen.dart';
import 'package:simulator_psikotes_it/features/capture/company_log_form_screen.dart';
import 'package:simulator_psikotes_it/features/capture/company_log_screen.dart';

import '../../core/golden_helper.dart' show goldenTest;
import '../../support/fake_repositories.dart';
import '../../support/pump_app.dart';

List<Override> repos({
  FakeCaptureRepository? captures,
  FakeCompanyLogRepository? logs,
}) =>
    [
      captureRepositoryProvider
          .overrideWithValue(captures ?? FakeCaptureRepository()),
      companyLogRepositoryProvider
          .overrideWithValue(logs ?? FakeCompanyLogRepository()),
      capturePhotoStoreProvider.overrideWithValue(MemoryPhotoStore()),
    ];

CompanyTestLog log(int id, String nama, List<String> tags) => CompanyTestLog(
      id: id,
      perusahaan: nama,
      tanggal: DateTime.utc(2026, 10, 1).subtract(Duration(days: id * 9)),
      subtes: const ['verbal', 'figural'],
      tipeBaru: tags,
      catatan: id == 1 ? 'Waktu terasa kurang. Urutan subtes berubah.' : '',
    );

FakeCompanyLogRepository sampleLogs() => FakeCompanyLogRepository([
      log(1, 'PT Maju Bersama', const ['lipat kertas', 'rotasi kubus']),
      log(2, 'Bank Nusantara', const []),
    ]);

void main() {
  goldenTest('S12 formulir kosong terang 360', (tester) async {
    await pumpScreen(tester, const CaptureScreen(),
        height: 1700, overrides: repos(logs: sampleLogs()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s12_formulir_360.png'));
  });

  goldenTest('S12 formulir kosong gelap 360', (tester) async {
    await pumpScreen(tester, const CaptureScreen(),
        brightness: Brightness.dark,
        height: 1700,
        overrides: repos(logs: sampleLogs()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s12_formulir_360_gelap.png'));
  });

  goldenTest('S12 galat validasi terang 360', (tester) async {
    await pumpScreen(tester, const CaptureScreen(),
        height: 1900, overrides: repos(logs: sampleLogs()));
    await tester.ensureVisible(find.text('Simpan ke bank pribadi'));
    await tester.tap(find.text('Simpan ke bank pribadi'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s12_galat_360.png'));
  });

  goldenTest('S13 daftar dan saran terang 360', (tester) async {
    await pumpScreen(tester, const CompanyLogScreen(),
        height: 1100, overrides: repos(logs: sampleLogs()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_daftar_360.png'));
  });

  goldenTest('S13 daftar dan saran gelap 360', (tester) async {
    await pumpScreen(tester, const CompanyLogScreen(),
        brightness: Brightness.dark,
        height: 1100,
        overrides: repos(logs: sampleLogs()));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_daftar_360_gelap.png'));
  });

  goldenTest('S13 kosong 360', (tester) async {
    await pumpScreen(tester, const CompanyLogScreen(),
        height: 800, overrides: repos());
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_kosong_360.png'));
  });

  goldenTest('S13 memuat 360', (tester) async {
    final logs = FakeCompanyLogRepository()..gate = Completer<void>();
    await pumpScreen(tester, const CompanyLogScreen(),
        height: 800, overrides: repos(logs: logs));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_memuat_360.png'));
  });

  goldenTest('S13 galat 360', (tester) async {
    final logs = FakeCompanyLogRepository()..failWith = StateError('x');
    await pumpScreen(tester, const CompanyLogScreen(),
        height: 800, overrides: repos(logs: logs));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_galat_360.png'));
  });

  goldenTest('S13 formulir catatan tes terang 360', (tester) async {
    await pumpScreen(tester, const CompanyLogFormScreen(),
        height: 1100, overrides: repos());
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/s13_formulir_360.png'));
  });
}
