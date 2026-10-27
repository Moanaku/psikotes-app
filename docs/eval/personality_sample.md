# Sampel pool kepribadian (T22)

Dibuat 2026-10-27 dari `assets/personality_pool.json` (95 pernyataan, 8 sifat). Untuk diperiksa pemilik: nada netral, tanpa jawaban benar atau salah, tanpa istilah klinis, tidak mirip item tes resmi.
Pernyataan yang meragukan: tulis ID-nya satu per baris di `docs/eval/personality_flags.txt`, lalu jalankan `python tool/pregenerate/gen_personality.py --bundle-only`.

## Keteraturan dan ketelitian (`keteraturan`)

Kecenderungan bekerja terstruktur dan memeriksa detail sebelum selesai.

- `PER-KTR-001` Saya menyusun daftar tugas harian sebelum mulai mengerjakan proyek.
- `PER-KTR-002` Saya membaca ulang kode saya sebelum mengirim permintaan penggabungan ke tim.
- `PER-KTR-003` Saya memberi nama berkas dan folder dengan pola yang konsisten.

## Ketekunan (`ketekunan`)

Kecenderungan bertahan pada tugas sampai tuntas walau membosankan atau sulit.

- `PER-TKN-001` Saya menyelesaikan laporan mingguan sampai rapi meskipun isinya berulang dan memakan waktu.
- `PER-TKN-002` Saya mencoba pendekatan lain satu per satu ketika kode yang saya tulis belum berjalan sesuai harapan.
- `PER-TKN-003` Saya melanjutkan pengujian seluruh skenario sampai semua kasus tercatat, termasuk yang sangat sederhana.

## Inisiatif dan kemandirian (`inisiatif`)

Kecenderungan memulai sendiri, mencari jalan, dan bekerja tanpa banyak arahan.

- `PER-INS-001` Saya menyusun rencana kerja sendiri ketika menerima tugas baru tanpa petunjuk rinci.
- `PER-INS-002` Saya mengusulkan perbaikan pada alur proyek sebelum diminta oleh atasan.
- `PER-INS-003` Saya mencari dokumentasi dan contoh sendiri ketika menemui kendala teknis.

## Kerja sama tim (`kerjasama`)

Kecenderungan bekerja bersama, berbagi beban, dan menjaga suasana tim.

- `PER-KRS-002` Saya menawarkan bantuan kepada rekan yang sedang kewalahan menyelesaikan fitur menjelang tenggat.
- `PER-KRS-003` Saya menyampaikan ucapan terima kasih kepada rekan setelah ia membantu memperbaiki kode saya.
- `PER-KRS-004` Saya ikut menyiapkan agenda dan catatan rapat harian agar seluruh tim memiliki acuan yang sama.

## Komunikasi (`komunikasi`)

Kecenderungan menjelaskan, bertanya, dan menyampaikan pendapat dengan jelas.

- `PER-KOM-001` Saya menjelaskan langkah kerja kepada rekan tim sebelum mulai mengerjakan bagian proyek bersama.
- `PER-KOM-002` Saya mengajukan pertanyaan lanjutan ketika arahan dari atasan masih memiliki bagian yang belum terang.
- `PER-KOM-003` Saya menyampaikan pendapat saya dalam rapat harian dengan contoh yang mudah dipahami.

## Mengarahkan orang lain (`kepemimpinan`)

Kecenderungan mengambil peran memimpin, membagi tugas, dan mengambil keputusan.

- `PER-PIM-001` Saya membagi tugas proyek kepada anggota tim berdasarkan keahlian masing-masing.
- `PER-PIM-002` Saya langsung mengambil keputusan ketika tim menghadapi dua pilihan teknis yang seimbang.
- `PER-PIM-003` Saya menawarkan diri memimpin rapat harian ketika belum ada yang ditunjuk.

## Tenang saat ditekan (`ketenangan`)

Kecenderungan tetap fokus ketika tenggat dekat, ada masalah, atau rencana berubah.

- `PER-TEN-001` Saya menyusun ulang urutan tugas dengan tenang ketika tenggat proyek tiba-tiba dimajukan.
- `PER-TEN-002` Saya menjaga nada bicara tetap stabil ketika klien menyampaikan perubahan kebutuhan di tengah rapat.
- `PER-TEN-003` Saya melanjutkan pengerjaan fitur sesuai prioritas saat banyak pesan masuk meminta perhatian sekaligus.

## Rasa ingin tahu (`belajar`)

Kecenderungan mencari tahu cara kerja sesuatu dan mempelajari hal baru.

- `PER-BLJ-001` Saya membongkar alur kode lama sampai paham cara kerjanya sebelum mengubahnya.
- `PER-BLJ-002` Saya membaca dokumentasi teknis versi terbaru saat tim mulai memakai pustaka baru.
- `PER-BLJ-003` Saya menanyakan alasan di balik sebuah keputusan arsitektur ketika rapat perencanaan proyek.
