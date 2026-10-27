# Laporan pembuatan bank (angka untuk README)

Disalin dari laporan lokal `tool/pregenerate/out/*.json` (folder itu di-ignore git) pada 2026-10-27, supaya angkanya bisa dirujuk dari repo. Laporan dibuat ulang oleh skrip di `tool/pregenerate/`. Pass 1 (membuat) dan pass 2 (menjawab tanpa kunci) memakai model yang sama lewat `claude -p` (ADR-12); pass 2 bukan pemeriksa independen.

| Bank | Berkas | Kandidat pass 1 | Lolos pass 2 | Dibuang | Di bank | Sumber laporan |
|---|---|---|---|---|---|---|
| Verbal (VRB-SYN 150, VRB-ANA 150) | `assets/verbal_bank.json` | 380 | 352 | 28 (23 penjawab menandai ambigu, 5 jawaban beda dari kunci); 5 kembar dibuang saat bundel | 300 | `verify_report.json`, `bundle_report.json` |
| Pengetahuan role (3 role x 3 level x 20) | `assets/knowledge_bank.json` | 245 | 240 | 5 | 180 (semua `needsVerification`) | `knowledge_report.json`, `progress.md` T26 |
| Bacaan VRB-RC | `assets/reading_bank.json` | | | | 30 (belum dipakai app) | `reading_report.json` |
| Kepribadian (8 sifat x 12) | `assets/personality_pool.json` | | | | 96 pernyataan | `progress.md` T22 |

Pemeriksaan manual 10% sampel oleh pemilik belum dilakukan untuk bank verbal (`docs/eval/verbal_flags.txt` kosong) dan belum selesai untuk bank pengetahuan (`docs/eval/knowledge_flags.txt` berisi KB-BA-L-013, diganti kandidat lolos lain; total tetap 180).

Per role dan level, bank pengetahuan akhir: qa, mobile, ba masing-masing dasar 20, menengah 20, lanjut 20 (dihitung dari `assets/knowledge_bank.json`).
