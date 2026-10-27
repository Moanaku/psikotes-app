import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';

import '../support/app_fonts.dart';

/// Test lebar teks hanya berarti bila mengukur dengan Instrument Sans, bukan
/// font cadangan. Uji perangkat 2: kata terpotong di HP padahal test lulus.
void main() {
  test(
      'Instrument Sans termuat di test: empat bobot, lebar bukan font cadangan',
      () {
    expectAppFontLoaded();
  });

  test('tema app memakai keluarga font yang dimuat', () {
    expect(AppType.title(Colors.black).fontFamily, AppType.family);
    expect(AppType.body(Colors.black).fontFamily, AppType.family);
  });

  test('font yang tidak termuat terdeteksi', () {
    // Keluarga yang tidak ada jatuh ke font cadangan: lebarnya sama untuk semua
    // bobot, sehingga pemeriksaan di atas akan gagal bila font app hilang.
    double width(FontWeight w) {
      final p = TextPainter(
        text: TextSpan(
          text: 'Wawancara',
          style: TextStyle(
              fontFamily: 'FontYangTidakAda', fontSize: 14, fontWeight: w),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return p.width;
    }

    expect(width(FontWeight.w400), width(FontWeight.w700));
  });
}
