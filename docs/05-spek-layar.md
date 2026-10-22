# 05. Spesifikasi layar

Dua puluh layar, dikelompokkan seperti kanvas desain. Tampilan visual ada di artefak desain; berkas ini menetapkan rute, data, aksi, kondisi, dan kriteria selesai. Teks dalam kurung siku (`[n]`, `[skor]`, `[mm:ss]`, `[dtk]`, `[nama]`) adalah tempat data asli.

Kondisi standar (lihat `04-sistem-desain.md`): **kosong**, **memuat** (skeleton), **galat** (sebab dan "Coba lagi"), **offline** (hanya wawancara). Layar tanpa baris Kondisi di bawah ini hanya punya tampilan normal.

## Peta rute

| ID | Rute | Layar | Fitur | Rilis | Papan desain |
|---|---|---|---|---|---|
| S01 | `/onboarding/role` | Pilih role | F01 | v1 | Main |
| S02 | `/onboarding/profil` | Profil tes target | F01 | v1 | S02 |
| S03 | `/onboarding/diagnostik` | Diagnostik | F02 | v1 | S03 |
| S04 | `/` (tab Beranda) | Beranda | F03 | v1 | S04 |
| S05 | `/psikotes` (tab Psikotes) | Katalog psikotes | F04 | v1 | S05 |
| S06 | `/sesi/:id` mode latihan atau diagnostik | Sesi soal | F04, F05 | v1 | S06 |
| S07 | `/sesi/:id` mode simulasi | Sesi simulasi | F05 | v1 | S07 |
| S08 | `/hasil/:id` | Hasil sesi | F06 | v1 | S08 |
| S09 | `/hasil/:id/soal/:n` | Pembahasan soal | F06 | v1 | S09 |
| S10 | `/buku-kesalahan` | Buku kesalahan | F07 | v1 | S10 |
| S11 | `/statistik` (tab Statistik) | Statistik | F08 | v1 | S11 |
| S12 | `/capture`, `/capture/:id` | Capture soal | F09 | v1 | S12 |
| S13 | `/catatan-tes` | Catatan psikotes | F10 | v1 | S13 |
| S14 | `/kepribadian/:id` | Sesi kepribadian | F12 | v1.1 | S14 |
| S15 | `/wawancara` (tab Wawancara) | Setup wawancara | F15 | v1.3 | S15 |
| S16 | `/wawancara/:id` | Dialog wawancara | F15, F18 | v1.3 | S16 |
| S17 | `/wawancara/:id/laporan` | Laporan wawancara | F15 | v1.3 | S17 |
| S18 | `/pengaturan` | Pengaturan | F11 | v1 | S18 |
| S19 | `/pengetahuan` | Bank pengetahuan role | F17 | v1.1 | S19 |
| S20 | `/pengetahuan/sesi/:id` | Sesi kartu pengetahuan | F17 | v1.1 | S20 |

Aturan umum:
- Sesi (S06, S07, S14, S16, S20) layar penuh tanpa bottom nav. Keluar lewat tombol tutup dengan konfirmasi jika ada jawaban yang belum tersimpan (sesi disimpan per jawaban, jadi konfirmasi hanya menawarkan "Lanjutkan nanti").
- Bottom nav tampil di S04, S05, S11, S15, S19.
- Jika belum ada profil aktif, semua rute selain `/onboarding/*` dialihkan ke `/onboarding/role`.

---

## Kelompok 1. Setup dan beranda

### S01 Pilih role (F01)
- **Tujuan:** memilih role atau mode Umum.
- **Elemen:** indikator "Langkah 1 dari 3"; judul "Kamu melamar sebagai apa?"; lima `ChoiceRow` (QA Engineer, Mobile / App Developer, IT Business Analyst, Umum tanpa role, Lainnya); catatan "Bisa membuat lebih dari satu profil nanti."; tombol "Lanjut".
- **Data:** menulis `role` sementara ke state onboarding (belum ke database).
- **Aksi:** "Lanjut" ke S02. Satu pilihan aktif; default QA Engineer.
- **Penjelasan tiap role:** QA: ketelitian, logika deduktif, Kraepelin/Pauli. Mobile Dev: figural induktif, pseudocode, numerik. IT BA: verbal, bacaan, tabel data, silogisme. Umum: semua kategori dengan bobot rata. Lainnya: atur bobot sendiri di S02.
- **Selesai bila:** memilih role mengubah bobot template yang tampil di S02; tombol "Lanjut" selalu aktif karena ada default.

### S02 Profil tes target (F01)
- **Tujuan:** menetapkan format tes, subtes, tanggal, nama profil, CV.
- **Elemen:** "2 / 3"; chip format tes (CCAT-style, Psikotes Bank-style, Kustom); daftar subtes dengan kotak centang, jumlah soal, menit (Verbal, Numerik, Logika, Figural, Kraepelin / Pauli dengan "kolom", Kepribadian dengan "item"); tanggal tes (opsional); nama profil; "CV untuk wawancara" dengan "Tempel CV"; tombol "Simpan dan lanjut".
- **Data:** menulis `test_profile` (aktif = 1) dan `blueprint_json`. Memilih format tes mengisi subtes dari blueprint di `06-bank-konten.md`.
- **Aksi:** "Simpan dan lanjut" ke S03; kembali ke S01. Dari S18 layar ini dibuka dalam mode ubah profil dan "Simpan dan lanjut" menjadi "Simpan profil".
- **Validasi:** minimal satu subtes aktif; jumlah soal 1 sampai 200; menit 1 sampai 180; nama profil diisi otomatis ("QA, CCAT-style") jika kosong; tanggal tes tidak boleh di masa lalu.
- **Galat:** "Pilih minimal satu subtes agar latihan bisa disusun." Tampil di bawah daftar subtes.
- **Selesai bila:** profil tersimpan dan menjadi aktif; mengubah profil mengubah rencana harian di S04 pada kunjungan berikutnya.

### S03 Diagnostik (F02)
- **Tujuan:** pengantar, progres, dan pratinjau hasil diagnostik.
- **Elemen:** "3 / 3"; "Kenali titik awalmu"; "Maksimal 20 menit. Hasilnya menentukan urutan latihan pertamamu."; daftar progres per subtes (Selesai, Berjalan, Belum); pratinjau hasil per kategori dengan `ScoreBar` dan penanda "Terlemah"; tautan "Ke beranda"; tombol "Lewati, nanti saja" dan "Mulai diagnostik".
- **Data:** membuat `session` mode `diagnostik`; hasil akhir disimpan sebagai titik awal metrik (akurasi dan median per kategori).
- **Aksi:** "Mulai diagnostik" ke S06 (mode diagnostik); "Lewati, nanti saja" dan "Ke beranda" ke S04.
- **Kondisi:** sesudah selesai, layar menampilkan hasil nyata menggantikan pratinjau, tombol utama menjadi "Ke beranda". Diagnostik bisa diulang dari S18.
- **Selesai bila:** diagnostik yang terputus bisa dilanjutkan; hasil lama tetap tersimpan saat diulang.

### S04 Beranda (F03)
- **Tujuan:** satu ketukan menuju latihan hari ini.
- **Elemen:** "Halo, [nama]" dan ikon pengaturan; baris profil aktif dengan "[n] hari lagi"; panel "Latihan hari ini" (± menit, tiga butir rencana, tombol "Mulai"); "Kelemahan saat ini" dengan tiga `ScoreBar` dan tautan "Statistik"; empat pintasan (Katalog psikotes, Pengetahuan role, Capture soal, Buku kesalahan dengan "[n] jatuh tempo"); bottom nav.
- **Data:** profil aktif, `DailyPlanner.plan()`, kelemahan (tiga tipe dengan skor tertinggi), jumlah kartu jatuh tempo.
- **Aksi:** "Mulai" ke S06 dengan sesi dari rencana; ikon pengaturan ke S18; pintasan ke S05, S19, S12, S10; "Statistik" ke S11.
- **Kondisi:**
  - Kosong (belum ada riwayat): "Belum ada data kelemahan. Kerjakan diagnostik agar latihan hari ini bisa disusun." Tombol: "Mulai diagnostik". Panel latihan tetap ada dengan campuran sesuai bobot profil.
  - Memuat: skeleton untuk baris profil, panel, dan tiga baris kelemahan.
  - Galat: "Rencana latihan tidak bisa disusun. Data profil gagal dibaca." Tombol: "Coba lagi".
  - Tanpa tanggal tes: baris profil menampilkan "Tanggal tes belum diisi" dengan tautan ke S02.
- **Selesai bila:** dari buka app sampai soal pertama tampil butuh satu ketukan; rencana memenuhi komposisi 50/30/20 di `03-data-model.md`.

---

## Kelompok 2. Latihan psikotes

### S05 Katalog psikotes (F04)
- **Tujuan:** memilih tipe soal untuk latihan atau memulai simulasi penuh.
- **Elemen:** judul "Psikotes"; kontrol segmen Latihan atau Simulasi; kelompok Numerik dan logika, Figural, Verbal, Ketelitian dan kepribadian, Modul IT, Pengetahuan role, Bank pribadi; tag "v1.1" untuk yang belum tersedia; panel bawah "Simulasi penuh" dengan "Mulai simulasi"; bottom nav.
- **Data:** katalog dari `QuestionType` yang terdaftar; jumlah soal Capture.
- **Aksi:** baris tipe soal ke S06 (mode latihan, tipe terpilih, tingkat default sedang); "Mulai simulasi" ke S07 memakai profil aktif; baris Papi-style ke S14; baris Pengetahuan role ke S19; "Soal hasil Capture" membuka sesi dari bank pribadi.
- **Aturan:** tipe yang belum dirilis tampil dengan tag dan tidak bisa dibuka (tombol nonaktif dengan penjelasan "Tersedia di v1.1").
- **Kondisi:** Bank pribadi kosong: "Belum ada soal Capture. Simpan soal dari tes asli lewat Capture soal." Tombol: "Buka Capture".

### S06 Sesi soal, latihan (F04, F05)
- **Tujuan:** mengerjakan soal satu per satu dengan petunjuk.
- **Elemen:** tombol tutup; judul tipe soal dan "Mode Latihan"; timer "[mm:ss]" (bisa dimatikan); deretan nomor soal; instruksi; stimulus soal (matriks 3x3 digambar `CustomPainter`); opsi A sampai F dalam kisi 3 x 2; tombol "Buka petunjuk" dan "Kirim jawaban [huruf]".
- **Data:** soal dari `QuestionGenerator.generate(seed, difficulty)`; menulis `answer` setiap jawaban; sesi disimpan per jawaban.
- **Aksi:** "Kirim jawaban" mencatat jawaban, menampilkan benar atau salah dengan pembahasan singkat (mode latihan), lalu soal berikutnya; setelah soal terakhir ke S08. Tutup kembali ke S05 atau S04.
- **Perilaku:** di mode latihan tombol "Kirim" tidak aktif sebelum ada opsi terpilih; petunjuk menampilkan aturan soal tanpa menyebut jawaban. Opsi figural tidak bergantung pada warna (bentuk, jumlah, isian).
- **Kondisi:** galat pembuatan soal (semua 20 percobaan gagal): "Soal tidak bisa dibuat. Coba tipe lain atau ulangi sesi." Tombol: "Ulangi". Kasus ini dicatat sebagai bug engine (lihat `08-rencana-tes.md`).
- **Selesai bila:** seed sama menampilkan soal identik; menutup app lalu membuka lagi melanjutkan dari soal terakhir.

### S07 Sesi simulasi (F05)
- **Tujuan:** kondisi tes asli.
- **Elemen:** tutup; "Simulasi QA CCAT-style" dan timer; langkah subtes (Verbal selesai, Numerik sekarang, Logika, Figural); "Subtes 2 dari 4, soal 7 dari 20"; kisi nomor soal 1 sampai 20; soal dan opsi A sampai D; catatan "Tidak bisa kembali ke subtes Verbal. Pembahasan muncul setelah simulasi selesai."; "Sebelumnya" dan "Berikutnya".
- **Data:** `session.deadline` sebagai batas waktu mutlak subtes berjalan; `session.posisi`.
- **Perilaku:** timer per subtes; saat habis subtes berpindah otomatis dengan pesan singkat; navigasi bebas di dalam subtes, tidak bisa kembali ke subtes sebelumnya; tidak ada pembahasan.
- **Aksi:** "Berikutnya" di soal terakhir subtes terakhir menyelesaikan sesi dan ke S08.
- **Selesai bila:** menutup paksa app lalu membuka lagi menampilkan posisi dan sisa waktu yang benar dari `deadline`.

### S08 Hasil sesi (F06)
- **Tujuan:** ringkasan skor dan pola kecepatan.
- **Elemen:** `[skor]%` dan "QA, CCAT-style"; "Sesi lalu [skor]%, durasi [mm:ss]"; "Per kategori" dengan akurasi dan median; "Kecepatan vs ketepatan" (`QuadrantGrid`: benar dan cepat, benar tapi lambat, salah dan cepat dengan "Terburu-buru", salah dan lambat dengan "Belum paham pola"); "[n] soal salah masuk buku kesalahan dan dijadwalkan ulang besok."; tombol "Beranda" dan "Lihat pembahasan".
- **Data:** `answer` sesi ini; menulis `mistake_card` untuk setiap jawaban salah (F07); `session.skor`.
- **Aksi:** "Lihat pembahasan" ke S09 (soal pertama yang salah); "Beranda" ke S04.
- **Selesai bila:** keempat sel menjumlah ke total soal; setiap soal salah punya kartu.

### S09 Pembahasan soal (F06)
- **Tujuan:** memahami satu soal.
- **Elemen:** strip nomor soal (benar atau salah, salah bergaris putus, sekarang berkontur tebal); jenis dan stimulus soal; blok "Salah, Jawabanmu" dan "Kunci"; "Kenapa" dengan penjelasan dan rangkaian selisih; "Pola dan trik"; "Waktumu [dtk], target [dtk]"; sakelar "Masuk buku kesalahan"; "Sebelumnya" dan "Berikutnya".
- **Data:** soal dibuat ulang dari `(tipe, seed, kesulitan)`; pembahasan dari `Question.explanation`.
- **Aksi:** sakelar menambah atau menghapus kartu buku kesalahan; navigasi antar soal.
- **Selesai bila:** pembahasan otomatis ada untuk semua tipe soal (diuji di property test: `explanation` tidak kosong).

---

## Kelompok 3. Belajar ulang, data, dan pengaturan

### S10 Buku kesalahan (F07)
- **Tujuan:** mengulang kartu yang jatuh tempo.
- **Elemen:** judul; dua angka "[n] jatuh tempo hari ini" dan "[n] sudah dikuasai"; tombol "Ulangi yang jatuh tempo"; chip filter Semua, Psikotes, Capture, Wawancara; baris kartu dengan nama, sumber, tag jatuh tempo ("Hari ini" distabilo), dan tiga titik penguasaan.
- **Data:** `mistake_card` urut `jatuh_tempo`.
- **Aksi:** "Ulangi yang jatuh tempo" ke S06 dengan kartu jatuh tempo; baris kartu membuka pembahasan.
- **Kondisi:**
  - Kosong pertama kali: "Buku kesalahan masih kosong. Soal yang salah akan masuk ke sini dan muncul lagi beberapa hari kemudian." Tombol: "Mulai latihan".
  - Filter kosong: "Tidak ada kartu [sumber] yang jatuh tempo." Tombol: "Tampilkan semua".
  - Semua sudah dikerjakan hari ini: "Tidak ada kartu jatuh tempo hari ini. Kartu berikutnya muncul [tanggal]."
- **Selesai bila:** jadwal mengikuti tangga 1, 3, 7 hari dan keluar setelah 3 benar berturut-turut.

### S11 Statistik (F08)
- **Tujuan:** melihat tren.
- **Elemen:** judul; kontrol segmen Mingguan atau Bulanan; tiga angka ("[n] menit minggu ini", "[n] sesi selesai", "[n] hari beruntun"); grafik garis "Skor simulasi per minggu" (fl_chart); "Per kategori" dengan akurasi dan median; tombol "Ekspor CSV untuk laporan hasil"; bottom nav.
- **Data:** agregasi `answer` dan `session`.
- **Aksi:** "Ekspor CSV" membagikan berkas CSV (kolom: tanggal, mode, skor, kategori, akurasi, median detik).
- **Kondisi:**
  - Kosong: "Belum ada sesi. Statistik muncul setelah sesi pertama selesai." Tombol: "Mulai latihan".
  - Grafik dengan satu titik: tampilkan titik tunggal dan teks "Butuh minimal dua simulasi untuk melihat tren."
  - Memuat: skeleton untuk tiga angka, grafik, dan empat baris kategori.
- **Selesai bila:** angka sama dengan hasil kueri langsung; CSV bisa dibuka di spreadsheet dengan koma sebagai pemisah dan UTF-8.

### S12 Capture soal (F09)
- **Tujuan:** menyimpan soal dari tes asli.
- **Elemen:** catatan privasi "Disimpan hanya di HP ini dan tidak ikut ke repo. Jangan bagikan soal asli perusahaan."; kategori dengan "Tipe baru"; foto soal (opsional); teks soal; opsi A sampai D dengan penanda kunci; "Hubungkan ke catatan tes"; tombol "Simpan ke bank pribadi".
- **Data:** menulis `captured_question`; foto disalin ke penyimpanan lokal app.
- **Validasi:** teks soal atau foto wajib salah satu; minimal 2 opsi terisi; kunci wajib dipilih dan menunjuk opsi yang terisi.
- **Galat:** "Kunci jawaban belum dipilih. Pilih lingkaran di kiri opsi yang benar." Tampil di dekat opsi.
- **Aksi:** "Simpan ke bank pribadi" kembali ke layar asal; soal masuk S05 (Bank pribadi) dan bisa masuk buku kesalahan.
- **Selesai bila:** soal Capture bisa dikerjakan di sesi latihan dan tidak pernah ikut ke ekspor repo atau log.

### S13 Catatan psikotes (F10)
- **Tujuan:** mencatat tes asli yang pernah dijalani.
- **Elemen:** pengantar; tombol "Tambah catatan tes"; daftar catatan (nama, tag subtes, tag "Tipe baru" distabilo, catatan, "Tambah soal"); kotak "Saran dari catatanmu".
- **Data:** `company_test_log`; saran dihitung dari tag tipe baru yang belum punya soal Capture.
- **Aksi:** "Tambah soal" ke S12 dengan catatan terhubung.
- **Kondisi:** kosong: "Belum ada catatan tes. Catat tes yang kamu jalani agar profil tes makin akurat." Tombol: "Tambah catatan tes".

### S18 Pengaturan (F11)
- **Tujuan:** profil, data, wawancara AI, tampilan.
- **Elemen:** Profil tes (profil aktif, kelola profil); Data (ekspor dan impor backup JSON); Wawancara AI (penyedia Gemini atau Groq, API key, batas sesi per hari); Tampilan (tema Terang, Gelap, Sistem); disclaimer.
- **Aksi:** profil aktif ke S02 (mode ubah); ekspor membagikan berkas JSON; impor memilih berkas lalu menampilkan ringkasan sebelum menggabungkan.
- **Galat:**
  - Berkas impor salah: "Backup tidak bisa dibaca. Berkasnya bukan hasil ekspor dari app ini. Pilih berkas lain."
  - Versi lebih baru: "Backup dibuat oleh versi app yang lebih baru. Perbarui app lalu coba lagi."
- **Catatan privasi:** API key "Disimpan terenkripsi di perangkat, tidak pernah ke server kami." Di web: "Key hanya disimpan selama tab ini terbuka."
- **Selesai bila:** ekspor lalu impor di perangkat bersih mengembalikan semua tabel; key tidak ada di berkas ekspor.

---

## Kelompok 4. Kepribadian dan pengetahuan role (v1.1)

### S14 Sesi kepribadian (F12)
- **Tujuan:** memilih pernyataan yang paling menggambarkan diri, lalu memahami artinya.
- **Elemen:** judul "Papi-style" dan "Soal [n] dari [total]"; bilah progres; "Pilih yang paling menggambarkan dirimu."; dua `OptionTile` (A dan B); catatan "Tidak ada jawaban benar"; review: "Arti pilihanmu di soal [n]", "Profil kecenderungan", keterangan sifat yang umumnya dicari untuk role.
- **Data:** `personality_pool.json`; `answer` tanpa `benar` (diabaikan); profil akhir dihitung dari tag sifat.
- **Aturan:** tidak ada warna benar atau salah; teks menyebut "edukatif, bukan diagnosis".

### S19 Bank pengetahuan role (F17)
- **Tujuan:** memilih role, level, dan topik.
- **Elemen:** chip role (QA, Mobile Dev, IT BA, Umum); penjelasan; tiga baris level (Dasar, Menengah, Lanjut) dengan "[n] dari [n] dikuasai" dan bilah progres; chip topik; "Latihan 10 kartu"; bottom nav.
- **Data:** `knowledge_bank.json`, `knowledge_progress`.
- **Aksi:** baris level atau tombol ke S20.
- **Kondisi:** topik tanpa butir: "Belum ada kartu untuk topik ini. Pilih topik lain." Tombol: "Tampilkan semua topik".

### S20 Sesi kartu (F17)
- **Tujuan:** menjawab, membuka jawaban model, menilai diri.
- **Elemen:** "[role], level [level]" dan "Kartu [n] dari 10"; topik dan pertanyaan; isian jawaban (boleh dilewati); "Jawaban model"; "Poin kunci" dengan kotak centang; tombol "Belum paham" dan "Sudah paham".
- **Perilaku:** jawaban model tertutup sampai pengguna menekan "Buka jawaban" (papan desain menampilkan keadaan terbuka); level Lanjut menilai dengan poin kunci yang dicentang; "Belum paham" membuat kartu buku kesalahan sumber `pengetahuan`.

---

## Kelompok 5. Wawancara berbasis CV (v1.3)

Tahap awal hanya UI sesuai papan desain: layar bisa dibuka dengan data contoh dan tidak memanggil layanan luar. Logika (F15, F18) dikerjakan terakhir.

### S15 Setup wawancara
- **Elemen:** judul dan "sisa [n] / 3 hari ini"; pilihan pewawancara (HR atau User teknis); CV tersimpan dengan "Ubah"; deskripsi lowongan; bahasa (Indonesia, English, Campuran); mode (Latihan, Simulasi); catatan "Nomor HP, email, dan alamat dihapus sebelum CV dikirim ke AI. Tanpa internet, app memakai kartu pertanyaan template."; "Mulai wawancara"; bottom nav.
- **Kondisi:**
  - Belum ada key: "Wawancara butuh API key Gemini atau Groq milikmu." Tombol: "Isi key di Pengaturan".
  - Batas harian habis: "Batas 3 sesi hari ini sudah terpakai. Pakai kartu pertanyaan template atau coba lagi besok."
  - Offline: "Tidak ada internet. Wawancara memakai kartu pertanyaan template. Psikotes tetap jalan seperti biasa." Tombol: "Pakai kartu template".

### S16 Dialog wawancara
- **Elemen:** judul persona dan "Topik [n] dari 7, mode [mode]"; "Akhiri"; bilah topik; gelembung pewawancara dan pengguna; petunjuk (hanya mode Latihan); penanda mengetik; isian jawaban; tombol suara (nonaktif sampai v1.3, F18) dan kirim.
- **Kondisi galat:** "Pewawancara tidak menjawab. Jawabanmu tersimpan. Coba kirim lagi." Tombol: "Kirim ulang".

### S17 Laporan wawancara
- **Elemen:** "Skor per aspek" (Struktur STAR, Kespesifikan, Relevansi, Kejelasan, skala 1 sampai 5); "Peta klaim CV" dengan tag Kuat atau Goyah; "Saran perbaikan CV"; "[n] pertanyaan lemah masuk buku kesalahan."; "Lihat transkrip" dan "Selesai".
- **Data:** `interview_session.laporan_json`; pertanyaan lemah membuat kartu buku kesalahan sumber `wawancara`.

---

## Daftar tautan antar layar (untuk uji navigasi)

| Dari | Aksi | Ke |
|---|---|---|
| S01 | Lanjut | S02 |
| S02 | Simpan dan lanjut | S03 |
| S03 | Mulai diagnostik | S06 |
| S03 | Lewati, Ke beranda | S04 |
| S04 | Mulai | S06 |
| S04 | Pintasan | S05, S19, S12, S10 |
| S04 | Ikon pengaturan | S18 |
| S04 | Statistik | S11 |
| S05 | Matriks 3x3 (tipe soal) | S06 |
| S05 | Mulai simulasi | S07 |
| S05 | Papi-style | S14 |
| S05 | Pengetahuan role | S19 |
| S06 | Kirim jawaban (soal terakhir) | S08 |
| S07 | Berikutnya (soal terakhir) | S08 |
| S08 | Lihat pembahasan | S09 |
| S08 | Beranda | S04 |
| S10 | Ulangi yang jatuh tempo | S06 |
| S12 | Hubungkan ke catatan tes | S13 |
| S12 | Simpan ke bank pribadi | S05 |
| S13 | Tambah soal | S12 |
| S18 | Profil aktif | S02 |
| S19 | Latihan 10 kartu | S20 |
| S15 | Mulai wawancara | S16 |
| S16 | Akhiri | S17 |
| S17 | Selesai | S04 |
