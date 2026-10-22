# 01. PRD

## Ringkasan

Simulator Psikotes IT adalah app Flutter offline-first untuk berlatih psikotes kerja IT. Soal dibuat ulang setiap sesi dari tipe, seed, dan tingkat kesulitan. Latihan disusun dari role yang dilamar, tes target, dan kelemahan pribadi. Simulasi wawancara berbasis CV dikerjakan paling akhir. Biaya proyek Rp0.

## Masalah

Pelamar IT fresh graduate menghadapi psikotes dengan format beragam (CCAT, TIU, Pauli, Papi, figural). Bahan latihan yang ada punya tiga kelemahan:

1. Bank soal tetap, sehingga yang terlatih hafalan jawaban, bukan pola.
2. Soal bergambar sering dikunci berbayar, padahal tipe ini paling sering membuat kaget.
3. Latihan generik, tidak disusun dari role, tes target, atau kelemahan pribadi.

Saat menemui tipe soal baru di tes asli, tidak ada tempat menyimpan dan melatihnya ulang. Wawancara juga dilatih dengan pertanyaan umum, bukan dari isi CV sendiri.

## Pengguna

Satu orang: pelamar IT (QA, Mobile/App Developer, IT BA) yang aktif melamar ke perusahaan besar di Indonesia. Pemilik proyek sekaligus pengguna tunggal. Tidak ada akun.

## Tujuan dan metrik

| Tujuan | Artinya | Metrik | Target awal |
|---|---|---|---|
| Produktivitas | Waktu belajar terpakai untuk latihan, bukan memilih materi | Menit latihan per minggu, sesi selesai per minggu | 5 sesi x 15 menit per minggu |
| Efektivitas | Latihan menaikkan skor | Akurasi dan waktu per soal per kategori, skor simulasi mingguan | Skor simulasi naik 15 poin persen dalam 4 minggu |
| Relevansi | Latihan sesuai tes dan role target | Porsi latihan yang sesuai blueprint tes target | Minimal 70% |

Definisi berhasil: dipakai sendiri minimal 4 minggu menjelang psikotes asli, dengan data sebelum dan sesudah tercatat di `10-laporan-hasil.md`.

## Scope

| Masuk | Nanti | Keluar |
|---|---|---|
| Psikotes kognitif (numerik, verbal, deret, figural, CCAT-style, Kraepelin/Pauli) | Suara (STT/TTS) di wawancara (F18) | Rilis Play Store |
| Kepribadian Papi/DISC-style dengan arti tiap opsi | OCR untuk Capture (F16) | Tes gambar proyektif (Wartegg, DAP, HTP) |
| Mode Latihan dan Simulasi | | Akun, login, server sendiri |
| Profil Role dan Tes, rencana harian, buku kesalahan, statistik | | Soal asli perusahaan di repo publik |
| Capture soal dari tes asli (manual dan foto) | | |
| Modul IT: pseudocode, flowchart, Excel | | |
| Bank Pengetahuan Role dan mode Umum tanpa role | | |
| Wawancara berbasis CV (persona HR dan User), teks dulu, dikerjakan paling akhir | | |

## Batasan

- Biaya Rp0: Flutter, GitHub, GitHub Actions, GitHub Pages, free tier LLM dengan key milik sendiri.
- Psikotes sepenuhnya offline. Hanya wawancara yang butuh internet.
- Distribusi: build web di GitHub Pages dan APK di GitHub Releases.
- Tidak menyalin soal SHL, CCAT, Papi Kostick, atau tes perusahaan. Yang ditiru hanya format, durasi, dan gaya.
- Interpretasi kepribadian bersifat edukatif, bukan diagnosis.

## Fitur dan rilis

| ID | Fitur | Rilis | Layar | User story |
|---|---|---|---|---|
| F01 | Profil Role dan Tes | v1 | S01, S02 | Sebagai pelamar, saya memilih role atau mode Umum tanpa role, format tes target, dan tanggal tes agar latihan sesuai tes yang akan saya hadapi |
| F02 | Diagnostik awal | v1 | S03 | Saya mengerjakan tes singkat lintas kategori agar app tahu kelemahan awal saya |
| F03 | Latihan hari ini | v1 | S04 | Saya membuka app dan langsung mendapat sesi 10-15 menit tanpa memilih materi |
| F04 | Engine soal kognitif | v1 | S05, S06 | Saya mendapat soal baru setiap sesi, termasuk soal bergambar, tanpa biaya |
| F05 | Mode Latihan dan Simulasi | v1 | S06, S07 | Saya bisa belajar santai dengan petunjuk, atau mencoba kondisi tes asli |
| F06 | Review dan pembahasan | v1 | S08, S09 | Setelah sesi, saya melihat jawaban benar, alasan, dan waktu per soal |
| F07 | Buku kesalahan | v1 | S10 | Soal yang salah muncul lagi beberapa hari kemudian sampai saya menguasainya |
| F08 | Statistik | v1 | S11 | Saya melihat akurasi, kecepatan, dan tren skor per kategori |
| F09 | Capture soal | v1 | S12 | Saat menemui tipe soal baru di tes asli, saya menyimpannya (teks atau foto) dan melatihnya ulang |
| F10 | Catatan psikotes perusahaan | v1 | S13 | Saya mencatat tes yang saya jalani agar profil tes makin akurat |
| F11 | Pengaturan dan backup | v1 | S18 | Saya bisa ekspor dan impor data lokal ke file JSON |
| F12 | Kepribadian Papi/DISC-style | v1.1 | S14 | Saya berlatih tes kepribadian dan memahami arti tiap pilihan saya |
| F13 | Kraepelin/Pauli penuh | v1.1 | S06 varian | Saya berlatih tes koran dengan durasi asli dan grafik konsistensi |
| F14 | Modul IT | v1.1 | S05, S06 | Saya berlatih soal pseudocode, flowchart, dan Excel yang relevan dengan role IT |
| F17 | Bank Pengetahuan Role | v1.1 | S19, S20 | Saya berlatih pertanyaan seputar role dari dasar sampai lanjut, lengkap dengan jawaban model |
| F16 | OCR untuk Capture | v1.2 | S12 | Saya memotret soal dari tes asli untuk diambil teksnya |
| F15 | Wawancara berbasis CV (teks) | v1.3 | S15, S16, S17 | Saya diwawancarai persona HR atau User berdasarkan CV dan lowongan saya |
| F18 | Suara di wawancara | v1.3 | S16 | Saya menjawab wawancara dengan suara dan dialog bergiliran |

Wawancara (F15, F18) dikerjakan paling akhir, setelah psikotes diuji sendiri (ADR-11). Desain layarnya sudah ada, tetapi kodenya baru dimulai di v1.3.

## Kriteria penerimaan

### F01 Profil Role dan Tes
- Bisa membuat lebih dari satu profil; satu profil aktif.
- Profil memuat role, daftar subtes, jumlah soal, durasi, bobot kategori, tanggal tes (opsional).
- Template awal: QA, Mobile Dev, IT BA, Umum (bobot rata), CCAT-style, Psikotes Bank-style.
- Mengubah profil langsung mengubah rencana harian dan komposisi simulasi.

### F02 Diagnostik
- Maksimal 20 menit, mencakup semua kategori aktif di profil.
- Hasil: akurasi dan median waktu per kategori, disimpan sebagai titik awal metrik.
- Bisa diulang kapan saja; hasil lama tetap tersimpan.

### F03 Latihan hari ini
- Bisa dimulai dengan satu ketukan dari beranda.
- Komposisi: kurang lebih 50% kategori terlemah, 30% kartu buku kesalahan jatuh tempo, 20% campuran sesuai bobot profil.
- Jika tanggal tes kurang dari 7 hari, porsi simulasi dinaikkan.

### F04 Engine soal
- Soal ditentukan oleh (tipe, seed, tingkat kesulitan); seed sama menghasilkan soal identik.
- Setiap soal punya tepat satu jawaban benar, dibuktikan oleh solver.
- Tidak ada dua opsi identik dalam satu soal.
- Membuat satu soal di bawah 50 ms di HP kelas menengah.
- Soal tidak berulang dalam 30 hari kecuali dari buku kesalahan.

### F05 Mode
- Latihan: timer bisa dimatikan; petunjuk dan pembahasan langsung setelah menjawab.
- Simulasi: timer per subtes, tidak bisa kembali ke subtes sebelumnya, pembahasan hanya di akhir.
- Jika app ditutup saat simulasi, sesi dilanjutkan dari posisi terakhir dengan sisa waktu yang benar.

### F06 Review
- Setiap soal menampilkan jawabanku, kunci, pembahasan, dan waktu.
- Soal dilabeli: benar-cepat, benar-lambat, salah-cepat, salah-lambat (ambang dari median waktu).

### F07 Buku kesalahan
- Soal salah otomatis masuk; jadwal ulang 1, 3, 7, 14 hari (SM-2 sederhana, lihat `03-data-model.md`).
- Keluar dari buku setelah 3 kali benar berturut-turut.
- Ulangan memakai soal setipe dengan seed baru, bukan soal yang sama persis, kecuali soal Capture.

### F08 Statistik
- Grafik skor simulasi per minggu, akurasi dan waktu per kategori, streak.
- Ekspor CSV untuk bahan laporan hasil.

### F09 Capture
- Input: teks soal, 2-6 opsi, kunci, pembahasan (opsional), kategori, foto (opsional).
- Data hanya lokal; ada peringatan agar tidak membagikan soal asli.
- Soal Capture bisa masuk latihan dan buku kesalahan.

### F10 Catatan psikotes perusahaan
- Catatan memuat perusahaan, tanggal, subtes yang keluar, catatan bebas, dan tag tipe baru.
- Dari catatan, app menyarankan latihan untuk tipe baru yang muncul.

### F11 Pengaturan dan backup
- Ekspor dan impor semua data ke satu berkas JSON; impor tidak menghilangkan data.
- API key wawancara disimpan terenkripsi di Android; di web hanya di sesi browser.

### F12 Kepribadian
- Pool 10-20 pernyataan per sifat; setiap sesi memasangkan dua sifat berbeda secara acak.
- Tidak ada skor benar-salah. Review menampilkan arti pilihan, profil akhir, dan sifat yang umumnya dicari tiap role.

### F15 Wawancara (ringkas, detail di `02-arsitektur.md`)
- Data pribadi (nomor HP, email, alamat) dihapus sebelum dikirim ke LLM.
- Setiap pertanyaan merujuk ke isi CV atau lowongan.
- Tanpa internet atau kuota habis, app beralih ke kartu pertanyaan template.
- Laporan memuat skor per aspek, peta klaim CV, dan pertanyaan lemah yang masuk buku kesalahan.

### F17 Bank Pengetahuan Role
- Tiap role punya tiga level: Dasar, Menengah, Lanjut. Mode Umum menampilkan topik lintas role.
- Setiap butir menampilkan pertanyaan, jawaban model, dan poin kunci; level Lanjut dinilai dengan poin kunci, bukan satu jawaban benar.
- Butir yang ditandai belum paham masuk buku kesalahan dengan jadwal SM-2 yang sama.
- Seluruh bank berjalan offline dari berkas JSON yang dibundel; butir tanpa sumber ditandai perlu verifikasi.

## Kebutuhan nonfungsional

- Offline penuh untuk psikotes; data hanya di perangkat.
- Android 8+ dan web (Chrome); layar 360 dp ke atas.
- Kontras teks minimal 4,5 : 1; soal figural tidak bergantung pada warna saja.
- Target sentuh minimal 48 dp; fokus keyboard terlihat di web; gerak mengikuti reduced motion.
- Startup di bawah 2 detik.
- Tema terang dulu; tema gelap menyusul (token sudah disiapkan).
