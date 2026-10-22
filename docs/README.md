# Dokumen develop: Simulator Psikotes IT

Paket ini adalah satu-satunya sumber kebenaran untuk membangun app. Blueprint awal (Doc di Claude) tetap jadi arsip keputusan; kalau ada selisih, berkas di folder ini yang berlaku.

## Urutan baca

| Berkas | Untuk siapa | Isi |
|---|---|---|
| [01-prd.md](01-prd.md) | Semua | Masalah, tujuan, scope, 18 fitur, kriteria penerimaan, nonfungsional |
| [02-arsitektur.md](02-arsitektur.md) | Developer | Lapisan, struktur folder, state, navigasi, antarmuka inti |
| [03-data-model.md](03-data-model.md) | Developer | Tabel Drift, indeks, SM-2, format ekspor backup |
| [04-sistem-desain.md](04-sistem-desain.md) | Developer, desainer | Token warna, huruf, jarak, komponen, aturan anti AI slop |
| [05-spek-layar.md](05-spek-layar.md) | Developer, QA | 20 layar: rute, data, kondisi, teks, tautan, kriteria |
| [06-bank-konten.md](06-bank-konten.md) | Developer | Katalog tipe soal, skema JSON, spek generator, pembuatan bank |
| [07-rencana-tugas.md](07-rencana-tugas.md) | Claude Code | Tugas per fitur dengan prompt siap tempel dan rekomendasi model |
| [08-rencana-tes.md](08-rencana-tes.md) | QA | Level tes, invarian engine, checklist manual, pelacakan bug |
| [09-keputusan.md](09-keputusan.md) | Semua | 12 ADR |
| [10-laporan-hasil.md](10-laporan-hasil.md) | Semua | Tabel metrik sebelum dan sesudah, kerangka README, bullet CV |
| [11-asumsi-dan-pertanyaan.md](11-asumsi-dan-pertanyaan.md) | Semua | Asumsi yang perlu dikonfirmasi dan pertanyaan terbuka |
| [progress.md](progress.md) | Semua | Kotak centang T01 sampai T32 |

Desain layar ada di artefak Claude Design "Desain UI Simulator Psikotes IT" (20 layar). Tautannya dicatat di [04-sistem-desain.md](04-sistem-desain.md).

## Status

| Hal | Status |
|---|---|
| Blueprint dan PRD | Siap |
| Desain 20 layar | Siap (wawancara UI saja) |
| Kerangka repo | Terverifikasi: analyze, test, dan test engine (VM dan Chrome) hijau (T01) |
| Tema dan komponen inti | Selesai: font, tema terang, 20 komponen, golden test, `check_tokens` diperkuat (T02) |
| Fondasi engine | Selesai: `Rng`, model `Question` dan `FigureSpec`, antarmuka generator dan solver, loop percobaan ulang, harness property test (T03) |
| Generator figural | FIG-MTX (T04), FIG-MIR, FIG-SEQ, FIG-ODD (T05) selesai: generator, solver, pengecoh, pembahasan, registry; 10.000 seed per kesulitan lolos |
| Kode fitur | Belum mulai |
| Daftar tes nyata yang sudah dijalani | Terbuka, menunggu dari pemilik |
| Penyedia LLM wawancara | Terbuka, diputuskan sebelum v1.3 |

## Langkah pertama pemilik repo

1. Buat repo kosong di GitHub (tanpa README, tanpa lisensi), lalu `git remote add origin <url>` dan `git push -u origin main`.
2. Di GitHub: Settings, Pages, Source: GitHub Actions (dipakai mulai T20). Branch protection untuk `main` bersifat opsional.
3. Taruh font Instrument Sans (lisensi OFL) di `assets/fonts/` (lihat `assets/fonts/README.md`).
4. Jalankan tugas T01 dari `07-rencana-tugas.md`.
5. Jawab Q1 sampai Q6 di `11-asumsi-dan-pertanyaan.md` sebelum tugas yang bergantung padanya.

## Aturan memperbarui dokumen

- Setiap keputusan penting menambah baris di `09-keputusan.md` dan satu berkas di `adr/`.
- Mengubah fitur atau layar: perbarui PRD, spek layar, dan rencana tes dalam satu pull request.
- ID fitur (F01 sampai F18) dan ID layar (S01 sampai S20) tidak diganti, dipakai lintas dokumen, label issue, dan nama commit.
