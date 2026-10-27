import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';

/// Dijalankan otomatis sebelum setiap berkas test di folder ini.
/// Memuat Instrument Sans agar golden tidak memakai font cadangan, dan memberi
/// ambang kecil pada pembanding golden karena anti-aliasing teks sedikit berbeda
/// antar sistem operasi (golden dibuat di Windows, CI jalan di Linux).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();

  final base = goldenFileComparator;
  if (base is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      base.basedir.resolve('placeholder_test.dart'),
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// Selisih piksel maksimum yang dianggap sama (0,5%).
  static const double tolerance = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
