# ADR-13: Golden test mengacu pada Linux dengan versi Flutter yang dipin

Status: diterima

## Konteks

Golden test komponen (T02) pertama kali dibuat di Windows. CI jalan di Linux dan 19 dari 20 golden gagal dengan selisih 1,2% sampai 9,9% piksel, jauh di atas ambang 0,5%. Percobaan di WSL dengan versi Flutter yang sama seperti lokal (3.35.4) menghasilkan selisih yang hampir identik dengan CI (Flutter 3.47.7), jadi penyebabnya sistem operasi, bukan versi Flutter. Tata letak identik: golden tanpa teks (skeleton) lolos persis. Perbandingan golden Windows dengan Linux menunjukkan ukuran gambar sama, posisi elemen bergeser paling banyak 1 px, dan selisih hanya di tepi huruf dan ikon.

## Keputusan

Golden Linux dengan versi Flutter yang dipin di `.github/workflows/ci.yml` adalah acuan; Windows melewati test bertag `golden`, dan versi Flutter dipin lalu dinaikkan secara sengaja.

## Alasan

CI berjalan di Linux, jadi golden yang dibuat di sana cocok persis dengan yang diperiksa CI, dan ambang 0,5% tetap bermakna (menangkap geser warna, batas, atau ukuran). Versi yang mengambang bisa mengubah rasterisasi tanpa perubahan kode.

## Alternatif yang ditolak

- Menaikkan ambang ke sekitar 10%: meloloskan perubahan nyata pada komponen kecil.
- Golden hanya di CI tanpa tag: pengembang Windows melihat test gagal tanpa sebab kode.
- Golden terpisah per sistem operasi: dua set berkas yang harus dijaga, dan hanya satu yang dipakai CI.

## Konsekuensi

- Test golden diberi tag `golden` (lewat `goldenTest` di `test/core/golden_helper.dart`, tag didaftarkan di `dart_test.yaml`). Di Windows pakai `flutter test --exclude-tags golden`. CI menjalankan semuanya.
- Golden dibuat ulang dengan `bash tool/update_goldens.sh` (WSL di Windows, langsung di Linux); `--verify` memeriksa tanpa menimpa. Skrip membaca versi Flutter dari `ci.yml`.
- Menaikkan Flutter: ubah `flutter-version` di `ci.yml`, jalankan `update_goldens.sh`, tinjau selisih golden, dan commit bersama.
- Biaya: pengembangan di Windows tidak melihat regresi golden secara lokal tanpa WSL; ambang 0,5% dan isi test tidak diubah.
