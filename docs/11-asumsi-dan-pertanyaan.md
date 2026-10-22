# 11. Asumsi dan pertanyaan terbuka

Hal-hal yang ditulis sebagai asumsi agar pekerjaan tidak berhenti. Setiap butir perlu dikonfirmasi pemilik atau diganti keputusan.

## Asumsi yang dibuat saat menulis dokumen

| No | Asumsi | Di mana dipakai | Cara mengonfirmasi |
|---|---|---|---|
| A1 | "Jadwal ulang 1, 3, 7, 14 hari" ditafsirkan: tangga 1, 3, 7 untuk tiga ulangan, lalu satu pemeriksaan 14 hari setelah kartu dikuasai | `03-data-model.md`, T16 | Pemilik setuju atau menghapus pemeriksaan 14 hari |
| A2 | Role menaikkan bobot kategori terkait +50% relatif lalu dinormalkan | `06-bank-konten.md`, T11 | Diganti dengan data tes nyata (Q1) |
| A3 | Target durasi latihan harian 15 menit | `03-data-model.md`, T13 | Diubah di profil |
| A4 | Subtes default 20 soal dan 8 menit di S02 sebagai nilai awal | `05-spek-layar.md` | Diganti oleh blueprint format tes terpilih |
| A5 | Papan desain memakai angka contoh (profil kecenderungan, bilah progres, titik grafik) | Desain | Diganti data nyata saat implementasi |
| A6 | Ambang lolos kontras tema gelap sudah dihitung, tetapi belum diperiksa per layar | `04-sistem-desain.md`, T21 | T21 |
| A7 | Versi paket di `pubspec.yaml` adalah titik awal dan belum pernah dikompilasi | T01 | T01 |

## Pertanyaan terbuka

| No | Pertanyaan | Dibutuhkan sebelum |
|---|---|---|
| Q1 | Daftar tes nyata yang sudah dijalani (perusahaan, subtes, jumlah soal, durasi) untuk mengganti angka template blueprint | T11 |
| Q2 | Penyedia LLM wawancara: Gemini atau Groq | T31 |
| Q3 | Bahasa default wawancara: Indonesia, English, atau Campuran | T31 |
| Q4 | Pustaka OCR untuk Android | T27 |
| Q5 | STT dan TTS untuk suara | T32 |
| Q6 | Lisensi repo (usulan: MIT untuk kode, konten bank soal dimiliki pemilik) dan nama repo | T01 |
