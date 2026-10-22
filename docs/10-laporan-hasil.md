# 10. Laporan hasil

Bagian ini diisi sambil berjalan dan menjadi bukti dampak di README dan CV. Isi kolom "Sebelum" dari diagnostik pertama, lalu perbarui setiap minggu. Jangan mengarang angka: sel yang belum ada datanya dibiarkan kosong.

## Metrik dampak

| Metrik | Sebelum | Minggu 2 | Minggu 4 | Sumber data |
|---|---|---|---|---|
| Skor simulasi (%) | | | | Statistik (F08) |
| Akurasi figural (%) | | | | Statistik (F08) |
| Median waktu per soal (detik) | | | | Statistik (F08) |
| Menit latihan per minggu | | | | Statistik (F08) |
| Kartu buku kesalahan yang dikuasai | | | | F07 |
| Tipe soal baru yang di-Capture | | | | F09 |
| Psikotes asli yang dijalani dan hasilnya | | | | F10 |

## Bukti engineering

| Bukti | Angka |
|---|---|
| Jumlah test otomatis | |
| Seed yang lolos property test per tipe | |
| Tipe soal yang bisa dibuat | |
| Konsistensi penilai wawancara pada test set | |

## Kerangka README case study

1. Masalah: satu paragraf dari pengalaman sendiri.
2. Demo: tautan web, tautan APK, video 60 sampai 90 detik.
3. Solusi: tiga fitur pembeda (soal selalu baru termasuk gambar, latihan sesuai role dan tes, wawancara dari CV).
4. Arsitektur dan keputusan: diagram dan tiga ADR terpenting (ADR-02, ADR-03, ADR-05).
5. Kualitas: strategi tes dan angka di atas.
6. Hasil: tabel metrik sebelum dan sesudah.
7. Yang dipelajari dan rencana berikutnya.

## Draf bullet CV (angka diisi setelah ada data)

- Membangun simulator psikotes IT (Flutter) dengan generator soal prosedural sehingga soal tidak berulang, termasuk soal bergambar yang di app lain berbayar.
- Merancang [X] property-based test yang menjamin setiap soal punya tepat satu jawaban benar, dengan CI GitHub Actions.
- Menambahkan simulasi wawancara berbasis CV dengan LLM (persona HR dan user) beserta evaluasi konsistensi penilaian.
- Dipakai sendiri selama [Y] minggu; skor simulasi naik dari [A]% ke [B]%.

Versi bullet bisa diganti penekanannya per lamaran: PRD dan user story untuk IT BA, rencana tes untuk QA, arsitektur untuk Developer.
