# Integration test

Tiga alur utama dari `docs/08-rencana-tes.md`, memakai app sungguhan: semua
layar dan router asli, repository Drift di atas SQLite memori. Yang diganti
hanya jam (maju per hari penuh), penanda waktu sesi, penyimpanan foto, dan
penyimpanan rahasia, supaya tidak ada yang menunggu waktu nyata.

| Berkas | Alur |
|---|---|
| `profil_sampai_statistik_test.dart` | Profil Umum, simulasi tiga subtes, hasil, pembahasan, statistik. Skor, jumlah kartu, dan menit di layar dicocokkan dengan isi database. |
| `buku_kesalahan_test.dart` | Jawaban salah membentuk kartu jatuh tempo besok; jam dimajukan; tiga ulangan benar (tangga 1, 3, 7 hari) menguasai kartu. |
| `capture_test.dart` | Simpan soal Capture, kerjakan di latihan, jawab salah, kartu muncul di buku kesalahan; ekspor backup lalu impor ke database bersih. |

Bank verbal 300 soal (`tool/pregenerate`) tidak dibutuhkan: simulasi memakai
tipe yang sudah terdaftar di engine dan melewati subtes verbal.

## Menjalankan tanpa perangkat (lokal dan CI)

```bash
bash tool/run_integration.sh
```

Ini memanggil `flutter test <berkas> -d flutter-tester` per berkas. Mesin uji
bawaan Flutter berjalan di komputer tanpa layar, tidak butuh HP, emulator,
atau Chrome. Syarat sama dengan test lain: `dart run build_runner build`
sudah dijalankan, dan pustaka SQLite ada (Windows: `sqlite3.dll` di PATH;
Linux: `libsqlite3-dev`). Satu berkas saja:

```bash
flutter test integration_test/capture_test.dart -d flutter-tester
```

Berkas dijalankan satu per satu karena `flutter-tester` menolak peluncuran
kedua dalam satu perintah ("Unable to start the app on the device").

## Menjalankan di HP atau emulator Android

Hubungkan HP (mode pengembang dan USB debugging aktif) atau nyalakan emulator,
lihat id perangkat dengan `flutter devices`, lalu:

```bash
flutter test integration_test -d <id>
```

Di perangkat, semua berkas bisa dijalankan sekaligus. Database tetap di
memori, jadi data app di HP tidak tersentuh. Perintah ini memasang build debug
app di perangkat dan memakai applicationId `io.github.moanaku.psikotes`.
`bash tool/run_integration.sh <id>` juga bisa dipakai.

## Menjalankan di browser

`flutter test` belum menjalankan `integration_test` di Chrome. Untuk web,
integration_test memakai `flutter drive` dengan chromedriver; alur yang sama
belum dicoba di jalur itu (lihat `docs/progress.md`, catatan T20).
