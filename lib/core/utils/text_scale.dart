import 'package:flutter/material.dart';

/// Batas skala huruf untuk teks "kerangka": label tab bawah, label sumbu
/// grafik, dan label subtes. Di atas ini teks tidak muat di lebarnya yang
/// tetap dan kata terpotong di tengah kata, jadi skalanya dibatasi di sini
/// dan selebihnya mengikuti pengaturan pengguna.
const double chromeTextScaleMax = 1.3;

/// Skala huruf di atas ini membuat dua tombol berdampingan di lebar 360 dp
/// terlalu sempit: "Sebelumnya" patah di tengah kata. Bilah aksi menyusun
/// tombolnya ke bawah mulai di sini.
const double stackButtonsTextScale = 1.15;

/// Bilah aksi harus menyusun tombolnya vertikal ([stackButtonsTextScale]).
bool shouldStackButtons(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 > stackButtonsTextScale;

/// Skala huruf pengguna melewati [chromeTextScaleMax]. Di atas ini bilah
/// baris kolom disusun ke bawah dan keterangan tambahan turun.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 > chromeTextScaleMax;

/// Membatasi skala huruf [child] sampai [chromeTextScaleMax].
class ClampedChromeText extends StatelessWidget {
  const ClampedChromeText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: chromeTextScaleMax,
        child: child,
      );
}
