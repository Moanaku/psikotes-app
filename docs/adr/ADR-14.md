# ADR-14: Waktu sesi dari deadline mutlak dengan penjaga perubahan jam

Status: diterima

## Konteks

Simulasi memakai timer per subtes dan harus melanjutkan sesi dengan sisa waktu yang benar setelah app ke latar belakang, layar mati, rotasi, atau proses dimatikan sistem (F05). Penghitung yang berkurang tiap detik berhenti saat proses mati dan meleset saat timer Dart tertunda. Jam dinding ikut berjalan selama app tertutup, tetapi bisa melompat bila pengguna atau jaringan mengubah jam perangkat; jam monoton tidak melompat, tetapi mulai dari nol di setiap proses dan di Android berhenti saat perangkat tidur.

## Keputusan

Sisa waktu dihitung dari `session.deadline` mutlak (UTC) dikurangi jam dinding, dan selama proses hidup `WallClockGuard` membandingkan jam dinding dengan jam monoton untuk mendeteksi perubahan jam lalu menggeser deadline yang tersimpan sebesar lompatannya.

## Alasan

Deadline mutlak satu-satunya nilai yang tetap benar setelah proses mati, karena hanya jam dinding yang berjalan saat app tertutup. Menggeser deadline saat jam berubah menjaga sisa waktu tetap sama, baik di memori maupun di database, sehingga pelanjutan setelah proses mati juga benar. Jam mundur selalu bisa dikenali (waktu nyata tidak mundur); jam maju hanya dikenali saat app berjalan terus, karena setelah jeda selisihnya bisa berarti perangkat tidur. Semua akses jam lewat antarmuka `Clock`, sehingga setiap kasus tepi diuji dengan jam palsu tanpa menyentuh jam sistem.

## Alternatif yang ditolak

- Penghitung mundur per detik yang disimpan berkala: salah setelah proses mati (waktu tertutup hilang) dan meleset bila timer tertunda.
- Jam monoton saja: mulai dari nol di proses baru dan berhenti saat perangkat tidur, jadi waktu tidur tidak terhitung.
- Jam dinding saja tanpa penjaga: memundurkan jam menambah waktu dan memajukannya menghabiskan subtes.
- Waktu dari server: melanggar aturan offline dan biaya Rp0.

## Konsekuensi

- Layar sesi wajib meneruskan siklus hidup app ke `SessionController.onPaused` dan `onResumed`; tanpa itu lompatan maju setelah perangkat tidur dianggap perubahan jam.
- Batas yang diterima (A46): jam dimajukan saat app tertutup atau di latar belakang dianggap waktu berlalu; jam dimundurkan saat app tertutup membatasi sisa waktu paling banyak durasi subtes.
- Subtes yang habis saat app tertutup ditutup; subtes berikutnya mulai saat dibuka dengan durasi penuh.
- `DateTime.now()` hanya ada di `SystemClock`; test lapisan memeriksanya.
