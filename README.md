# Simulator Psikotes IT

App Flutter offline-first untuk berlatih psikotes kerja IT. Soal dibuat ulang setiap sesi, termasuk soal bergambar, dan latihan disusun dari role yang dilamar, tes target, dan kelemahan pribadi. Wawancara berbasis CV menyusul di v1.3. Gratis dan semua data tinggal di perangkat.

Status: fitur v1 selesai (T01 sampai T19) dan T20 (integrasi, build, rilis) sebagian; v1.0.0 menunggu checklist manual pemilik. Lihat [docs/README.md](docs/README.md), [CHANGELOG.md](CHANGELOG.md), dan [docs/RILIS-APK.md](docs/RILIS-APK.md).

## Isi repo

| Folder | Isi |
|---|---|
| `docs/` | PRD, arsitektur, data model, sistem desain, spek layar, bank konten, rencana tugas, rencana tes, keputusan |
| `lib/` | App Flutter (tema, komponen, data, domain, layar) |
| `integration_test/` | Tiga alur utama (lihat `integration_test/README.md`) |
| `packages/question_engine/` | Engine soal Dart murni dan tesnya |
| `tool/` | Skrip pembuat bank soal dan pemeriksa token |
| `assets/` | Font dan bank soal terbundel |

## Menjalankan

Butuh Flutter stabil dan Dart yang menyertainya.

```
flutter pub get
dart run build_runner build
flutter analyze
flutter test --exclude-tags golden
bash tool/run_integration.sh
cd packages/question_engine && dart pub get && dart test -p vm,chrome
```

Web: `bash tool/prepare_web.sh` lalu `flutter run -d chrome`. APK: `flutter build apk --release` (penandatanganan dan rilis: [docs/RILIS-APK.md](docs/RILIS-APK.md)). Detail perintah rutin ada di `CLAUDE.md`.

## Catatan hukum

App ini tidak berafiliasi dengan SHL, Criteria, atau penerbit tes mana pun. Soal dibuat dari generator sendiri dan hanya meniru format, durasi, dan gaya. Interpretasi kepribadian bersifat edukatif, bukan diagnosis.

## Kerangka case study (diisi setelah v1)

Masalah, demo, solusi, arsitektur dan keputusan, kualitas, hasil, pelajaran. Kerangka lengkap di [docs/10-laporan-hasil.md](docs/10-laporan-hasil.md).
