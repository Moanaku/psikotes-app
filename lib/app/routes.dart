/// Rute app. Daftar lengkap dan aturan: docs/05-spek-layar.md.
abstract final class Routes {
  static const onboardingRole = '/onboarding/role'; // S01
  static const onboardingProfil = '/onboarding/profil'; // S02
  static const onboardingPrefix = '/onboarding';
  static const onboardingDiagnostik = '/onboarding/diagnostik'; // S03
  static const beranda = '/'; // S04
  static const psikotes = '/psikotes'; // S05
  static const sesi = '/sesi/:id'; // S06, S07
  static const hasil = '/hasil/:id'; // S08
  static const pembahasan = '/hasil/:id/soal/:n'; // S09
  static const bukuKesalahan = '/buku-kesalahan'; // S10
  static const kartuKesalahan = '/buku-kesalahan/:id'; // pembahasan kartu S10
  static const statistik = '/statistik'; // S11
  static const capture = '/capture'; // S12
  static const captureUbah = '/capture/:id'; // S12
  static const catatanTes = '/catatan-tes'; // S13
  static const catatanTesBaru = '/catatan-tes/baru'; // formulir S13
  static const kepribadian = '/kepribadian/:id'; // S14 (v1.1)
  static const wawancara = '/wawancara'; // S15 (v1.3)
  static const wawancaraDialog = '/wawancara/:id'; // S16 (v1.3)
  static const wawancaraLaporan = '/wawancara/:id/laporan'; // S17 (v1.3)
  static const pengaturan = '/pengaturan'; // S18
  static const pengetahuan = '/pengetahuan'; // S19 (v1.1)
  static const pengetahuanSesi = '/pengetahuan/sesi/:id'; // S20 (v1.1)

  /// S06 atau S07 untuk sesi [id].
  static String sesiPath(int id) => '/sesi/$id';

  /// S14 dengan soal dari [seed].
  static String kepribadianPath(int seed) => '/kepribadian/$seed';

  /// S08 untuk sesi [id].
  static String hasilPath(int id) => '/hasil/$id';

  /// S09 untuk soal nomor [n] (mulai dari 1) di sesi [id].
  static String pembahasanPath(int id, int n) => '/hasil/$id/soal/$n';

  /// S12 untuk soal baru, dihubungkan ke catatan [logId] dan diberi nama tipe
  /// baru [tipe] bila ada.
  static String capturePath({int? logId, String? tipe}) {
    final q = <String, String>{
      if (logId != null) 'catatan': '$logId',
      if (tipe != null) 'tipe': tipe,
    };
    return q.isEmpty
        ? capture
        : Uri(path: capture, queryParameters: q).toString();
  }

  /// S12 untuk mengubah soal Capture [id].
  static String captureUbahPath(int id) => '$capture/$id';

  /// Pembahasan kartu [id] dari baris S10.
  static String kartuKesalahanPath(int id) => '/buku-kesalahan/$id';

  /// S02 dalam mode ubah profil (dibuka dari S18).
  static String profilUbah(int id) => '$onboardingProfil?ubah=$id';
}
