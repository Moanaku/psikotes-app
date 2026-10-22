# 07. Rencana tugas untuk Claude Code

Tiap tugas adalah satu pull request kecil. Setiap tugas memuat rekomendasi model, berkas yang disentuh, kriteria selesai, dan prompt siap tempel.

## Cara memakai

1. Buka Claude Code di akar repo. `CLAUDE.md` terbaca otomatis.
2. Pilih model sesuai tugas (`/model`). Rekomendasi ada di baris **Model** tiap tugas.
3. Tempel isi **Prompt**. Setiap prompt sudah menyebut dokumen yang harus dibaca.
4. Tinjau diff, jalankan `flutter analyze` dan `flutter test`, lalu merge lewat pull request dengan CI hijau.
5. Centang tugas di `docs/progress.md` (buat saat T01) dan perbarui dokumen terkait kalau ada keputusan baru.

## Panduan model

| Model | Pakai untuk | Alasan |
|---|---|---|
| Opus 5.5 | Engine, solver, penjadwalan waktu sesi, desain prompt dan evaluasi LLM | Logika yang mudah salah secara halus; biaya salah tinggi |
| Sonnet 5.5 | Hampir semua layar, repository, tema, CI, skrip | Cukup kuat untuk kode terstruktur, lebih hemat kuota langganan |
| Haiku 5.5 | Perubahan mekanis: ganti nama, CHANGELOG, pembaruan dokumen, tabel | Cepat dan murah untuk pekerjaan yang jelas bentuknya |

Aturan praktis: mulai dengan model yang direkomendasikan; naikkan ke Opus hanya jika tes gagal berulang dan akar masalahnya logika, bukan sintaks. Langganan Claude memiliki batas pemakaian, jadi Opus dipakai hanya pada tugas yang ditandai.

## Aturan umum tiap tugas

- Cabang `fitur/Txx-nama-singkat`; pesan commit memuat ID tugas dan ID fitur (contoh: `T04 F04: generator FIG-MTX`).
- Test ditulis bersama kodenya. Bug engine yang ditemukan menjadi test baru sebelum diperbaiki.
- Tidak ada warna, jarak, radius, atau ukuran teks di luar token (`04-sistem-desain.md`).
- Layar data wajib punya empat kondisi (kosong, memuat, galat, offline untuk wawancara) dengan teks dari `05-spek-layar.md`.
- Definition of Done: kode di-merge lewat pull request; test otomatis ditulis dan CI hijau; dicoba di HP Android dan di browser; kriteria penerimaan fitur di `01-prd.md` terpenuhi; dokumen atau CHANGELOG diperbarui.

---

# Rilis v1 (inti latihan offline)

## T01 Verifikasi kerangka repo dan CI
- **Fitur:** pondasi. **Bergantung pada:** tidak ada.
- **Model:** Sonnet 5.5. Pekerjaan konfigurasi dan perbaikan versi paket; tidak butuh penalaran berat.
- **Tujuan:** kerangka yang ada belum pernah dikompilasi. Pastikan `flutter pub get`, `flutter analyze`, dan `flutter test` hijau, perbaiki versi paket, dan aktifkan CI serta GitHub Pages.
- **Berkas:** `pubspec.yaml`, `packages/question_engine/pubspec.yaml`, `analysis_options.yaml`, `.github/workflows/ci.yml`, `docs/progress.md`.
- **Selesai bila:** CI hijau di `main`; `dart test -p vm,chrome` di `packages/question_engine` lulus (termasuk nilai emas `Rng`); halaman web kosong terbit di GitHub Pages.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/02-arsitektur.md, dan docs/07-rencana-tugas.md (aturan umum).
  Kerangka repo ini ditulis tanpa Flutter terpasang, jadi belum pernah dikompilasi.
  Jalankan flutter pub get, flutter analyze, flutter test, lalu dart test -p vm,chrome
  di packages/question_engine. Perbaiki semua galat (versi paket, API yang berubah,
  impor). Jangan menambah fitur. Aktifkan workflow CI dan deploy GitHub Pages.
  Buat docs/progress.md berisi daftar T01 sampai T32 dengan kotak centang. Laporkan
  versi paket final dan apa saja yang kamu ubah dari kerangka awal.
  ```

## T02 Tema, token, dan komponen inti
- **Fitur:** pondasi UI. **Bergantung pada:** T01.
- **Model:** Sonnet 5.5. Menerjemahkan token dan spesifikasi komponen ke widget, banyak keputusan sudah tertulis.
- **Tujuan:** bundel font, `ThemeData` dari token (terang), komponen inti, dan widget kondisi.
- **Berkas:** `assets/fonts/`, `lib/core/theme/`, `lib/core/widgets/` (AppButton, AppIconButton, AppTopBar, AppBottomNav, ListRow, ChoiceRow, OptionTile, AppChip, SegmentedControl, NumberBubble, ScoreBar, StatusTag, NoteBox, AppTextField, StatRow, QuadrantGrid, EmptyView, SkeletonList, ErrorView, OfflineView), `test/core/` golden test.
- **Selesai bila:** setiap komponen punya golden test; tidak ada hex mentah atau `Colors.*` di `lib/` kecuali `app_tokens.dart` (diperiksa skrip `tool/check_tokens.sh`); semua target sentuh 48 dp; ikon punya label semantik.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/04-sistem-desain.md, docs/design/tokens.json, dan
  lib/core/theme/app_tokens.dart. Bundel font Instrument Sans (OFL) ke assets/fonts
  lalu daftarkan di pubspec.yaml. Bangun ThemeData terang secara eksplisit dari
  token (tanpa ColorScheme.fromSeed, tanpa dynamic color) dan semua komponen di
  bagian "Komponen inti". Tambahkan skala TextTheme penuh dengan angka tabular.
  Tulis golden test untuk tiap komponen dan skrip tool/check_tokens.sh yang gagal
  jika ada hex mentah, Colors.*, atau angka jarak di luar skala di lib/ (selain
  app_tokens.dart). Jangan membuat komponen di luar daftar; tanya dulu jika perlu.
  ```

## T03 Engine: Rng, model, antarmuka generator
- **Fitur:** F04. **Bergantung pada:** T01.
- **Model:** Opus 5.5. Fondasi determinisme lintas platform; kesalahan di sini merusak semua soal.
- **Tujuan:** `Rng` final, model `Question`, `Option`, `Difficulty`, `QuestionType`, `FigureSpec`, antarmuka `QuestionGenerator` dan `QuestionSolver`, `GenerationFailure`, dan harness property test bersama.
- **Berkas:** `packages/question_engine/lib/src/{rng,models,figure_spec,generator}.dart`, `test/`.
- **Selesai bila:** nilai emas `Rng` sama di VM dan Chrome; serialisasi JSON `Question` bolak-balik identik; harness property test (`glados`) menerima generator mana pun dan menjalankan invarian di `08-rencana-tes.md`.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/02-arsitektur.md (bagian Determinisme engine dan Antarmuka
  inti) dan docs/06-bank-konten.md (Format soal dan FigureSpec). Selesaikan
  packages/question_engine: Rng (xorshift32 dengan penyamaran 32 bit, metode
  nextInt(max), nextBool, pick, shuffle, derive(seed, attempt)), model Question
  dengan toJson/fromJson, FigureSpec, antarmuka generator dan solver. Tulis test
  nilai emas yang identik di VM dan Chrome. Buat harness property test yang
  menerima QuestionGenerator + QuestionSolver dan memeriksa semua invarian di
  docs/08-rencana-tes.md. Jangan memakai dart:math Random atau DateTime di engine.
  ```

## T04 Generator FIG-MTX, solver, property test
- **Fitur:** F04. **Bergantung pada:** T03.
- **Model:** Opus 5.5. Bagian paling berisiko: pembuktian tepat satu jawaban benar dan pengecoh yang melanggar tepat satu aturan.
- **Tujuan:** generator matriks 3x3 dengan 1 sampai 3 aturan, pengecoh, solver, dan pembahasan.
- **Berkas:** `packages/question_engine/lib/src/generators/figural/fig_mtx.dart`, `solver`, `test/fig_mtx_test.dart`.
- **Selesai bila:** 10.000 seed per kesulitan lolos semua invarian; pembuatan satu soal di bawah 50 ms (diukur di VM); pembahasan menyebut aturan per baris dan kolom.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md bagian "FIG-MTX (matriks 3x3), spesifikasi
  lengkap". Implementasikan generator, solver, dan pembuat pengecoh persis sesuai
  spesifikasi. Tulis property test 10.000 seed per tingkat kesulitan (easy, medium,
  hard): tepat satu opsi lolos solver, tidak ada opsi kembar, determinisme, posisi
  kunci tersebar merata, pembahasan tidak kosong, waktu pembuatan di bawah 50 ms.
  Jika ada seed yang gagal, jangan melonggarkan invarian; perbaiki generatornya.
  Laporkan berapa persen soal membutuhkan percobaan ulang.
  ```

## T05 Generator FIG-MIR, FIG-SEQ, FIG-ODD
- **Fitur:** F04. **Bergantung pada:** T04.
- **Model:** Sonnet 5.5. Pola sudah ditetapkan di T04; tinggal menurunkan ke tipe lain.
- **Selesai bila:** ketiganya lolos harness property test 10.000 seed dengan semua kesulitan.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md (tabel "Spesifikasi ringkas tipe lain").
  Ikuti pola fig_mtx.dart yang sudah ada. Implementasikan FIG-MIR, FIG-SEQ, FIG-ODD
  lengkap dengan solver dan pembahasan otomatis, lalu daftarkan di registry
  generator. Pakai harness property test dari T03; semua invarian harus lolos
  pada 10.000 seed per tipe dan kesulitan.
  ```

## T06 Generator numerik dan logika
- **Fitur:** F04. **Bergantung pada:** T03.
- **Model:** Sonnet 5.5. Solver numerik jelas bentuknya; untuk LOG-SYL naikkan ke Opus 5.5 hanya jika pemeriksa model himpunan gagal tes.
- **Selesai bila:** NUM-SEQ, NUM-ARI, NUM-WORD, LOG-SYL lolos property test; aritmetika memakai pecahan eksak.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md. Implementasikan NUM-SEQ, NUM-ARI,
  NUM-WORD, dan LOG-SYL beserta solver, pengecoh, dan pembahasan. NUM-ARI memakai
  pecahan eksak (tanpa double). LOG-SYL memeriksa kesimpulan dengan enumerasi model
  kecil. Registrasikan semua generator. Jalankan property test 10.000 seed per
  tipe dan kesulitan.
  ```

## T07 Skrip pre-generate dan bank verbal 300 soal
- **Fitur:** F04. **Bergantung pada:** T03.
- **Model:** Sonnet 5.5 untuk menulis skrip dan memverifikasi. Pembuatan soalnya sendiri dijalankan lewat Claude Code dengan langganan (tanpa API berbayar, ADR-12).
- **Selesai bila:** `assets/verbal_bank.json` berisi 300 soal lolos pass kedua; 10% sampel sudah diperiksa pemilik; skema valid; tidak ada opsi kembar.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md (Bank verbal). Tulis tool/pregenerate/
  gen_verbal.py, verify_verbal.py, bundle.py dan validator skema. Pembuatan soal
  memakai claude -p (langganan, bukan API). verify_verbal.py menjawab tanpa kunci
  dengan prompt berbeda dan membuang soal yang tidak cocok. Hasilkan 300 soal
  VRB-SYN dan VRB-ANA, tulis laporan jumlah yang dibuang, dan siapkan 30 soal
  sampel di docs/eval/verbal_sample.md untuk saya periksa manual.
  ```

## T08 Renderer figural dan golden test
- **Fitur:** F04. **Bergantung pada:** T02, T04.
- **Model:** Sonnet 5.5. Menggambar dari data adalah pekerjaan terstruktur.
- **Selesai bila:** semua nilai `FigureSpec` tergambar terbaca di 360 dp; `fill` dibedakan lewat pola; golden test untuk tiap shape, fill, rotasi, dan satu matriks lengkap.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md (Spesifikasi gambar). Buat widget
  FigureView berbasis CustomPainter yang menggambar FigureSpec (single, sequence,
  matrix3x3) memakai warna dari token. Fill dibedakan lewat pola kosong, penuh,
  arsir, bukan warna. Tulis golden test di 360 dp dan 412 dp, serta uji semantik
  (Semantics label deskripsi gambar).
  ```

## T09 Database Drift dan repository
- **Fitur:** pondasi data. **Bergantung pada:** T01.
- **Model:** Sonnet 5.5. Skema sudah ditetapkan di `03-data-model.md`.
- **Selesai bila:** tabel v1 dan migrasi ada; repository punya test dengan database memori; berjalan di Android dan web.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/03-data-model.md. Implementasikan tabel Drift v1
  (test_profile, session, answer, mistake_card, captured_question, company_test_log,
  app_setting) dengan indeks yang ditulis, antarmuka repository di domain/ dan
  implementasinya di data/. Setup database yang berjalan di Android dan web.
  Tulis test repository dengan database dalam memori dan satu test migrasi.
  ```

## T10 Kerangka sesi
- **Fitur:** F05. **Bergantung pada:** T03, T09.
- **Model:** Opus 5.5. Penghitungan waktu dari `deadline` mutlak dan pelanjutan sesi mudah salah.
- **Selesai bila:** test unit untuk timer per subtes, pindah subtes otomatis, pelanjutan setelah restart, mode latihan tanpa timer, dan penilaian; sesi tetap benar jika jam perangkat berubah wajar.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F05), docs/02-arsitektur.md (Manajemen state),
  docs/03-data-model.md (session). Implementasikan SessionController (Notifier) dan
  Scoring di domain/. Sisa waktu dihitung dari deadline mutlak yang disimpan, bukan
  penghitung yang berkurang. Setiap jawaban langsung ditulis ke database. Simulasi:
  timer per subtes, tidak bisa kembali ke subtes sebelumnya, pembahasan hanya di
  akhir. Tulis test dengan jam palsu (fake clock) untuk semua skenario di kriteria
  penerimaan, termasuk app ditutup paksa lalu dibuka lagi.
  ```

## T11 Onboarding: S01, S02 dan profil Umum
- **Fitur:** F01. **Bergantung pada:** T02, T09.
- **Model:** Sonnet 5.5.
- **Selesai bila:** profil bisa dibuat, diubah, dan diaktifkan; template QA, Mobile Dev, IT BA, Umum, CCAT-style, Psikotes Bank-style tersedia; pengalihan awal ke onboarding jika belum ada profil.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/05-spek-layar.md (S01, S02), docs/06-bank-konten.md (Blueprint
  tes per profil) dan papan desain Main serta S02. Bangun layar S01 dan S02,
  ProfileRepository, template profil termasuk Umum dengan bobot rata, validasi, dan
  guard rute. Gunakan hanya komponen dari lib/core/widgets. Sertakan semua kondisi
  dan test widget.
  ```

## T12 Beranda dan katalog: S04, S05
- **Fitur:** F03, F04. **Bergantung pada:** T02, T09, T11.
- **Model:** Sonnet 5.5.
- **Selesai bila:** beranda menampilkan data profil dan kelemahan; katalog membuka tipe soal; tipe yang belum rilis tampil nonaktif; semua kondisi ada.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/05-spek-layar.md (S04, S05) dan papan desain S04, S05. Bangun
  kedua layar dengan bottom nav, provider data, dan kondisi kosong, memuat, galat.
  Rencana latihan memakai antarmuka DailyPlanner (implementasi di T13; sementara
  pakai fake). Tipe soal diambil dari registry generator.
  ```

## T13 Diagnostik dan rencana latihan harian
- **Fitur:** F02, F03. **Bergantung pada:** T06, T10, T12.
- **Model:** Sonnet 5.5. Algoritma sudah tertulis langkah demi langkah; naikkan ke Opus 5.5 hanya jika komposisi 50/30/20 gagal tes.
- **Selesai bila:** `DailyPlanner` memenuhi komposisi, aturan tanggal tes kurang dari 7 hari, dan aturan tanpa pengulangan 30 hari; S03 berjalan; hasil diagnostik menjadi titik awal metrik.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F02, F03), docs/03-data-model.md (Rencana latihan
  harian, WeaknessModel) dan docs/05-spek-layar.md (S03). Implementasikan
  DailyPlanner dan WeaknessModel di domain/, layar S03, dan sesi diagnostik (maks
  20 menit, semua kategori aktif). Tulis test unit untuk: komposisi 50/30/20,
  kekurangan kartu jatuh tempo, tanggal tes kurang dari 7 hari, tanpa pengulangan
  (type, seed) dalam 30 hari, tipe tanpa data diberi bobot 0,5.
  ```

## T14 Layar sesi: S06, S07
- **Fitur:** F04, F05. **Bergantung pada:** T08, T10.
- **Model:** Sonnet 5.5.
- **Selesai bila:** latihan dan simulasi berjalan end to end; petunjuk, timer opsional, dan pelanjutan sesi bekerja; layar terbaca di 360 dp.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/05-spek-layar.md (S06, S07), papan desain S06 dan S07. Bangun
  satu SessionScreen dengan dua mode memakai SessionController (T10) dan FigureView
  (T08). Opsi soal memakai OptionTile; kisi nomor memakai NumberBubble. Mode latihan
  menampilkan benar atau salah dan pembahasan singkat setelah menjawab. Tulis test
  widget untuk memilih opsi, mengirim, pindah subtes otomatis, dan melanjutkan sesi.
  ```

## T15 Hasil dan pembahasan: S08, S09
- **Fitur:** F06. **Bergantung pada:** T14.
- **Model:** Sonnet 5.5.
- **Selesai bila:** empat label cepat atau lambat dihitung dari median 30 hari; sakelar buku kesalahan bekerja; semua soal punya pembahasan.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F06), docs/03-data-model.md (Label cepat dan
  lambat) dan docs/05-spek-layar.md (S08, S09). Bangun kedua layar dan layanan
  pelabelan. Soal pada S09 dibuat ulang dari (tipe, seed, kesulitan). Jawaban salah
  membuat kartu buku kesalahan. Tulis test unit pelabelan dan test widget kedua
  layar.
  ```

## T16 Buku kesalahan dengan SM-2: S10
- **Fitur:** F07. **Bergantung pada:** T15.
- **Model:** Sonnet 5.5. Tangga interval sudah ditetapkan di dokumen.
- **Selesai bila:** `Sm2Scheduler` lulus semua baris tabel jadwal (termasuk pemeriksaan 14 hari, asumsi A1); ulangan engine memakai seed baru; kartu Capture memakai butir yang sama.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F07), docs/03-data-model.md (Jadwal SM-2) dan
  docs/05-spek-layar.md (S10). Implementasikan Sm2Scheduler, MistakeRepository.
  applyReview, dan layar S10 dengan filter serta kondisi kosong. Tulis test
  berbasis tabel untuk setiap peristiwa jadwal. Jika menemukan ketidakjelasan,
  catat sebagai pertanyaan di docs/progress.md, jangan menebak.
  ```

## T17 Statistik: S11
- **Fitur:** F08. **Bergantung pada:** T15.
- **Model:** Sonnet 5.5.
- **Selesai bila:** angka sama dengan kueri langsung; grafik dengan satu titik ditangani; CSV valid.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F08) dan docs/05-spek-layar.md (S11). Bangun
  StatsService, layar S11 dengan fl_chart (warna dari token, nilai di label teks),
  dan ekspor CSV (UTF-8, koma). Tulis test unit agregasi dan test widget kondisi
  kosong serta satu titik.
  ```

## T18 Capture dan catatan psikotes: S12, S13
- **Fitur:** F09, F10. **Bergantung pada:** T09, T14.
- **Model:** Sonnet 5.5.
- **Selesai bila:** soal Capture bisa disimpan, dikerjakan di sesi latihan, dan masuk buku kesalahan; foto tersimpan lokal; tidak ada data Capture di ekspor repo atau log; saran dari catatan bekerja.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F09, F10) dan docs/05-spek-layar.md (S12, S13).
  Bangun kedua layar, repository Capture dan catatan, penyimpanan foto lokal, dan
  integrasi ke sesi latihan serta buku kesalahan. Tambahkan folder data lokal ke
  .gitignore. Tulis test validasi form dan test integrasi simpan lalu kerjakan.
  ```

## T19 Pengaturan dan backup: S18
- **Fitur:** F11. **Bergantung pada:** T09.
- **Model:** Sonnet 5.5.
- **Selesai bila:** ekspor lalu impor di database bersih mengembalikan semua tabel; versi lebih baru ditolak dengan pesan; key API tidak ada di ekspor.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/03-data-model.md (Format backup) dan docs/05-spek-layar.md
  (S18). Implementasikan BackupService (ekspor dan impor satu transaksi, validasi
  format dan versi), layar S18, pemilih tema (terang, gelap, sistem; gelap menunggu
  T21), dan penyimpanan key (flutter_secure_storage di Android, memori di web).
  Tulis test bolak-balik ekspor dan impor serta test penolakan berkas salah.
  ```

## T20 Alur integrasi, build web dan APK, rilis v1.0.0
- **Fitur:** v1. **Bergantung pada:** T11 sampai T19.
- **Model:** Sonnet 5.5.
- **Selesai bila:** tiga test integrasi lulus (profil lalu sesi simulasi lalu review lalu statistik; buku kesalahan; Capture); web terbit di Pages; APK terlampir di GitHub Releases; checklist manual di `08-rencana-tes.md` terisi.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/08-rencana-tes.md. Tulis tiga integration_test sesuai
  tabel level tes, tambahkan job build web ke GitHub Pages dan job APK ke GitHub
  Releases saat tag v*. Buat CHANGELOG.md dan tandai v1.0.0. Isi checklist manual
  sebagai berkas docs/eval/checklist-v1.0.0.md untuk saya jalankan di HP.
  ```

**Gerbang v1:** psikotes lolos uji coba pribadi (dipakai sendiri, kolom "Sebelum" di `10-laporan-hasil.md` terisi dari diagnostik pertama). Rilis v1.1 dimulai setelah ini.

---

# Rilis v1.1 (lengkapi)

## T21 Tema gelap
- **Model:** Sonnet 5.5. **Bergantung pada:** T02.
- **Selesai bila:** token gelap di `design/tokens.json` aktif; semua layar diperiksa satu per satu (laporkan kontras tiap pasangan); soal figural terbaca di mode gelap.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/04-sistem-desain.md (tema gelap). Aktifkan tema gelap lewat
  token, sambungkan ke pengaturan tema, dan periksa seluruh layar satu per satu.
  Laporkan rasio kontras tiap pasangan teks dan latar, dan perbaiki token (bukan
  layar) bila ada yang gagal. Tambahkan golden test gelap untuk komponen inti.
  ```

## T22 Kepribadian Papi/DISC-style: S14
- **Fitur:** F12. **Model:** Sonnet 5.5. **Bergantung pada:** T14.
- **Selesai bila:** pool terbundel (10 sampai 20 pernyataan per sifat); pasangan acak dari dua sifat berbeda; review memuat arti pilihan dan profil; tanpa skor benar atau salah.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/06-bank-konten.md (Pool kepribadian), docs/05-spek-layar.md
  (S14). Buat generator PER-PAPI dan PER-DISC, skrip pembuat pool (claude -p), pool
  JSON awal, layar S14, dan review profil. Tanpa warna benar atau salah. Tulis
  test pemasangan acak, determinisme, dan pembentukan profil.
  ```

## T23 Kraepelin/Pauli penuh
- **Fitur:** F13. **Model:** Sonnet 5.5. **Bergantung pada:** T14.
- **Selesai bila:** durasi asli per kolom, grafik konsistensi, dan skor berdasarkan kecepatan serta ketelitian.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md (KRP). Lengkapi generator KRP (kolom
  angka, durasi per kolom, pergantian kolom otomatis), layar sesi khusus dengan
  input angka cepat, dan grafik konsistensi (fl_chart). Tulis test solver dan test
  widget input.
  ```

## T24 Modul IT: pseudocode, flowchart, Excel
- **Fitur:** F14. **Model:** Opus 5.5 untuk interpreter dan solver; Sonnet 5.5 untuk layar. **Bergantung pada:** T03.
- **Selesai bila:** IT-PSE, IT-FLW, IT-XLS lolos property test; pseudocode dieksekusi oleh interpreter kecil buatan sendiri.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md (tabel katalog IT-*). Implementasikan
  generator dan solver IT-PSE (trace pseudocode dengan interpreter mini untuk loop,
  kondisi, nesting), IT-FLW (cabang), IT-XLS (SUM, IF, VLOOKUP, COUNTIF pada tabel
  kecil, aritmetika eksak). Tampilkan pseudocode dengan font monospasi dari token.
  Property test 10.000 seed per tipe.
  ```

## T25 Bank pengetahuan role: S19, S20
- **Fitur:** F17. **Model:** Sonnet 5.5. **Bergantung pada:** T16.
- **Selesai bila:** bank terbundel dengan tiga level per role; "Belum paham" membuat kartu buku kesalahan; level Lanjut dinilai dengan poin kunci; butir tanpa sumber bertanda "perlu verifikasi".
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/01-prd.md (F17), docs/06-bank-konten.md (Bank pengetahuan
  role) dan docs/05-spek-layar.md (S19, S20). Bangun KnowledgeRepository, layar S19
  dan S20, penilaian poin kunci, tabel knowledge_progress (migrasi), dan integrasi
  ke buku kesalahan. Mode Umum memilih butir lintas role. Tulis test pemilihan
  butir dan test integrasi ke SM-2.
  ```

## T26 Pembuatan isi bank pengetahuan dan bacaan
- **Fitur:** F17, VRB-RC. **Model:** Sonnet 5.5. **Bergantung pada:** T07, T25.
- **Selesai bila:** minimal 30 butir per role dan level (target awal; sesuaikan dengan lowongan yang dilamar); pass kedua lolos; pemilik memeriksa sampel 10%; butir tanpa sumber ditandai.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/06-bank-konten.md. Perluas tool/pregenerate untuk
  knowledge_bank.json dan VRB-RC dengan alur yang sama seperti bank verbal (claude
  -p, verifikasi pass kedua tanpa melihat kunci, sampel manual). Hasilkan bank
  sesuai topik awal dan laporkan jumlah butir per role, level, topik, serta yang
  ditandai perlu verifikasi. Siapkan sampel di docs/eval/ untuk saya periksa.
  ```

---

# Rilis v1.2 (uji coba dan publikasi)

## T27 OCR untuk Capture
- **Fitur:** F16. **Model:** Sonnet 5.5. **Bergantung pada:** T18.
- **Selesai bila:** foto soal menghasilkan teks yang bisa disunting sebelum disimpan; berjalan offline di Android (ML Kit atau setara, dipilih dan dicatat sebagai ADR); web memberi pesan bahwa OCR hanya di Android.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/01-prd.md (F16, F09). Pilih pustaka OCR gratis dan offline
  untuk Android, catat alasannya sebagai ADR baru di docs/adr/ dan 09-keputusan.md,
  lalu tambahkan tombol "Ambil teks dari foto" di S12. Hasil OCR selalu bisa
  disunting. Di web tampilkan pesan yang menjelaskan keterbatasannya. Tulis test
  alur dengan OCR palsu.
  ```

## T28 README case study, demo, laporan hasil, bullet CV
- **Model:** Haiku 5.5 untuk menyusun dari data; Sonnet 5.5 untuk menulis README. **Bergantung pada:** T20 dan data pemakaian.
- **Selesai bila:** README memuat masalah, demo (web, APK, video 60 sampai 90 detik), solusi, arsitektur dan tiga ADR terpenting, kualitas (angka test), hasil (tabel sebelum dan sesudah), pelajaran; bullet CV punya angka asli, bukan kurung siku.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/10-laporan-hasil.md dan docs/09-keputusan.md. Susun README.md
  sesuai kerangka case study dan isi tabel metrik dari ekspor CSV Statistik yang
  saya lampirkan. Jangan mengarang angka: kolom yang belum ada datanya dibiarkan
  kosong dan dicatat. Tulis tiga versi bullet CV (BA, QA, Developer) dengan angka
  yang tersedia.
  ```

---

# Rilis v1.3 (wawancara, fitur terakhir)

## T29 UI wawancara dengan data contoh (boleh dikerjakan lebih awal)
- **Fitur:** F15 (UI saja). **Model:** Sonnet 5.5. **Bergantung pada:** T02.
- **Selesai bila:** S15, S16, S17 dapat dibuka dengan data contoh dan sesuai papan desain; tidak ada panggilan jaringan; tombol suara nonaktif; semua kondisi (key kosong, batas habis, offline, galat kirim) tampil.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/05-spek-layar.md (Kelompok 5) dan papan desain S15, S16, S17.
  Bangun ketiga layar dengan data contoh lokal (tanpa jaringan) lewat antarmuka
  AiCoach yang hanya berisi implementasi palsu (FakeCoach). Gunakan komponen di
  lib/core/widgets, termasuk ChatBubble (tambahkan sesuai tabel komponen bila belum
  ada). Tulis test widget untuk semua kondisi.
  ```

## T30 Antarmuka AiCoach, sanitasi CV, kartu template
- **Fitur:** F15. **Model:** Sonnet 5.5. **Bergantung pada:** T29.
- **Selesai bila:** `CvSanitizer` menghapus nomor HP, email, dan alamat (test dengan variasi format Indonesia); `TemplateCoach` berjalan offline; batas harian 3 sesi ditegakkan.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/02-arsitektur.md (Wawancara). Implementasikan CvSanitizer
  (regex nomor HP Indonesia, email, alamat), TemplateCoach (kartu pertanyaan dari
  klaim CV tanpa LLM), pencatat batas sesi harian, dan tabel cv_profile serta
  interview_session (migrasi). Tulis test sanitasi dengan minimal 30 contoh format.
  ```

## T31 Coach LLM (Gemini atau Groq), penilai, dan evaluasi
- **Fitur:** F15. **Model:** Opus 5.5. Rancangan prompt penilai dan evaluasi konsistensi perlu penalaran kuat. **Bergantung pada:** T30. Keputusan penyedia (ADR) harus sudah dibuat.
- **Selesai bila:** lima metode `AiCoach` berjalan; JSON keluaran divalidasi dengan skema dan ada percobaan ulang; test set 25 jawaban dijalankan 3 kali dengan selisih skor maksimal 1 poin pada 80% kasus; hasil di `docs/eval/`.
- **Prompt:**
  ```
  Baca CLAUDE.md, docs/02-arsitektur.md (Wawancara) dan docs/08-rencana-tes.md
  (Evaluasi LLM). Implementasikan GeminiCoach atau GroqCoach (sesuai ADR penyedia)
  untuk extractCv, planInterview, assess, nextTurn, report. Semua keluaran JSON
  divalidasi, ada percobaan ulang dan jatuh ke TemplateCoach saat gagal atau offline.
  Bangun test set 25 jawaban contoh (10 kuat, 10 lemah, 5 ambigu), jalankan tiga
  kali, dan simpan selisih skor serta kestabilan keputusan gali atau lanjut di
  docs/eval/. Key hanya dari pengaturan; jangan pernah masuk log.
  ```

## T32 Suara di wawancara
- **Fitur:** F18. **Model:** Sonnet 5.5. **Bergantung pada:** T31.
- **Selesai bila:** jawaban lewat suara (STT) dan pertanyaan dibacakan (TTS) memakai layanan gratis di perangkat; dialog bergiliran; fallback ke teks.
- **Prompt:**
  ```
  Baca CLAUDE.md dan docs/01-prd.md (F18). Pilih STT dan TTS gratis di perangkat,
  catat sebagai ADR, aktifkan tombol suara di S16, dan atur dialog bergiliran.
  Sediakan fallback ke teks bila izin mikrofon ditolak atau offline.
  ```
