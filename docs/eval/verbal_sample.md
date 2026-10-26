# Sampel pemeriksaan manual bank verbal

30 soal dari bank (300 soal), dipilih acak tetap (seed 7) dan seimbang antar tipe dan kesulitan. Kunci sudah ditandai (**tebal**).

Cara memeriksa: untuk tiap soal tanyakan (1) apakah kuncinya benar menurut KBBI, (2) apakah ada pengecoh yang juga bisa dibenarkan, (3) apakah pembahasan cocok. Soal yang meragukan: tulis ID-nya satu per baris di `docs/eval/verbal_flags.txt`, lalu jalankan ulang `python tool/pregenerate/bundle.py`. Soal bertanda dibuang dari bank sampai diperiksa, dan bundel mengisi penggantinya dari kandidat lolos lainnya.

## VRB-ANA-0007 (easy)

Lembar : Buku = Cabang : ...

- A. Nasabah
- B. **Bank**
- C. Tabungan
- D. Kantor

Pembahasan: Lembar adalah bagian dari buku. Cabang adalah bagian dari bank.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0008 (easy)

Hemat : Boros = Rajin : ...

- A. Giat
- B. **Malas**
- C. Gaji
- D. Kerja

Pembahasan: Hemat berlawanan dengan boros. Lawan kata rajin adalah malas.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0018 (easy)

Murah : Mahal = Langka : ...

- A. Unik
- B. Terbatas
- C. Berharga
- D. **Melimpah**

Pembahasan: Murah berlawanan arti dengan mahal. Langka (jarang ada) berlawanan arti dengan melimpah (banyak sekali). Terbatas justru mendekati arti langka.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0030 (easy)

Pesan : Pengirim = Jawaban : ...

- A. **Penjawab**
- B. Penanya
- C. Pembaca
- D. Pertanyaan

Pembahasan: Pesan disampaikan oleh pengirim; jawaban disampaikan oleh penjawab. Hubungannya hasil-pembuat. 'Penanya' adalah pihak yang berlawanan peran.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0031 (easy)

Termometer : Suhu = Stetoskop : ...

- A. Telinga
- B. Dokter
- C. **Detak jantung**
- D. Rumah sakit

Pembahasan: Termometer adalah alat untuk mengukur suhu; stetoskop adalah alat untuk mendengarkan detak jantung. Dokter adalah pemakai, bukan hal yang diukur.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0061 (medium)

Lembur : Lelah = Begadang : ...

- A. Kopi
- B. **Mengantuk**
- C. Tidur
- D. Malam

Pembahasan: Lembur yang berlebihan menyebabkan lelah; begadang menyebabkan mengantuk. Tidur adalah lawan dari kegiatan begadang, bukan akibatnya.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0065 (medium)

Kelalaian : Kecelakaan = Ketekunan : ...

- A. **Keberhasilan**
- B. Tugas
- C. Kerja
- D. Kemalasan

Pembahasan: Kelalaian dapat menyebabkan kecelakaan; ketekunan dapat menyebabkan keberhasilan. Kemalasan justru berlawanan dengan ketekunan.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0087 (medium)

Laboratorium : Percobaan = Studio : ...

- A. Musik
- B. Kaset
- C. Mikrofon
- D. **Rekaman**

Pembahasan: Laboratorium adalah tempat melakukan percobaan; studio adalah tempat melakukan rekaman. Mikrofon dan kaset adalah benda, sedangkan musik adalah isi yang direkam, bukan kegiatan di tempat itu.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0096 (medium)

Apoteker : obat = Juru masak : ...

- A. wajan
- B. **hidangan**
- C. pelanggan
- D. restoran

Pembahasan: Apoteker meracik dan menyediakan obat sebagai hasil kerjanya; juru masak menghasilkan hidangan. Wajan adalah alat, restoran tempat, pelanggan penerima.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0097 (medium)

Cedera : pincang = Dehidrasi berat : ...

- A. **pingsan**
- B. haus
- C. air
- D. minum

Pembahasan: Cedera pada kaki dapat menyebabkan pincang; dehidrasi berat dapat menyebabkan pingsan. Minum dan air adalah penanganan, sedangkan haus adalah gejala awal, bukan akibat parah.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0118 (hard)

Gejala alam : Pelangi = Bencana alam : ...

- A. Musim
- B. Mendung
- C. **Tanah longsor**
- D. Hujan lebat

Pembahasan: Pelangi adalah salah satu contoh gejala alam, dan tanah longsor adalah salah satu contoh bencana alam. Hujan lebat dan mendung bisa menjadi penyebab atau pertanda bencana, tetapi keduanya bukan bencana itu sendiri. Musim adalah pembagian waktu, bukan bencana.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0129 (hard)

Karbohidrat : nasi = Protein : ...

- A. **tempe**
- B. minyak
- C. gula
- D. garam

Pembahasan: Nasi adalah sumber karbohidrat, sama seperti tempe adalah sumber protein. Gula adalah karbohidrat, minyak adalah lemak, dan garam adalah mineral.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0152 (hard)

Kapas : Kain = Bijih besi : ...

- A. Tambang
- B. **Baja**
- C. Karat
- D. Pabrik

Pembahasan: Kain adalah produk olahan dari kapas, sebagaimana baja adalah produk olahan dari bijih besi. Tambang dan pabrik adalah tempat, sedangkan karat adalah hasil kerusakan, bukan produk olahan.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0153 (hard)

Produsen : Penawaran = Konsumen : ...

- A. Pasokan
- B. Distribusi
- C. **Permintaan**
- D. Pemasaran

Pembahasan: Produsen menciptakan sisi penawaran di pasar, sedangkan konsumen menciptakan sisi permintaan. Pasokan sama dengan penawaran sehingga merupakan relasi produsen, sedangkan distribusi dan pemasaran adalah kegiatan penyalur dan penjual.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-ANA-0156 (hard)

Sistem operasi : Linux = Bahasa pemrograman : ...

- A. Pemrogram
- B. Windows
- C. **Python**
- D. Kompilator

Pembahasan: Linux adalah contoh sistem operasi, dan Python adalah contoh bahasa pemrograman. Kompilator adalah alat penerjemah kode, pemrogram adalah pelakunya, dan Windows adalah contoh sistem operasi.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0004 (easy)

Padanan kata "balas" adalah ...

- A. teruskan
- B. tanya
- C. kirim
- D. **jawab**

Pembahasan: Membalas pesan sama dengan menjawab pesan. Mengirim, bertanya, dan meneruskan adalah tindakan berbeda.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0011 (easy)

Padanan kata "cepat" adalah ...

- A. Lambat
- B. **Lekas**
- C. Santai
- D. Tertib

Pembahasan: "Cepat" bersinonim dengan "lekas", yaitu tidak memakan banyak waktu. "Lambat" adalah antonimnya.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0025 (easy)

Lawan kata "mudah" adalah ...

- A. singkat
- B. ringan
- C. **sukar**
- D. biasa

Pembahasan: Mudah berarti tidak memerlukan banyak tenaga atau pikiran; lawannya sukar atau sulit. Ringan mirip maknanya dengan mudah, bukan lawan.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0031 (easy)

Padanan kata "sehat" adalah ...

- A. pucat
- B. **bugar**
- C. sakit
- D. lemas

Pembahasan: Sehat berarti dalam keadaan baik badan dan jiwanya; bugar bersinonim dengan sehat. Lemas, sakit, dan pucat menggambarkan kondisi tubuh yang tidak baik.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0052 (easy)

Padanan kata "bicara" adalah ...

- A. **tutur**
- B. dengar
- C. bisik
- D. diam

Pembahasan: Bicara bersinonim dengan tutur, yaitu mengucapkan kata-kata. Bisik hanya cara berbicara pelan, sedangkan diam adalah lawan kata dan dengar bukan padanan.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0062 (medium)

Lawan kata "MENYETUJUI" adalah ...

- A. **menolak**
- B. membenarkan
- C. mengesahkan
- D. menyepakati

Pembahasan: Menyetujui berarti menyatakan sepaham atau membolehkan; lawannya menolak. Pilihan lain bermakna sama atau mirip dengan menyetujui.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0064 (medium)

Lawan kata "PERMANEN" adalah ...

- A. berkala
- B. tetap
- C. **sementara**
- D. tahunan

Pembahasan: Permanen berarti tetap atau tidak berubah dalam waktu lama; lawannya sementara. Tetap bersinonim dengan permanen, sedangkan tahunan dan berkala menyangkut keteraturan waktu.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0081 (medium)

Lawan kata "EKSPOR" adalah ...

- A. produksi
- B. distribusi
- C. konsumsi
- D. **impor**

Pembahasan: Ekspor adalah pengiriman barang ke luar negeri, sedangkan impor adalah pemasukan barang dari luar negeri.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0096 (medium)

Lawan kata "BUGAR" adalah ...

- A. gemuk
- B. **lesu**
- C. kurus
- D. pendiam

Pembahasan: Bugar berarti segar dan sehat badannya; lawannya lesu, yaitu tidak bersemangat dan lemah. Kurus, gemuk, dan pendiam tidak berkaitan dengan kebugaran.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0099 (medium)

Lawan kata "PULIH" adalah ...

- A. **memburuk**
- B. menetap
- C. menyembuh
- D. berobat

Pembahasan: Pulih berarti kembali baik seperti semula; lawannya memburuk, yaitu menjadi lebih buruk. Menyembuh sepadan dengan pulih, sedangkan berobat adalah upaya, bukan kebalikannya.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0117 (hard)

Padanan kata "esensial" adalah ...

- A. sekunder
- B. tambahan
- C. opsional
- D. **hakiki**

Pembahasan: Esensial berarti sangat mendasar atau pokok, sepadan dengan hakiki. Tambahan, opsional, dan sekunder bermakna tidak pokok.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0118 (hard)

Padanan kata "kolaborasi" adalah ...

- A. persaingan
- B. pengawasan
- C. pembagian
- D. **kerja sama**

Pembahasan: Kolaborasi berarti kerja sama antara beberapa pihak untuk mencapai tujuan bersama. Persaingan adalah kebalikannya, pembagian dan pengawasan berbeda makna.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0120 (hard)

Padanan kata "delegasi" dalam konteks pembagian tugas adalah ...

- A. penggabungan jabatan
- B. **pelimpahan wewenang**
- C. penolakan tugas
- D. pengawasan kerja

Pembahasan: Delegasi berarti penyerahan atau pelimpahan wewenang/tugas kepada orang lain. Pilihan lain tidak menggambarkan penyerahan wewenang.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0128 (hard)

Padanan kata "mangkir" adalah ...

- A. Cuti
- B. Mengundurkan diri
- C. **Absen tanpa alasan**
- D. Terlambat

Pembahasan: Mangkir berarti tidak hadir tanpa keterangan yang sah. Cuti adalah ketidakhadiran yang sah dan diizinkan.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

## VRB-SYN-0147 (hard)

Padanan kata "obsolet" adalah ...

- A. **usang**
- B. rusak
- C. lambat
- D. mahal

Pembahasan: Obsolet berarti sudah tidak terpakai lagi karena ketinggalan zaman, yaitu usang. Rusak, lambat, dan mahal tidak selalu berarti ketinggalan zaman.

Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)

