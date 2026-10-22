# Simulator Psikotes IT

App Flutter offline-first untuk berlatih psikotes kerja IT. Soal dibuat ulang setiap sesi, termasuk soal bergambar, dan latihan disusun dari role yang dilamar, tes target, dan kelemahan pribadi. Wawancara berbasis CV menyusul di v1.3. Gratis dan semua data tinggal di perangkat.

Status: perencanaan selesai, kode belum dimulai. Lihat [docs/README.md](docs/README.md).

## Isi repo

| Folder | Isi |
|---|---|
| `docs/` | PRD, arsitektur, data model, sistem desain, spek layar, bank konten, rencana tugas, rencana tes, keputusan |
| `lib/` | Kerangka app Flutter (tema, rute) |
| `packages/question_engine/` | Engine soal Dart murni dan tesnya |
| `tool/` | Skrip pembuat bank soal dan pemeriksa token |
| `assets/` | Font dan bank soal terbundel |

## Menjalankan

Butuh Flutter stabil dan Dart yang menyertainya.

```
flutter pub get
flutter analyze
flutter test
cd packages/question_engine && dart pub get && dart test -p vm,chrome
```

Kerangka ini belum pernah dikompilasi; tugas T01 di [docs/07-rencana-tugas.md](docs/07-rencana-tugas.md) memverifikasinya.

## Catatan hukum

App ini tidak berafiliasi dengan SHL, Criteria, atau penerbit tes mana pun. Soal dibuat dari generator sendiri dan hanya meniru format, durasi, dan gaya. Interpretasi kepribadian bersifat edukatif, bukan diagnosis.

## Kerangka case study (diisi setelah v1)

Masalah, demo, solusi, arsitektur dan keputusan, kualitas, hasil, pelajaran. Kerangka lengkap di [docs/10-laporan-hasil.md](docs/10-laporan-hasil.md).
