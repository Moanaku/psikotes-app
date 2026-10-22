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
| A13 | FIG-MTX: opsi 7 sampai 8 = kunci + satu salinan sel lain + 5 sampai 6 pengecoh yang melanggar tepat satu aturan. "5 sampai 7 kandidat ditambah satu salinan" tidak muat dalam batas 8 opsi bila 7, jadi diambil 5 sampai 6 (biasanya 6) | `fig_mtx.dart` (`maxSingleViolations`), T04 | Pemilik setuju, atau batas opsi dinaikkan |
| A14 | FIG-MTX: ciri yang tidak diatur dibuat tetap di semua sel dan dihitung sebagai aturan tersirat; pengecoh boleh melanggar aturan tersirat. Tanpa ini easy (1 aturan) tidak punya cukup pengecoh | `fig_mtx.dart`, T04 | Pemilik setuju |
| A15 | FIG-MTX: aturan distribusi hanya di hard; hard = 3 aturan, atau 2 aturan dengan sedikitnya satu distribusi (peluang sama). Easy dan medium memakai konstan per baris, naik per kolom (jumlah, ukuran), rotasi bertahap 90 derajat, penjumlahan dan pengurangan bentuk | `fig_mtx.dart` (`pickRules`), T04 | Pemilik setuju |
| A16 | FIG-MTX: penjumlahan bentuk memakai himpunan bentuk yang saling lepas (gabungan sama dengan xor); pengurangan memakai bentuk kolom 2 sebagai bagian dari kolom 1. Tiap bentuk muncul sekali, sehingga aturan ini juga mengatur jumlah. Sel tidak pernah kosong (A9 tidak dipakai) | `fig_mtx.dart`, T04 | Pemilik setuju |
| A17 | FIG-MTX: aturan rotasi bertabrakan dengan aturan bentuk, karena rotasi hanya terlihat pada satu bentuk tetap yang tidak simetris (segitiga atau segi lima). Bila bentuk berubah antar sel, rotasi 0 | `fig_mtx.dart` (`MtxRule.collidesWith`), T04 | T08 |
| A18 | FIG-MTX: solver tidak membaca tag; ia menyimpulkan aturan dari 8 sel (konstan, distribusi multiset, deret aritmetika, rotasi siklik, operasi himpunan, tambah dan kurang jumlah, per baris dan per kolom). Generator menolak matriks bila ada tafsiran yang meramalkan nilai lain, termasuk nilai yang tidak bisa digambar. Isian dianggap bertingkat (kosong, arsir, penuh) | `fig_mtx_solver.dart`, T04 | Pemilik setuju |
| A19 | FIG-MTX: "pembahasan menyebut aturan per baris dan kolom" ditafsirkan: tiap aturan disebut dengan arah bacanya ("Baris:" atau "Kolom:") dan contoh nilainya, lalu ciri yang tetap, lalu jawaban | `fig_mtx.dart`, T04 | Pemilik setuju |

## Pertanyaan terbuka

| No | Pertanyaan | Dibutuhkan sebelum |
|---|---|---|
| Q1 | Daftar tes nyata yang sudah dijalani (perusahaan, subtes, jumlah soal, durasi) untuk mengganti angka template blueprint | T11 |
| Q2 | Penyedia LLM wawancara: Gemini atau Groq | T31 |
| Q3 | Bahasa default wawancara: Indonesia, English, atau Campuran | T31 |
| Q4 | Pustaka OCR untuk Android | T27 |
| Q5 | STT dan TTS untuk suara | T32 |
| Q6 | Lisensi repo (usulan: MIT untuk kode, konten bank soal dimiliki pemilik) dan nama repo | T01 |
