# ADR-15: Rilis dari tag, integration_test di mesin uji Flutter, web dari aset yang dibangun

Status: diterima

## Konteks

T20 menutup v1. Ada empat hal yang harus diputuskan bersama: identitas app Android (masih `com.example`), tempat tiga integration_test berjalan agar CI bisa memakainya tanpa perangkat, cara menerbitkan web dan APK tanpa biaya, dan asal `sqlite3.wasm` dan `drift_worker.js` yang dibutuhkan database web (A44). Repo masih privat; GitHub Pages untuk repo privat butuh paket berbayar.

## Keputusan

`applicationId` dan namespace menjadi `io.github.moanaku.psikotes`; integration_test memakai app sungguhan dengan Drift di SQLite memori dan dijalankan dengan `flutter test <berkas> -d flutter-tester` (tanpa perangkat, juga bisa di HP dengan `-d <id>`); rilis dibuat oleh tag `v*` lewat workflow APK ke GitHub Releases, dan Pages hanya jalan manual atau pada tag; dua berkas web dibangun oleh `tool/prepare_web.sh` dan tidak di-commit.

## Alasan

- Nama paket `com.example` tidak boleh dipakai untuk rilis, dan tidak bisa diganti setelah app dipasang tanpa menjadi app lain.
- `flutter-tester` berjalan di CI Ubuntu tanpa emulator, GTK, atau chromedriver, dan menjalankan seluruh app dan database sungguhan; hasilnya sama di HP.
- Tag adalah satu-satunya pemicu rilis, jadi push biasa tidak pernah menerbitkan apa pun dan keystore hanya dibaca dari secret saat tag.
- `sqlite3.wasm` diambil dari paket `drift` yang sudah ada di cache pub (dibangun dari versi sqlite3 yang sama) dan worker dikompilasi dari sumber di repo, jadi tanpa unduhan dari luar dan tanpa biner di git.

## Alternatif yang ditolak

- Integration test di Chrome lewat `flutter drive`: butuh chromedriver dan jalur terpisah; belum perlu.
- Integration test di Linux desktop: butuh folder platform `linux/` dan paket GTK di CI.
- Menaruh `sqlite3.wasm` dan `drift_worker.js` di repo: 1 MB biner yang harus dijaga selaras dengan versi paket.
- Pages otomatis pada setiap push ke `main`: gagal terus selama repo privat tanpa paket berbayar.
- Menunggu keystore pemilik untuk bisa membangun APK: APK bertanda debug tetap dibangun dan ditandai jelas di catatan rilis.

## Konsekuensi

- `flutter-tester` hanya meluncurkan satu berkas per perintah, jadi `tool/run_integration.sh` menjalankannya satu per satu.
- Pemilik perlu mengisi empat secret dan membuat tag (`docs/RILIS-APK.md`); sampai itu APK rilis bertanda debug.
- Pages untuk repo privat tetap menunggu keputusan pemilik.
- Setelah mengubah versi paket `drift`, jalankan ulang `tool/prepare_web.sh`.
