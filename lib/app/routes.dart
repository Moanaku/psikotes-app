/// Rute app. Daftar lengkap dan aturan: docs/05-spek-layar.md.
abstract final class Routes {
  static const onboardingRole = '/onboarding/role'; // S01
  static const onboardingProfil = '/onboarding/profil'; // S02
  static const onboardingDiagnostik = '/onboarding/diagnostik'; // S03
  static const beranda = '/'; // S04
  static const psikotes = '/psikotes'; // S05
  static const sesi = '/sesi/:id'; // S06, S07
  static const hasil = '/hasil/:id'; // S08
  static const pembahasan = '/hasil/:id/soal/:n'; // S09
  static const bukuKesalahan = '/buku-kesalahan'; // S10
  static const statistik = '/statistik'; // S11
  static const capture = '/capture'; // S12
  static const captureUbah = '/capture/:id'; // S12
  static const catatanTes = '/catatan-tes'; // S13
  static const kepribadian = '/kepribadian/:id'; // S14 (v1.1)
  static const wawancara = '/wawancara'; // S15 (v1.3)
  static const wawancaraDialog = '/wawancara/:id'; // S16 (v1.3)
  static const wawancaraLaporan = '/wawancara/:id/laporan'; // S17 (v1.3)
  static const pengaturan = '/pengaturan'; // S18
  static const pengetahuan = '/pengetahuan'; // S19 (v1.1)
  static const pengetahuanSesi = '/pengetahuan/sesi/:id'; // S20 (v1.1)
}
