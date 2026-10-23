# Checklist manual v1.0.0

Dijalankan pemilik di HP Android asli dan di Chrome Android, sebelum membuat tag `v1.0.0` (kriteria rilis di `docs/08-rencana-tes.md`). Centang `[x]` bila lulus. Bila gagal, tulis di kolom Catatan dan buat issue dengan label `bug`, `severity:1/2/3`, dan ID fitur. Bug `severity:1` (soal salah, data hilang, sesi rusak) harus selesai sebelum rilis.

| Hal | Isi |
|---|---|
| Tanggal uji | |
| HP dan versi Android | |
| Versi app (APK dari mana) | |
| Penandatangan APK | kunci debug / keystore pemilik |
| Browser untuk demo web | |

## 0. Persiapan (langkah pemilik)

- [ ] Bank verbal 300 soal **belum dibuat** (sengaja tidak dijalankan di T20). Tanpa bank, app tetap berjalan dan subtes verbal dilewati. Untuk menguji verbal, jalankan satu kali langkah di `tool/pregenerate/README.md` (`gen_verbal.py`, `verify_verbal.py`, `bundle.py`), periksa 10% sampel di `docs/eval/verbal_sample.md`, buka komentar `assets/verbal_bank.json` di `pubspec.yaml`, lalu bangun ulang APK. Pilih salah satu dan catat: [ ] diuji tanpa bank verbal, [ ] diuji dengan bank verbal.
- [ ] APK terpasang di HP (lihat `docs/RILIS-APK.md`, bagian 3 atau 4). Catatan: bila pernah memasang build lama (`com.example...`), itu app berbeda dan boleh dicopot.
- [ ] CI hijau di `main` dan integration_test lulus (`bash tool/run_integration.sh`).

## 1. Sesi tidak hilang

- [ ] **Layar mati saat simulasi.** Mulai Simulasi dari tab Psikotes. Jawab dua soal, tekan tombol daya sampai layar mati, tunggu 1 menit, nyalakan lagi. Posisi soal, jawaban, dan sisa waktu benar (sisa waktu sudah berkurang sekitar 1 menit, tidak berhenti). Catatan:
- [ ] **Matikan paksa lalu lanjut.** Di tengah simulasi: buka daftar app terbaru, geser app ke luar (matikan paksa). Tunggu 30 detik, buka lagi. Beranda menampilkan "Lanjutkan simulasi"; ketuk, posisi dan jawaban sama, sisa waktu sudah berkurang sekitar 30 detik. Catatan:
- [ ] Hal yang sama di Latihan: jawab 3 soal, matikan paksa, buka lagi, "Lanjutkan latihan" membuka soal ke-4 dengan jawaban 1 sampai 3 tersimpan. Catatan:
- [ ] Waktu subtes habis saat app tertutup: mulai simulasi, tutup app lewat batas waktu subtes pertama, buka lagi. Pindah ke subtes berikutnya dengan pesan "Waktu subtes ... habis" dan durasi penuh. Catatan:
- [ ] Ubah jam HP (Pengaturan sistem, tanggal dan waktu) maju 10 menit saat simulasi berjalan dan app terbuka: sisa waktu tidak melompat. Kembalikan jam ke otomatis sesudahnya. Catatan:

## 2. Tampilan: ukuran huruf

Pengaturan HP, Tampilan, Ukuran font. Ukur dengan skala 1,0 (bawaan), 1,3, 1,6, dan 2,0 (terbesar; bila slider HP hanya sampai 1,3, ambil yang terbesar dan catat). Untuk tiap skala buka: Beranda, Psikotes (katalog), Simulasi (ringkasan subtes), satu soal teks di Latihan, satu soal bergambar, Hasil, Pembahasan, Buku kesalahan, Statistik, Capture (formulir), Pengaturan.

| Skala | Tidak ada teks terpotong atau saling menimpa | Semua tombol bisa diketuk | Catatan |
|---|---|---|---|
| 1,0 | [ ] | [ ] | |
| 1,3 | [ ] | [ ] | |
| 1,6 | [ ] | [ ] | |
| 2,0 | [ ] | [ ] | |

- [ ] Soal bergambar (matriks 3x3, cermin, deret gambar) terbaca di layar 360 dp pada skala 1,0 dan 2,0: kotak, opsi A sampai D, dan label tidak terpotong. Catatan:

## 3. Tema dan cahaya

- [ ] Tema terang terbaca di dalam ruangan dan **di luar ruangan pada cahaya terang** (kecerahan layar otomatis): teks utama, teks sekunder, dan tombol tidak kabur. Catatan:
- [ ] Aksen stabilo (kuning) tidak menyulitkan membaca teks hitam di atasnya (chip terpilih, tab aktif). Catatan:
- [ ] Pemilih tema di Pengaturan menampilkan keterangan "Tema gelap tersedia di v1.1 ...", dan app tetap terang walaupun pilihan Gelap atau Sistem dipilih dan HP diatur ke mode gelap saat HP diatur ke mode gelap. Catatan:
- [ ] Tema gelap: **tidak berlaku di v1.0.0** (T21). Diuji ulang di checklist v1.1.0.

## 4. Empat kondisi layar data

Untuk tiap layar, kondisi dengan teks dari `docs/05-spek-layar.md`, tanpa pesan exception mentah.

| Layar | Kosong | Memuat (kerangka baris, bukan spinner) | Galat dengan sebab dan "Coba lagi" | Offline |
|---|---|---|---|---|
| Beranda (S04) | [ ] | [ ] | [ ] | [ ] |
| Katalog (S05) | [ ] | [ ] | [ ] | [ ] |
| Buku kesalahan (S10) | [ ] | [ ] | [ ] | [ ] |
| Statistik (S11) | [ ] | [ ] | [ ] | [ ] |
| Capture dan catatan (S12, S13) | [ ] | [ ] | [ ] | [ ] |

Cara memicu: Kosong dengan data baru (setelah memasang ulang, atau profil baru tanpa riwayat). Memuat: perhatikan sesaat saat membuka layar dari awal. Galat sulit dipicu di HP; bila tidak bisa dipicu, tulis "dicakup test widget" dan lewati. Offline: nyalakan mode pesawat dan buka semua layar di atas; seluruh psikotes harus berjalan normal (tidak ada pesan "tidak ada koneksi"). Pembedaan "belum ada data" dan "filter kosong": di Buku kesalahan, pilih filter Capture saat belum ada kartu Capture, teksnya beda dari kondisi kosong awal.

- [ ] Mode pesawat: simulasi lengkap, hasil, pembahasan, buku kesalahan, statistik, Capture, ekspor backup semua berjalan. Catatan:

## 5. Soal dan hasil

- [ ] Satu sesi Latihan tiap tipe yang tersedia (Matriks 3x3, cermin, deret gambar, odd one out, deret angka, hitungan, soal cerita, silogisme): tidak ada soal yang kuncinya terasa salah atau opsi kembar. Bug soal = `severity:1`. Catatan:
- [ ] Pembahasan setelah menjawab dan di S09 masuk akal dan tidak kosong. Catatan:
- [ ] Skor di Hasil sama dengan hitungan manual (jumlah benar dibagi jumlah soal di rencana, soal tidak dijawab dihitung salah). Catatan:
- [ ] Soal salah masuk Buku kesalahan dan jadwalnya "Besok". Catatan:
- [ ] Diagnostik pertama dikerjakan sampai selesai dan hasilnya muncul di kolom "Sebelum" `docs/10-laporan-hasil.md` (gerbang v1). Catatan:

## 6. Capture, catatan, backup

- [ ] Capture: simpan satu soal dari teks, satu dengan foto dari kamera, satu dengan foto dari galeri. Latih dari bank pribadi. Foto tampil di soal. Catatan:
- [ ] Ekspor backup dari Pengaturan, simpan berkas JSON. Buka berkasnya di editor teks: tidak ada key API, tidak ada teks CV, tidak ada foto. Catatan:
- [ ] Impor backup di app yang sudah dikosongkan (Pengaturan sistem, Penyimpanan app, Hapus data, buka lagi, buat profil, lalu impor): soal Capture, kartu, riwayat sesi, dan profil kembali. Foto memang tidak ikut. Catatan:
- [ ] Berkas bukan backup (misalnya foto) ditolak dengan pesan jelas, data tidak berubah. Catatan:

## 7. Web

- [ ] Demo web bisa dibuka di Chrome Android tanpa login, dari alamat Pages **atau** dari build lokal (`flutter build web` lalu disajikan; lihat `docs/RILIS-APK.md`, bagian Pages menunggu keputusan). Catat salah satu: [ ] Pages, [ ] lokal, [ ] belum bisa diuji (repo privat). Catatan:
- [ ] Di web: buat profil, kerjakan satu latihan, muat ulang halaman, data (profil dan riwayat) masih ada. Catatan:
- [ ] Di web: Capture memakai galeri/berkas, bukan kamera langsung, dan tidak error. Catatan:

## 8. Satu tugas utama dari awal sampai selesai

- [ ] Dari app terpasang baru: buat profil, diagnostik, latihan hari ini, satu simulasi, lihat hasil dan pembahasan, buka buku kesalahan dan ulangi kartu, lihat statistik. Tidak ada langkah yang janggal, label tombol jelas, tidak buntu. Langkah yang janggal (tulis): 

## Rekap

| Hasil | Jumlah |
|---|---|
| Lulus | |
| Gagal `severity:1` | |
| Gagal `severity:2` | |
| Gagal `severity:3` | |

Keputusan: [ ] siap tag `v1.0.0` (lanjut ke `docs/RILIS-APK.md`, bagian 4) / [ ] perbaiki dulu.
