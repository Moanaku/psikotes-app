import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';

/// Berkas font app dan bobotnya (assets/fonts, pubspec.yaml).
const List<String> appFontWeights = ['Regular', 'Medium', 'SemiBold', 'Bold'];

/// Memuat Instrument Sans dari `assets/fonts` lewat `FontLoader`, sama dengan
/// yang dimuat app. Tanpa ini `flutter test` memakai font kotak bawaan (Ahem)
/// yang lebarnya jauh berbeda dari HP, dan test "tidak ada kata terpotong"
/// lulus padahal kata terpotong di perangkat. Dipanggil sekali oleh
/// `flutter_test_config.dart` sebelum setiap berkas test.
Future<void> loadAppFonts() async {
  final loader = FontLoader(AppType.family);
  for (final weight in appFontWeights) {
    final bytes =
        File('assets/fonts/InstrumentSans-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  final code = FontLoader(AppType.codeFamily);
  for (final weight in const ['Regular', 'SemiBold']) {
    final bytes =
        File('assets/fonts/IBMPlexMono-$weight.ttf').readAsBytesSync();
    code.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await code.load();

  // Ikon: tanpa ini ikon Material tampil sebagai kotak di golden.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await iconLoader.load();
    }
  }
}

double _width(String family, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Wawancara Statistik',
      style: TextStyle(fontFamily: family, fontSize: 14, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Memastikan font app sungguhan yang dipakai mengukur teks: lebar teks uji
/// dengan Instrument Sans berbeda dari font cadangan, dan tiap bobot punya
/// lebar sendiri. Gagal dengan pesan jelas bila font tidak termuat, supaya
/// test lebar teks tidak diam-diam memakai font lain.
void expectAppFontLoaded() {
  final fallback = _width('FontYangTidakAda', FontWeight.w400);
  final widths = [
    for (final w in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ])
      _width(AppType.family, w),
  ];
  expect(widths.toSet(), hasLength(4),
      reason: 'empat bobot ${AppType.family} harus punya lebar berbeda; '
          'font app tidak termuat di test');
  for (final w in widths) {
    expect(w, isNot(closeTo(fallback, 0.01)),
        reason: 'lebar sama dengan font cadangan: ${AppType.family} tidak '
            'termuat (loadAppFonts di flutter_test_config.dart)');
  }
}
