import 'package:go_router/go_router.dart';

import '../core/widgets/placeholder_screen.dart';
import 'routes.dart';

/// Kerangka rute. Setiap tugas mengganti PlaceholderScreen dengan layar nyata.
/// Pengalihan ke onboarding bila belum ada profil aktif ditambahkan di T11.
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.onboardingRole,
  routes: [
    _r(Routes.onboardingRole, 'S01', 'Pilih role'),
    _r(Routes.onboardingProfil, 'S02', 'Profil tes target'),
    _r(Routes.onboardingDiagnostik, 'S03', 'Diagnostik'),
    _r(Routes.beranda, 'S04', 'Beranda'),
    _r(Routes.psikotes, 'S05', 'Katalog psikotes'),
    _r(Routes.sesi, 'S06', 'Sesi soal'),
    _r(Routes.hasil, 'S08', 'Hasil sesi'),
    _r(Routes.pembahasan, 'S09', 'Pembahasan soal'),
    _r(Routes.bukuKesalahan, 'S10', 'Buku kesalahan'),
    _r(Routes.statistik, 'S11', 'Statistik'),
    _r(Routes.capture, 'S12', 'Capture soal'),
    _r(Routes.captureUbah, 'S12', 'Capture soal'),
    _r(Routes.catatanTes, 'S13', 'Catatan psikotes'),
    _r(Routes.kepribadian, 'S14', 'Sesi kepribadian'),
    _r(Routes.wawancara, 'S15', 'Setup wawancara'),
    _r(Routes.wawancaraDialog, 'S16', 'Dialog wawancara'),
    _r(Routes.wawancaraLaporan, 'S17', 'Laporan wawancara'),
    _r(Routes.pengaturan, 'S18', 'Pengaturan'),
    _r(Routes.pengetahuan, 'S19', 'Bank pengetahuan role'),
    _r(Routes.pengetahuanSesi, 'S20', 'Sesi kartu pengetahuan'),
  ],
);

GoRoute _r(String path, String id, String title) => GoRoute(
      path: path,
      builder: (context, state) => PlaceholderScreen(id: id, title: title),
    );
