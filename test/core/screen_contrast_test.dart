import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';

/// Rasio kontras WCAG antara dua warna.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pasangan teks atau batas yang dipakai satu layar, per tema.
typedef Pair = (
  String,
  Color Function(AppColors),
  Color Function(AppColors),
  double
);

const double text = 4.5;
const double border = 3.0;

final Map<String, List<Pair>> screens = {
  'S01 Pilih role': [
    ('judul ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'teks sekunder inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    ('baris terpilih: ink di accent', (c) => c.onAccent, (c) => c.accent, text),
    (
      'titik radio outline di surface',
      (c) => c.outline,
      (c) => c.surface,
      border
    ),
    (
      'tombol utama: surfaceContainer di ink',
      (c) => c.surfaceContainer,
      (c) => c.ink,
      text
    ),
  ],
  'S02 Profil tes target': [
    ('chip terpilih: ink di accent', (c) => c.onAccent, (c) => c.accent, text),
    (
      'chip biasa: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'batas chip dan isian: outline di surface',
      (c) => c.outline,
      (c) => c.surface,
      border
    ),
    (
      'batas isian: outline di surfaceContainer',
      (c) => c.outline,
      (c) => c.surfaceContainer,
      border
    ),
    (
      'petunjuk isian: placeholder di surfaceContainer',
      (c) => c.placeholder,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'bantuan isian: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    ('galat isian: bad di surface', (c) => c.bad, (c) => c.surface, text),
    (
      'catatan: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    ('tag v1.3: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'tombol nonaktif: inkMuted di surfaceContainerHigh',
      (c) => c.inkMuted,
      (c) => c.surfaceContainerHigh,
      text
    ),
  ],
};

void main() {
  for (final entry in screens.entries) {
    for (final (themeName, colors) in [
      ('terang', AppColors.light),
      ('gelap', AppColors.dark),
    ]) {
      group('${entry.key}, tema $themeName', () {
        for (final (name, fg, bg, min) in entry.value) {
          test(name, () {
            final ratio = contrast(fg(colors), bg(colors));
            // ignore: avoid_print
            printOnFailure('rasio ${ratio.toStringAsFixed(2)} : 1');
            expect(ratio, greaterThanOrEqualTo(min), reason: name);
          });
        }
      });
    }
  }
}
