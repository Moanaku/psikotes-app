# Progres tugas

Centang saat tugas selesai dan lolos kriteria "Selesai bila" di `07-rencana-tugas.md`. Perbarui juga `docs/README.md` bagian status.


## v1

- [x] T01 Verifikasi kerangka repo dan CI
- [x] T02 Tema, token, dan komponen inti
- [x] T03 Engine: Rng, model, antarmuka generator
- [x] T04 Generator FIG-MTX, solver, property test
- [x] T05 Generator FIG-MIR, FIG-SEQ, FIG-ODD
- [x] T06 Generator numerik dan logika
- [x] T07 Skrip pre-generate dan bank verbal 300 soal (skrip, validator, dan bank 300 soal selesai dan terdaftar di `pubspec.yaml`; pemeriksaan 10% sampel oleh pemilik belum dilakukan, lihat `docs/eval/verbal_sample.md`; app belum memuat bank ini, lihat pertanyaan terbuka)
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
- [ ] T22 Kepribadian Papi/DISC-style: S14
- [ ] T23 Kraepelin/Pauli penuh
- [ ] T24 Modul IT: pseudocode, flowchart, Excel
- [ ] T25 Bank pengetahuan role: S19, S20
- [ ] T26 Pembuatan isi bank pengetahuan dan bacaan

## v1.2

- [ ] T27 OCR untuk Capture
- [ ] T28 README case study, demo, laporan hasil, bullet CV

## v1.3

- [ ] T29 UI wawancara dengan data contoh (boleh dikerjakan lebih awal)
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

## Pertanyaan terbuka

- Pemuat bank verbal. `assets/verbal_bank.json` sudah ada dan terdaftar, tetapi tidak ada kode yang membacanya: `availableTypesProvider` (`lib/domain/providers.dart`) hanya memakai `GeneratorRegistry.types`, jadi Sinonim dan Analogi tetap "Segera" di katalog dan tidak masuk diagnostik, simulasi, atau latihan harian (temuan uji perangkat 2). Mana yang dikerjakan: tugas tersendiri (cabang `fitur/Txx-pemuat-bank-verbal`) yang memuat bank ke database atau memori, menambah tipe VRB-SYN dan VRB-ANA ke `availableTypesProvider`, dan membuat soal bank ikut flow sesi dan pembahasan? Saya berhenti di sini dan tidak menulis logikanya.
- Temuan uji perangkat 2 (Back sistem menutup app dari wizard profil, teks terpotong di skala 1,3 dan 2,0, target waktu 394 dtk di pembahasan, placeholder Wawancara) belum dikerjakan; rincian di `uji-perangkat/LAPORAN-2.md` (lokal, tidak di-commit).
