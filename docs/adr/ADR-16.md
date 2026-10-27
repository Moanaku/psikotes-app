# ADR-16: Tes tanpa pilihan ganda berjalan di layar sendiri, tanpa sesi di database

Status: diterima

## Konteks

Kepribadian Papi-style (F12, T22) tidak punya jawaban benar, dan Kraepelin/Pauli (F13, T23) berupa isian angka berwaktu per kolom. Keduanya tidak cocok dengan sesi soal pilihan ganda (`SessionController`, tabel sesi dan jawaban): skor sesi, statistik, kelemahan per tipe, dan buku kesalahan semuanya mengandaikan satu kunci per soal. Memasukkan keduanya ke tabel itu berarti setiap pembaca data harus menyaring tipe ini, dan pilihan kepribadian akan tercatat sebagai "salah".

## Keputusan

Papi-style (S14, `/kepribadian/:id`) dan Kraepelin (`/kraepelin/:id`) adalah layar sendiri. Isinya ditentukan seed di rute (pasangan pernyataan, lembar angka), logikanya Dart murni (`personality.dart`, `KrpSheet`, `KraepelinRun`), dan hasilnya hanya hidup di layar. Keduanya tidak terdaftar di `GeneratorRegistry`; katalog membukanya lewat `ownScreenTypes`, dan simulasi S07 menandai subtes Kraepelin dan Kepribadian sebagai "Tes terpisah".

## Alasan

Skor, statistik, dan buku kesalahan tetap benar tanpa penyaring baru. Seed di rute membuat layar bisa dibuat ulang identik dan diuji tanpa database. Tidak ada migrasi skema untuk fitur yang cara menyimpan hasilnya belum diputuskan pemilik (Q13, Q14).

## Alternatif yang ditolak

- Menyimpan sebagai sesi biasa dengan `benar` diabaikan: tercampur ke skor, kelemahan, dan statistik.
- Tabel baru untuk hasil kepribadian dan Kraepelin sekarang: butuh migrasi dan keputusan tampilan riwayat yang belum ada.
- Mendaftarkan generator dengan kunci palsu: melanggar invarian "tepat satu jawaban benar".

## Konsekuensi

- Keluar di tengah tes menghapus pilihan; layar meminta konfirmasi.
- Simulasi Bank-style tidak memuat Kraepelin dan Kepribadian sampai Q13 dan Q14 dijawab.
- Menyimpan hasil nanti berarti tabel atau kolom baru dan ADR baru.
