# Bullet CV

Hanya angka yang terukur dan tercantum di [README](../README.md) bagian Evaluasi. Belum ada pengguna selain pembuatnya, jadi tidak ada bullet tentang pengguna, skor, atau dampak. Perbarui angka bila README berubah.

- Membangun simulator psikotes IT offline (Flutter, Android dan web) dengan engine soal Dart murni yang deterministik: 11 tipe soal prosedural, termasuk soal bergambar, disimpan sebagai (tipe, seed, kesulitan) alih-alih soal utuh.
- Menjamin tiap soal punya tepat satu jawaban benar lewat solver terpisah dan property test: 330.000 soal per platform (11 tipe x 3 kesulitan x 10.000 seed) dijalankan di VM dan Chrome pada CI GitHub Actions.
- Menulis 1.343 test aplikasi dan 655 eksekusi test engine; `flutter analyze` bersih; APK rilis 58,1 MB; diuji di HP Android pada tiga skala huruf, empat temuan tata letak diperbaiki dan diuji ulang.
- Menyusun pipeline konten dengan LLM dan verifikasi dua pass untuk bank 300 soal verbal dan 180 butir pengetahuan role (28 dari 380 dan 5 dari 245 kandidat gugur), dengan batasan yang ditulis terang di README: semua butir pengetahuan masih "perlu verifikasi".
