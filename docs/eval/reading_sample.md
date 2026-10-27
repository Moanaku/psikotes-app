# Sampel bank bacaan VRB-RC (T26)

Dibuat 2026-10-27: 3 dari 30 soal (sekitar 10%). Periksa apakah kuncinya benar menurut bacaan saja. Id yang meragukan ditulis di `docs/eval/reading_flags.txt` (pakai kode kandidat di judul, mis. RC003-2), lalu jalankan `python tool/pregenerate/gen_reading.py bundle`.

## VRB-RC-0001 (hard, kandidat RC001-1)

Tim Nusa Pesan beranggotakan lima orang dan bertugas menambahkan fitur pelacakan pesanan pada aplikasi pemesanan makanan. Pada minggu pertama, tim menyelesaikan rancangan tampilan. Minggu kedua dipakai untuk menulis kode, dan minggu ketiga untuk pengujian internal. Fitur ini awalnya dirilis hanya kepada sepuluh persen pengguna agar kesalahan yang muncul tidak memengaruhi semua orang. Jika dalam tiga hari tidak ada laporan gangguan serius, fitur dibuka bagi seluruh pengguna. Ketua tim, Rina, memutuskan menunda pengumuman resmi sampai rilis penuh selesai. Alasannya, tim ingin memastikan server mampu menahan lonjakan pesanan lebih dahulu.

Pernyataan: Server aplikasi pernah mengalami gangguan saat terjadi lonjakan pesanan sebelumnya.

**Kunci:** Tidak dapat ditentukan

**Alasan:** Bacaan hanya menyebut tim ingin memastikan server mampu menahan lonjakan, tanpa menyebut adanya gangguan di masa lalu.

## VRB-RC-0011 (easy, kandidat RC004-2)

Kebijakan cadangan data di perusahaan Lintas Arsip berjalan setiap hari pukul 02.00, ketika penggunaan sistem paling sepi. Cadangan penuh dibuat pada hari Minggu, sedangkan pada hari lain hanya data yang berubah sejak cadangan terakhir yang disalin. Setiap salinan disimpan di dua lokasi, yaitu server kantor dan penyimpanan awan. Salinan dipertahankan selama 30 hari, lalu dihapus otomatis. Setiap Senin, seorang petugas mencoba memulihkan satu berkas acak dari cadangan untuk memastikan salinan dapat dipakai. Hasil uji dicatat dalam laporan mingguan. Kebijakan ini disusun agar kehilangan data maksimal hanya sehari kerja.

Pernyataan: Cadangan penuh dibuat setiap hari pada pukul 02.00.

**Kunci:** Salah

**Alasan:** Cadangan penuh hanya dibuat pada hari Minggu; hari lain hanya data yang berubah yang disalin.

## VRB-RC-0021 (medium, kandidat RC007-3)

Tim Rantai Data memilih alat pelacak tugas baru karena alat lama sering lambat saat dibuka. Anggota tim menetapkan tiga kriteria: kemudahan penggunaan, kemampuan terhubung dengan repositori kode, dan biaya. Empat alat diuji selama dua minggu, dan setiap anggota memberi nilai 1 sampai 10 untuk tiap kriteria. Alat B mendapat nilai kemudahan tertinggi, tetapi tidak bisa terhubung dengan repositori kode. Alat C memiliki biaya terendah dan dapat terhubung dengan repositori. Karena kemampuan terhubung dengan repositori dianggap wajib, alat yang tidak memenuhinya disingkirkan. Akhirnya tim memilih Alat C, meskipun nilai kemudahannya lebih rendah daripada Alat B.

Pernyataan: Alat B tidak dipilih karena tidak memenuhi kriteria yang dianggap wajib.

**Kunci:** Benar

**Alasan:** Alat B tidak bisa terhubung dengan repositori kode, padahal kemampuan itu wajib sehingga alat yang tidak memenuhinya disingkirkan.
