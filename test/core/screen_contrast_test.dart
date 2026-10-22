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
  'S04 Beranda': [
    (
      'judul dan nama profil: ink di surface',
      (c) => c.ink,
      (c) => c.surface,
      text
    ),
    (
      '"Profil aktif" dan "hari lagi": inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'panel: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'panel: "Sekitar 15 menit" inkMuted di surfaceContainer',
      (c) => c.inkMuted,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'batas panel: outline di surface',
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
    (
      'tombol garis: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    ('nilai bilah: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'isi bilah ink di trek surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      border
    ),
    (
      'baris pintasan: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    ('tag v1.1: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'bottom nav tidak aktif: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'bottom nav aktif: onAccent di accent (ikon)',
      (c) => c.onAccent,
      (c) => c.accent,
      border
    ),
    (
      'bottom nav aktif: ink di surface (label)',
      (c) => c.ink,
      (c) => c.surface,
      text
    ),
  ],
  'S05 Katalog psikotes': [
    (
      'segmen terpilih: ink di accent',
      (c) => c.onAccent,
      (c) => c.accent,
      text
    ),
    (
      'segmen biasa: ink di surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      text
    ),
    ('judul kelompok: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'alasan nonaktif: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'tag Segera dan v1.1: ink di surface',
      (c) => c.ink,
      (c) => c.surface,
      text
    ),
    (
      'batas tag: outline di surface',
      (c) => c.outline,
      (c) => c.surface,
      border
    ),
    (
      'panel simulasi: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'catatan: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
  ],
  'S03 Diagnostik': [
    ('judul ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'pengantar inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'subjudul baris inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    ('tag Selesai: ok di okContainer', (c) => c.ok, (c) => c.okContainer, text),
    (
      'tag Berjalan dan Terlemah: onAccent di accent',
      (c) => c.onAccent,
      (c) => c.accent,
      text
    ),
    ('tag Belum: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'batas tag Belum: outline di surface',
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
    (
      'tombol sekunder: ink di surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      text
    ),
    (
      'isi bilah ink di trek surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      border
    ),
  ],
  'S06 Sesi latihan': [
    ('judul ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'mode dan nomor soal inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'soal dan opsi: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'batas opsi: outline di surfaceContainer',
      (c) => c.outline,
      (c) => c.surfaceContainer,
      border
    ),
    (
      'opsi terpilih: onAccent di accent',
      (c) => c.onAccent,
      (c) => c.accent,
      text
    ),
    (
      'huruf opsi: ink di surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      text
    ),
    (
      'huruf opsi terpilih: surfaceContainer di ink',
      (c) => c.surfaceContainer,
      (c) => c.ink,
      text
    ),
    (
      'nomor soal terjawab: surfaceContainer di ink',
      (c) => c.surfaceContainer,
      (c) => c.ink,
      text
    ),
    (
      'nomor soal belum: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'batas nomor soal belum: outline di surface',
      (c) => c.outline,
      (c) => c.surface,
      border
    ),
    (
      'feedback benar: ok di okContainer',
      (c) => c.ok,
      (c) => c.okContainer,
      text
    ),
    (
      'feedback benar: ink di okContainer (pembahasan)',
      (c) => c.ink,
      (c) => c.okContainer,
      text
    ),
    (
      'feedback salah: bad di badContainer',
      (c) => c.bad,
      (c) => c.badContainer,
      text
    ),
    (
      'feedback salah: ink di badContainer (pembahasan)',
      (c) => c.ink,
      (c) => c.badContainer,
      text
    ),
    (
      'petunjuk dan konfirmasi: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'batas catatan: outline di surfaceContainer',
      (c) => c.outline,
      (c) => c.surfaceContainer,
      border
    ),
    (
      'tombol sekunder: ink di surfaceContainerHigh',
      (c) => c.ink,
      (c) => c.surfaceContainerHigh,
      text
    ),
    (
      'tombol nonaktif: inkMuted di surfaceContainerHigh',
      (c) => c.inkMuted,
      (c) => c.surfaceContainerHigh,
      text
    ),
    ('timer: ink di surface', (c) => c.ink, (c) => c.surface, text),
  ],
  'S07 Simulasi': [
    ('judul dan timer: ink di surface', (c) => c.ink, (c) => c.surface, text),
    (
      'subtes belum dan keterangan: inkMuted di surface',
      (c) => c.inkMuted,
      (c) => c.surface,
      text
    ),
    (
      'batang subtes sekarang: ink (batas) di surface',
      (c) => c.ink,
      (c) => c.surface,
      border
    ),
    (
      'nomor soal sekarang: onAccent di accent',
      (c) => c.onAccent,
      (c) => c.accent,
      text
    ),
    (
      'opsi terpilih: onAccent di accent',
      (c) => c.onAccent,
      (c) => c.accent,
      text
    ),
    (
      'catatan aturan: ink di surfaceContainer',
      (c) => c.ink,
      (c) => c.surfaceContainer,
      text
    ),
    (
      'tombol utama: surfaceContainer di ink',
      (c) => c.surfaceContainer,
      (c) => c.ink,
      text
    ),
    (
      'tombol sekunder: ink di surfaceContainerHigh',
      (c) => c.ink,
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
