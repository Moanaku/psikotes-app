# Changelog

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/). Versi mengikuti [docs/07-rencana-tugas.md](docs/07-rencana-tugas.md).

## [Belum dirilis] - v1.1

### Ditambahkan

- Kepribadian Papi-style (F12, T22): 96 pernyataan dari 8 sifat kerja, sesi 24 pilihan paksa di S14 tanpa jawaban benar atau salah, review profil kecenderungan, arti tiap pilihan, dan sifat yang umumnya dicari untuk role profil.
- Modul IT (F14, T24): trace pseudocode dengan interpreter mini buatan sendiri, logika flowchart sebagai tabel kotak, dan rumus Excel (SUM, IF, VLOOKUP, COUNTIF) dengan pecahan eksak. Ketiganya terbuka di katalog dan menjadi subtes "Modul IT" yang aktif untuk role Mobile Dev.

## [1.0.0] - belum dirilis

Rilis v1: psikotes offline untuk berlatih, tanpa akun, tanpa server, tanpa telemetri. Tag `v1.0.0` dibuat pemilik setelah checklist manual lulus (langkahnya di [docs/RILIS-APK.md](docs/RILIS-APK.md)).

### Ditambahkan

- Profil role dan tes target, template QA, Mobile Dev, IT BA, Umum, dan format CCAT-style, Bank-style, Kustom (F01).
- Diagnostik awal dan rencana latihan harian dari riwayat, kelemahan, dan kartu jatuh tempo (F02, F03).
- Engine soal Dart murni dengan solver dan property test 10.000 seed per tipe dan kesulitan: matriks 3x3, cermin, deret gambar, odd one out, deret angka, hitungan, soal cerita, silogisme (F04).
- Mode Latihan dan Simulasi dengan waktu dari deadline mutlak, pelanjutan sesi setelah app ditutup paksa (F05).
- Hasil dan pembahasan per soal, kuadran cepat-lambat (F06).
- Buku kesalahan dengan jadwal SM-2 sederhana: 1, 3, 7 hari, dikuasai setelah tiga benar berturut-turut (F07).
- Statistik mingguan dan bulanan, hari beruntun, ekspor CSV (F08).
- Capture soal dari tes asli (teks dan foto lokal) dan catatan psikotes perusahaan (F09, F10).
- Pengaturan, ekspor dan impor backup JSON tanpa CV dan key API (F11).
- Tiga integration_test (profil sampai statistik, buku kesalahan, Capture) dan pelari `tool/run_integration.sh`.
- Build web dan APK: `tool/prepare_web.sh` (sqlite3.wasm dan drift_worker.js), workflow `pages` (manual atau tag), workflow `release-apk` (tag `v*`, lampiran GitHub Releases).

### Diubah

- `applicationId` dan namespace Android menjadi `io.github.moanaku.psikotes` (sebelumnya `com.example.simulator_psikotes_it`). App yang dipasang dari build lama dianggap app lain oleh Android.

### Belum ada di rilis ini

- Soal verbal (bank 300 butir): skrip sudah ada, bank belum dibuat pemilik. Subtes verbal dilewati sampai bank terbundel.
- Tema gelap (T21): pemilih tema di Pengaturan masih menunggu.
- Ikon app masih ikon Flutter bawaan.
- Web di GitHub Pages: menunggu keputusan pemilik (repo privat).
