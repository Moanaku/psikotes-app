# CLAUDE.md

Proyek: Simulator Psikotes IT, app Flutter offline-first untuk berlatih psikotes kerja IT. Pemilik: Bnan (Dani Banan Husna). Bahasa kerja: Indonesia. Dokumen lengkap ada di `docs/` dan itulah sumber kebenaran; baca bagian yang relevan sebelum mengerjakan tugas.

## Mulai dari sini

1. Baca `docs/README.md` (daftar isi dan status).
2. Tugas yang sedang dikerjakan ada di `docs/07-rencana-tugas.md`; kemajuan di `docs/progress.md`.
3. Fitur memakai ID F01 sampai F18, layar S01 sampai S20, keputusan ADR-01 sampai ADR-13. Pakai ID yang sama di commit, test, dan issue.

## Aturan keras

- Biaya Rp0. Tidak ada layanan berbayar, tidak ada akun, tidak ada server sendiri.
- Psikotes sepenuhnya offline. Hanya wawancara (v1.3) yang boleh memanggil jaringan.
- `packages/question_engine` Dart murni: tanpa `package:flutter`, tanpa I/O, tanpa `dart:math Random`, tanpa `DateTime.now()`, tanpa `hashCode`. Semua keacakan lewat `Rng`.
- Soal tidak disimpan utuh: simpan `(type, seed, difficulty, gen_versi)`.
- Setiap soal harus punya tepat satu jawaban benar, dibuktikan solver. Kegagalan invarian diperbaiki di generator, tidak dengan melonggarkan invarian.
- Jangan menyalin soal SHL, CCAT, Papi Kostick, atau soal perusahaan. Soal Capture, foto, dan key API tidak boleh masuk repo, log, atau ekspor.
- Tidak ada telemetri.
- Fitur wawancara (F15, F18) dikerjakan paling akhir (ADR-11). Jangan memulai logikanya sebelum v1.1 selesai, kecuali UI saja (T29).

## Aturan UI (dari dokumen "Bikin Aplikasi Mobile yang Tidak Terlihat AI Slop")

Detail dan angka: `docs/04-sistem-desain.md`, nilai di `lib/core/theme/app_tokens.dart`.

Alur kerja:
- Token dan komponen ada sebelum layar. Layar adalah perakitan komponen di `lib/core/widgets/`.
- Layar baru harus bisa dibangun dari token yang ada. Kalau butuh nilai baru, hentikan dan usulkan perubahan token; jangan menambal di layar.
- Jangan membuat komponen baru tanpa izin; kalau perlu, tambahkan baris di tabel komponen dulu.
- Setiap layar data wajib punya empat kondisi: kosong, memuat (skeleton), galat (sebab dan "Coba lagi"), offline. Bedakan "belum ada data" dari "filter kosong". Jangan pernah menampilkan pesan exception mentah.

Larangan:
- Tanpa warna biru sebagai aksen. Satu aksen saja: stabilo `#F2CF3D`.
- Tanpa gradien, tanpa `ColorScheme.fromSeed` tanpa override, tanpa dynamic color, tanpa Inter, Poppins, atau Roboto.
- Tanpa hex mentah atau `Colors.*` di widget. Tanpa `Opacity` untuk teks sekunder; pakai `inkMuted`.
- Tanpa kartu untuk semua hal: daftar adalah baris dan garis pemisah. Tanpa tiga kartu seragam berjajar.
- Tanpa emoji sebagai ikon; satu keluarga ikon outlined.
- Tanpa spinner di tengah layar sebagai satu-satunya loading.
- Tanpa angka jarak di luar 4, 8, 12, 16, 24, 32, 48. Maksimal 3 radius (4, 8, 12), 1 tingkat elevasi (0), 6 ukuran teks (12, 14, 16, 20, 28, 36). Satu easing, durasi 150 ms.
- Microcopy Indonesia, kalimat pendek, tombol menyebut objek ("Simpan ke bank pribadi"). Tanpa "Oops", "Something went wrong", "No data", "Submit".

Sebelum menyatakan UI selesai, jalankan checklist di akhir `docs/04-sistem-desain.md` dan laporkan poin per poin, termasuk angka kontras dan satu keputusan desain sadar per layar.

## Cara bekerja

- Satu tugas, satu cabang `fitur/Txx-nama`, satu pull request kecil. Pesan commit: `Txx Fyy: ringkasan`.
- Atribusi: jangan menambahkan `Co-Authored-By`, "Generated with", tautan sesi, atau nama alat AI apa pun ke pesan commit, deskripsi pull request, issue, README, atau berkas lain yang tampil di GitHub. Seluruh riwayat atas nama pemilik repo. `.claude/settings.json` sudah mematikan atribusi otomatis; jangan diubah.
- Tulis test bersama kodenya. Bug engine yang ditemukan jadi test baru dulu, baru diperbaiki.
- Perintah rutin: `dart run build_runner build` (membuat kode Drift; berkas `*.g.dart` tidak di-commit, jalankan setelah `flutter pub get` dan setelah mengubah tabel; di Windows `sqlite3.dll` harus ada di PATH untuk test database), `flutter analyze`, `flutter test`, `cd packages/question_engine && dart test -p vm,chrome`, `bash tool/check_tokens.sh`, `bash tool/check_tokens_test.sh`.
- Golden test (ADR-13): acuannya Linux dengan Flutter yang dipin di `.github/workflows/ci.yml`. Di Windows pakai `flutter test --exclude-tags golden`. Membuat ulang golden: `bash tool/update_goldens.sh` (lewat WSL); memeriksa: `bash tool/update_goldens.sh --verify`. Tinjau selisih PNG sebelum commit; jangan memperbarui golden hanya agar CI hijau.
- Jika dokumen tidak jelas atau saling bertentangan, tulis pertanyaan di `docs/progress.md` dan berhenti di bagian itu; jangan menebak. Asumsi yang sudah ada tercatat di `docs/11-asumsi-dan-pertanyaan.md`.
- Keputusan penting baru: tambahkan ADR di `docs/adr/` dan baris di `docs/09-keputusan.md`.
- Gunakan model sesuai baris **Model** di tugas. Naikkan ke model yang lebih kuat hanya bila tes gagal berulang dan akarnya logika.

## Struktur

Ringkas: `lib/app`, `lib/core` (tema, widget), `lib/data` (Drift, repository, backup), `lib/domain` (perencana, sesi, SM-2, statistik), `lib/features/*` (layar), `lib/ai` (wawancara), `packages/question_engine`, `tool/pregenerate` (skrip Python bank soal), `assets/`. Detail: `docs/02-arsitektur.md`.

## Definition of Done

Kode ter-merge lewat pull request; test otomatis ditulis dan CI hijau; dicoba di HP Android dan di browser; kriteria penerimaan fitur terpenuhi; dokumen, ADR, atau CHANGELOG diperbarui.
