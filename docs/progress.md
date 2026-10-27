# Progres tugas

Centang saat tugas selesai dan lolos kriteria "Selesai bila" di `07-rencana-tugas.md`. Perbarui juga `docs/README.md` bagian status.


## v1

- [x] T01 Verifikasi kerangka repo dan CI
- [x] T02 Tema, token, dan komponen inti
- [x] T03 Engine: Rng, model, antarmuka generator
- [x] T04 Generator FIG-MTX, solver, property test
- [x] T05 Generator FIG-MIR, FIG-SEQ, FIG-ODD
- [x] T06 Generator numerik dan logika
- [x] T07 Skrip pre-generate dan bank verbal 300 soal (skrip, validator, dan bank 300 soal selesai dan terdaftar di `pubspec.yaml` di cabang sebelumnya; pemuat bank, pemilihan soal, dan integrasi ke rencana, sesi, pembahasan, buku kesalahan, dan katalog baru selesai di cabang `fix/pemuat-verbal-dan-ui`, A100; sebelum itu app tidak membaca bank ini. Pemeriksaan 10% sampel oleh pemilik belum dilakukan, lihat `docs/eval/verbal_sample.md`; `docs/eval/verbal_flags.txt` masih kosong, jadi bank belum berubah)
- [x] T08 Renderer figural dan golden test
- [x] T09 Database Drift dan repository
- [x] T10 Kerangka sesi
- [x] T11 Onboarding: S01, S02 dan profil Umum
- [x] T12 Beranda dan katalog: S04, S05
- [x] T13 Diagnostik dan rencana latihan harian
- [x] T14 Layar sesi: S06, S07
- [x] T15 Hasil dan pembahasan: S08, S09
- [x] T16 Buku kesalahan dengan SM-2: S10
- [x] T17 Statistik: S11
- [x] T18 Capture dan catatan psikotes: S12, S13
- [x] T19 Pengaturan dan backup: S18
- [ ] T20 Alur integrasi, build web dan APK, rilis v1.0.0 (sebagian, lihat catatan T20 di bawah)

## v1.1

- [ ] T21 Tema gelap
- [x] T22 Kepribadian Papi/DISC-style: S14 (Papi-style selesai, pool 12 per sifat menunggu pemeriksaan pemilik; DISC-style dan penyimpanan hasil menunggu Q13)
- [x] T23 Kraepelin/Pauli penuh (penyimpanan hasil dan durasi asli menunggu Q14)
- [x] T24 Modul IT: pseudocode, flowchart, Excel (engine, katalog, template Mobile Dev; tampilan monospasi menunggu Q11, QA menunggu Q12)
- [x] T25 Bank pengetahuan role: S19, S20 (isi bank menunggu T26; aset sementara berisi nol butir)
- [x] T26 Pembuatan isi bank pengetahuan dan bacaan (pengetahuan: 180 butir; bacaan: lihat catatan)

## v1.2

- [ ] T27 OCR untuk Capture
- [ ] T28 README case study, demo, laporan hasil, bullet CV

## v1.3

- [x] T29 UI wawancara dengan data contoh (boleh dikerjakan lebih awal)
- [ ] T30 Antarmuka AiCoach, sanitasi CV, kartu template
- [ ] T31 Coach LLM (Gemini atau Groq), penilai, dan evaluasi
- [ ] T32 Suara di wawancara

## Catatan T20

Kotak T20 belum dicentang karena "Selesai bila" memuat hal yang hanya bisa dilakukan pemilik. Selesai di cabang `fitur/T20-rilis-v1`:

- [x] `applicationId` dan namespace Android: `io.github.moanaku.psikotes` (`flutter build apk --debug` dan `--release` berhasil lokal; paket terverifikasi dengan `aapt2`).
- [x] Tiga integration_test (`integration_test/`), lulus lokal dengan `bash tool/run_integration.sh` dan dijalankan di CI.
- [x] `tool/prepare_web.sh` (sqlite3.wasm dan drift_worker.js, A44); `flutter build web` berhasil lokal; database web terbuka di Chrome 155 (tampil onboarding).
- [x] Workflow `release-apk` (tag `v*`, tanda tangan dari secret atau kunci debug) dan `pages` (manual atau tag, bukan push biasa); sintaks YAML diperiksa, belum pernah dijalankan di GitHub.
- [x] `CHANGELOG.md`, `docs/RILIS-APK.md`, `docs/eval/checklist-v1.0.0.md`.

Menunggu pemilik: checklist manual di HP, pemeriksaan 30 soal sampel bank verbal (tandai di `docs/eval/verbal_flags.txt`, lalu jalankan `bundle.py` lagi), secret keystore, keputusan Pages untuk repo privat, tag `v1.0.0` (perintah di `docs/RILIS-APK.md`), centang T20 setelah APK terlampir di Releases. Belum dicoba: integration_test di HP atau emulator dan di Chrome (`flutter drive`), APK di perangkat, workflow GitHub di luar CI pull request, desain ikon app.

## Daftar untuk fase pengujian akhir (perbaikan UI skala huruf)

Perbaikan di cabang `fix/pemuat-verbal-dan-ui` (kepala S07 dipadatkan, nama subtes mengecil dalam satu baris, gambar soal, test dengan font asli `test/support/app_fonts.dart`) lulus di test widget pada layar 360 x 800, tetapi **belum selesai dan belum diverifikasi di HP**. Yang masih harus diperiksa dan mungkin diperbaiki:

- [ ] Navigasi bawah dan tombol terpotong di skala 1,3 dan 2,0.
- [ ] Kepala S07 di skala 2,0 (masih memakan banyak tinggi layar).
- [ ] Label sumbu grafik S11 di skala 2,0.
- [ ] Tombol Back sistem di langkah 1 wizard tambah profil.

Dari T25 (belum dicoba di HP dan browser; bank bawaan kini 180 butir dari T26):

- [ ] S19 dan S20 dengan bank kecil (isi `assets/knowledge_bank.json` sementara untuk uji) di skala 1,0, 1,3, 2,0; ketuk level, topik, "Latihan 10 kartu", "Buka jawaban", centang poin kunci Lanjut, ringkasan, tombol tutup, tombol Back sistem.
- [ ] "Belum paham" muncul sebagai kartu "Pengetahuan QA, Dasar" di S10 dan dihitung di "jatuh tempo" beranda.
- [ ] Upgrade dari APK lama (skema v2 ke v3) tidak menghapus riwayat; backup lalu impor membawa kemajuan pengetahuan.

Dari T29 (belum dicoba di HP dan browser):

- [ ] S15 sampai S17 di skala 1,0, 1,3, 2,0: pilih pewawancara, mulai, kirim jawaban sampai penutup, Akhiri, transkrip; judul S16 di 2,0; tombol Back sistem.

Dari Tugas 4 (belum dicoba di HP dan browser):

- [ ] Pseudocode IT-PSE memakai font monospasi dengan indentasi gantung di S06 dan S09 pada skala 1,0, 1,3, 2,0; tabel flowchart dan lembar kerja memakai font kode; font termuat di web.

Layar baru dari T22, T23, T24 ditambahkan ke daftar ini di catatan tugas masing-masing.

Dari Tugas 0 (belum dicoba di HP dan browser):

- [ ] S04: baris "Sudah dikerjakan hari ini" naik setelah menjawab, tidak menghitung soal dilewati, kembali ke "Belum ada soal dikerjakan hari ini." setelah lewat tengah malam; dibaca di skala 1,0, 1,3, 2,0. Upgrade dari APK lama (skema v1 ke v2) tidak menghapus riwayat.

Dari T24 (belum dicoba di HP dan browser):

- [ ] S06 dengan soal Pseudocode, Flowchart, dan Excel di skala 1,0, 1,3, 2,0 (test widget 360 dp dengan font asli lulus). Perhatikan pseudocode yang baris panjangnya terlipat di 2,0: indentasi hilang di baris lanjutan (Q11).
- [ ] Tabel flowchart dan lembar kerja di S06 dan S09 (TableFigure) di layar sempit.
- [ ] S02 dengan baris "Modul IT" dan role Mobile Dev; simulasi berisi subtes Modul IT.

Dari T22 (belum dicoba di HP dan browser):

- [ ] S14 Papi-style dari katalog: soal, Sebelumnya, konfirmasi keluar, tombol Back sistem, review panjang (24 baris arti pilihan) di skala 1,0, 1,3, 2,0.
- [ ] Pool kepribadian termuat di web (aset JSON) dan di APK.

Dari T23 (belum dicoba di HP dan browser):

- [ ] Tes Kraepelin dari katalog (QA: 10 kolom x 60 detik): tombol angka terasa cepat, tidak ada ketukan ganda, pergantian kolom otomatis, timer, keluar di tengah, tombol Back sistem.
- [ ] App ditinggal ke latar belakang di tengah tes: kolom terlewat saat kembali.
- [ ] Hasil dan grafik konsistensi di skala 1,0, 1,3, 2,0; grafik dengan 15 kolom (Bank-style).
- [ ] S02 untuk QA dengan Kraepelin menyala; ringkasan simulasi "Tes terpisah".

## Catatan lanjut

- Uji HP dan browser (Tugas 5) sebagian selesai; laporan lokal di `uji-perangkat/LAPORAN-3.md` (tidak di-commit). Lulus di HP: S04 penghitung, upgrade skema, S19, S20, S15, S16 (1,0), pseudocode monospasi (1,0 dan 2,0). Diperbaiki: tombol Akhiri S16 terpotong, nama topik akronim. Belum terbukti di HP: S16 di 2,0. Tidak diuji: Kraepelin, S14, tabel IT, S17, S19 dan S20 di 1,3 dan 2,0, butir lama (nav, S07, S11, Back wizard). Browser: aset termuat (200), tampilan belum diverifikasi. `assets/reading_bank.json` (30 soal VRB-RC: 10 per kesulitan, 10 per kunci; 45 kandidat semua sepakat di pass 2, jadi penguji tampak longgar) terdaftar tetapi belum dipakai app; sampel di `docs/eval/reading_sample.md`. Terbuka: Q15, Q16.
- T26: `assets/knowledge_bank.json` berisi 180 butir (qa, mobile, ba x dasar, menengah, lanjut x 20; 27 topik). 245 kandidat diperiksa pass 2 tanpa melihat kunci, 5 gugur. SEMUA butir bertanda perlu verifikasi: pass 1 dan 2 memakai model yang sama dan rujukan belum dicocokkan dengan teks aslinya. Sampel 18 butir di `docs/eval/knowledge_sample.md` menunggu pemeriksaan pemilik; id meragukan ditulis di `docs/eval/knowledge_flags.txt` lalu `python tool/pregenerate/gen_knowledge.py bundle`. Role Umum memakai butir lintas role (tanpa butir role `umum`). Lanjut bila perlu: `python tool/pregenerate/gen_knowledge.py all`.
- Tugas 4 selesai: `AppType.code`, `CodeBlock`, IBM Plex Mono di `assets/fonts` (A109). Golden S06 teks dan tabel IT perlu dibuat ulang lewat WSL.
- T29 selesai: S15 sampai S17 dengan `FakeCoach`, `ChatBubble`, semua kondisi (A108). Berikutnya: selesaikan T26 (`python tool/pregenerate/gen_knowledge.py all`, lalu `gen_reading.py all`), Tugas 4 (font kode), Tugas 5 (uji HP dan browser), golden lewat WSL, PR.
- T25 selesai di cabang `fitur/fitur-inti-dan-uji-akhir`: `KnowledgeBank` (pemuat dengan kondisi galat seperti A100), `KnowledgeSelector`, `KnowledgeService` (penilaian diri, kemajuan, kartu SM-2), tabel `knowledge_progress` (skema v3 dengan test migrasi v2 ke v3), S19 dan S20 dengan semua kondisi, baris katalog dan pintasan beranda, backup ikut membawa `knowledge_progress` dan `answer.dijawab` (A106, A107). Terbuka: Q15 (`CheckRow`). Berikutnya: T26 (isi bank pengetahuan dan VRB-RC).
- Tugas 0 (cabang `fitur/fitur-inti-dan-uji-akhir`) selesai: baris "Sudah dikerjakan hari ini: N soal" di bawah panel latihan S04 (A105). Skema naik ke v2 (`answer.dijawab`, migrasi dan test migrasi). Berikutnya: T25 (bank pengetahuan, S19, S20).
- T24 selesai di cabang `fix/pemuat-verbal-dan-ui`: IT-PSE (interpreter mini, 22 kasus tulisan tangan), IT-FLW dan IT-XLS (masing-masing dibandingkan dengan solver kedua independen pada 3.000 soal per kesulitan), property test 10.000 seed per tipe dan kesulitan, katalog terbuka, subtes Modul IT untuk Mobile Dev (A101, A102). Golden katalog, S02, tabel NUM-WORD, dan S08 diperbarui lewat WSL (sebagian tertinggal dari commit sebelumnya). Terbuka: Q11 (token monospasi), Q12 (QA dan IT).
- T22 selesai: pool 96 pernyataan (8 sifat x 12) lewat `claude -p` dengan penyaring istilah klinis, sampel di `docs/eval/personality_sample.md` menunggu pemeriksaan pemilik (catatan: PER-KRS-001 dan PER-PIM-001 mirip), S14 dengan empat kondisi dan review per role, baris Papi-style di katalog terbuka (A103). Terbuka: Q13 (simpan hasil, subtes Kepribadian di simulasi, DISC-style).
- T23 selesai: `KrpSheet` dan `KrpScore` di engine (test tulisan tangan dan 10.000 seed), `KraepelinRun` dengan pergantian kolom otomatis dari jam monoton, layar dengan input angka cepat, hasil kecepatan, ketelitian, konsistensi, dan grafik `fl_chart`; baris katalog terbuka; QA menyalakan Kraepelin (A104). Ditemukan dan diperbaiki: mengganti role mematikan Kraepelin Bank-style; integration_test profil sampai statistik masih mencari teks S08 lama "Tidak dijawab: n soal" sejak A99, kini membaca baris "Soal tidak dijawab". Terbuka: Q14.
- Berikutnya: checklist UI, pull request ke main, pantau CI. Lalu jawaban Q11 sampai Q14 dan fase pengujian akhir di HP.

## Pertanyaan terbuka

- Temuan uji perangkat 2: bagian logika selesai di `fix/pemuat-verbal-dan-ui` (pemuat verbal A100, target waktu A98, soal tidak dijawab A99, tab Wawancara, nama tipe). Bagian UI di HP (teks terpotong di skala 1,3 dan 2,0, S07, S11, Back wizard) tercatat di bawah setelah diverifikasi. Pertanyaan baru: Q8 sampai Q10 di `docs/11-asumsi-dan-pertanyaan.md`. Rincian temuan: `uji-perangkat/LAPORAN-2.md` (lokal, tidak di-commit).
