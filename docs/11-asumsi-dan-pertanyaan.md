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
| A8 | Simetri rotasi bentuk: lingkaran, persegi, dan palang tampak sama di semua rotasi; belah ketupat (lebih tinggi daripada lebar) sama setelah 180 derajat; segitiga dan segi lima berbeda di keempat rotasi. Arsiran digambar dengan sudut tetap di layar. Dua opsi yang hanya berbeda pada rotasi tak terlihat dianggap kembar | `figure_spec.dart` (`Shape.rotationPeriod`), T04, T08 | Renderer T08 menggambar sesuai aturan ini, atau aturannya diubah bersama |
| A9 | Satu gambar `single` berisi 0 sampai 4 objek; 0 boleh untuk sel hasil pengurangan bentuk | `figure_spec.dart`, T04 | T04 menaikkan batas jika aturan penjumlahan butuh lebih |
| A10 | `QuestionType` memuat semua kode katalog kecuali KB-*, karena butir pengetahuan punya ID sendiri dan bukan soal pilihan ganda | `models.dart`, T25 | T25 |
| A11 | Teks opsi dibandingkan tanpa spasi berlebih dan tanpa beda huruf besar saat memeriksa opsi kembar | `models.dart` (`visualKey`) | Generator verbal atau IT yang butuh beda huruf besar mengusulkan perubahan |
| A12 | `estimatedSeconds` dibatasi 1 sampai 600 detik | `models.dart` | Generator yang butuh lebih lama mengusulkan perubahan |

## Pertanyaan terbuka

| No | Pertanyaan | Dibutuhkan sebelum |
|---|---|---|
| Q1 | Daftar tes nyata yang sudah dijalani (perusahaan, subtes, jumlah soal, durasi) untuk mengganti angka template blueprint | T11 |
| Q2 | Penyedia LLM wawancara: Gemini atau Groq | T31 |
| Q3 | Bahasa default wawancara: Indonesia, English, atau Campuran | T31 |
| Q4 | Pustaka OCR untuk Android | T27 |
| Q5 | STT dan TTS untuk suara | T32 |
| Q6 | Lisensi repo (usulan: MIT untuk kode, konten bank soal dimiliki pemilik) dan nama repo | T01 |
