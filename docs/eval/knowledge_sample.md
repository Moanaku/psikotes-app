# Sampel bank pengetahuan role (T26)

Dibuat 2026-10-27 dari `assets/knowledge_bank.json`: 18 dari 180 butir (sekitar 10%), tersebar di semua role dan level.

Periksa tiap butir: apakah pertanyaan jelas, jawaban model dan poin kunci benar dan tidak bergantung pada alat tertentu, dan rujukan masuk akal. Butir yang meragukan: tulis id-nya satu per baris di `docs/eval/knowledge_flags.txt`, lalu jalankan `python tool/pregenerate/gen_knowledge.py bundle`. Butir bertanda dibuang dari bank dan diganti kandidat lolos lain.

Semua butir bertanda perlu verifikasi: dua pass dilakukan oleh model yang sama, dan rujukan belum dicocokkan dengan teks aslinya.

## KB-QA-D-001 (test-case)

**Pertanyaan:** Apa yang dimaksud dengan test case dalam pengujian perangkat lunak?

**Jawaban model:** Test case adalah sekumpulan kondisi awal, input, langkah eksekusi, dan hasil yang diharapkan yang dirancang untuk memverifikasi satu tujuan pengujian tertentu. Dengan membandingkan hasil aktual dengan hasil yang diharapkan, penguji dapat menentukan apakah perilaku sistem sesuai.

**Poin kunci:**
- Test case dirancang untuk satu tujuan pengujian tertentu.
- Berisi input, langkah, dan hasil yang diharapkan.
- Hasil aktual dibandingkan dengan hasil yang diharapkan.
- Dari perbandingan itu ditentukan lulus atau gagal.

**Rujukan:** ISTQB Glossary

## KB-QA-D-016 (severity-priority)

**Pertanyaan:** Apa yang dimaksud dengan priority pada sebuah defect?

**Jawaban model:** Priority adalah tingkat urgensi atau urutan defect untuk diperbaiki. Priority mempertimbangkan kebutuhan bisnis, jadwal rilis, dan risiko. Karena itu nilainya bisa berubah mengikuti situasi proyek.

**Poin kunci:**
- Priority menunjukkan seberapa cepat defect perlu diperbaiki.
- Priority dipengaruhi kebutuhan bisnis dan jadwal rilis.
- Priority dapat berubah seiring perubahan kondisi proyek.
- Priority membantu tim mengatur urutan pekerjaan perbaikan.

**Rujukan:** ISTQB Glossary

## KB-QA-M-003 (boundary-value)

**Pertanyaan:** Sebuah kolom isian menerima bilangan bulat dalam rentang tertentu, partisi dan nilai uji apa yang kamu rancang?

**Jawaban model:** Ada tiga partisi: invalid di bawah rentang, valid di dalam rentang, dan invalid di atas rentang. Untuk batas, pilih nilai tepat di batas bawah dan atas, serta nilai satu langkah di luar masing-masing batas. Tambahkan satu nilai representatif dari tengah partisi valid untuk cakupan partisi.

**Poin kunci:**
- Rentang valid menghasilkan tiga partisi: invalid bawah, valid, dan invalid atas.
- Uji nilai tepat di batas bawah dan batas atas rentang valid.
- Uji nilai satu satuan di luar setiap batas, yang berada di partisi invalid.
- Satu nilai dari tengah partisi valid mewakili anggota partisi lainnya.
- Partisi tambahan seperti input kosong atau bukan angka dapat dipertimbangkan secara terpisah.

**Rujukan:** ISTQB Foundation Level Syllabus

## KB-QA-M-013 (siklus-bug)

**Pertanyaan:** Apa yang sebaiknya kamu lakukan ketika pengembang menyatakan bug yang kamu laporkan tidak dapat direproduksi?

**Jawaban model:** Periksa kembali langkah reproduksi dan bandingkan lingkungan, data, serta konfigurasi antara pengujimu dan pengembang. Tambahkan informasi yang kurang seperti log, rekaman, waktu kejadian, dan frekuensi muncul, lalu coba reproduksi bersama bila perlu. Jika masalah memang sporadis, catat kondisinya dan biarkan tiket tetap terbuka atau ditandai khusus sampai ada bukti tambahan.

**Poin kunci:**
- Verifikasi ulang langkah dan kondisi awal yang dipakai.
- Bandingkan lingkungan, data uji, dan konfigurasi.
- Lampirkan log atau rekaman yang menangkap kejadian.
- Catat bila bug bersifat sporadis dan kapan terakhir terjadi.
- Berkolaborasi langsung dengan pengembang untuk mereproduksi bersama.

**Rujukan:** tidak ada

## KB-QA-L-001 (strategi-tes)

**Pertanyaan:** Bagaimana Anda menyusun strategi tes untuk sebuah rilis ketika waktu terbatas dan tidak semua fitur bisa diuji sama dalam?

**Jawaban model:** Saya mulai dari analisis risiko: menilai kemungkinan terjadinya cacat dan dampaknya terhadap bisnis serta pengguna, lalu mengalokasikan upaya tes sebanding dengan tingkat risiko. Area berisiko tinggi mendapat tes lebih dalam dan lebih awal, sedangkan area berisiko rendah cukup dengan tes ringan. Keputusan ini saya komunikasikan kepada pemangku kepentingan agar risiko yang diterima disepakati bersama.

**Poin kunci:**
- Prioritas tes ditentukan oleh tingkat risiko, yaitu kombinasi kemungkinan dan dampak.
- Area berisiko tinggi diuji lebih dalam dan lebih awal.
- Area berisiko rendah boleh diuji lebih ringan, dan keputusan itu didokumentasikan.
- Risiko residual dikomunikasikan kepada pemangku kepentingan agar diterima secara sadar.

**Rujukan:** ISTQB Foundation Level Syllabus

## KB-QA-L-015 (ci)

**Pertanyaan:** Bagaimana Anda menyusun urutan tahapan pengujian dalam pipeline CI agar umpan balik cepat tetapi risiko tetap terkendali?

**Jawaban model:** Susun tahapan dari yang tercepat dan paling murah ke yang paling lambat dan mahal, sehingga kegagalan terdeteksi sedini mungkin. Pemeriksaan statis dan uji unit dijalankan lebih dulu pada setiap perubahan, lalu uji integrasi, dan uji end-to-end serta uji non-fungsional yang berat dijalankan belakangan atau pada jadwal tertentu. Pendekatan ini menghemat sumber daya karena build yang sudah gagal di tahap awal tidak menghabiskan waktu di tahap mahal.

**Poin kunci:**
- Tahap cepat dan murah dijalankan lebih dulu.
- Kegagalan awal menghentikan tahap berikutnya agar sumber daya tidak terbuang.
- Uji unit dan analisis statis memberi umpan balik paling cepat pada setiap perubahan.
- Uji end-to-end dan uji berat ditempatkan di tahap akhir atau dijadwalkan terpisah.
- Urutan perlu ditinjau ulang berdasarkan data kegagalan dan durasi nyata.

**Rujukan:** tidak ada

## KB-MOB-D-001 (siklus-hidup-layar)

**Pertanyaan:** Apa yang dimaksud dengan siklus hidup layar pada aplikasi mobile?

**Jawaban model:** Siklus hidup layar adalah rangkaian tahap yang dilalui sebuah layar, mulai dari dibuat, tampil, tidak aktif, sampai dihancurkan. Pada setiap perubahan tahap, sistem atau framework memanggil fungsi tertentu sehingga developer bisa menjalankan kode yang sesuai.

**Poin kunci:**
- Layar melewati tahap dibuat, tampil, tidak aktif, dan dihancurkan.
- Sistem atau framework memanggil fungsi khusus pada setiap perubahan tahap.
- Developer menaruh kode di fungsi yang tepat sesuai kebutuhan tiap tahap.
- Perpindahan tahap dipicu oleh tindakan pengguna maupun keputusan sistem.

**Rujukan:** Dokumentasi Android Developers

## KB-MOB-D-013 (state)

**Pertanyaan:** Mengapa sebaiknya kita mengubah state dan bukan mengubah elemen tampilan secara langsung?

**Jawaban model:** Jika state menjadi satu-satunya sumber kebenaran, tampilan selalu konsisten dengan datanya. Mengubah elemen tampilan secara langsung membuat data dan tampilan bisa tidak sinkron, sehingga memunculkan bug yang sulit dilacak. Dengan mengubah state, logika pembaruan tampilan cukup ditulis di satu tempat.

**Poin kunci:**
- State sebaiknya menjadi sumber kebenaran tunggal.
- Mengubah tampilan langsung dapat membuat data dan tampilan tidak sinkron.
- Logika tampilan terpusat sehingga lebih mudah dipahami dan diuji.
- Bug akibat tampilan yang usang menjadi lebih jarang.

**Rujukan:** tidak ada

## KB-MOB-M-001 (arsitektur-mvvm)

**Pertanyaan:** Mengapa ViewModel sebaiknya tidak menyimpan referensi langsung ke objek tampilan seperti Activity, Fragment, ViewController, atau Widget?

**Jawaban model:** ViewModel yang memegang referensi ke tampilan membuat logika terikat pada siklus hidup UI, sehingga berisiko menyebabkan kebocoran memori dan sulit diuji tanpa lingkungan UI. Dengan hanya mengekspos state yang diamati oleh tampilan, ViewModel tetap independen dan bisa diuji sebagai unit biasa. Arah ketergantungan yang benar adalah tampilan mengetahui ViewModel, bukan sebaliknya.

**Poin kunci:**
- Tampilan bergantung pada ViewModel, bukan sebaliknya.
- Referensi ke tampilan dapat bocor ketika tampilan dihancurkan tetapi ViewModel masih hidup.
- ViewModel tanpa dependensi UI bisa diuji sebagai unit test biasa.
- ViewModel berkomunikasi lewat state atau event yang diamati.

**Rujukan:** Dokumentasi Android Developers

## KB-MOB-M-013 (async)

**Pertanyaan:** Bagaimana cara yang benar memperbarui tampilan setelah pekerjaan di thread latar belakang selesai?

**Jawaban model:** Komponen antarmuka umumnya hanya aman diakses dari thread utama. Setelah pekerjaan latar belakang selesai, hasilnya harus dikirim kembali ke thread utama, misalnya lewat mekanisme dispatch atau konteks eksekusi utama. Baru di sana state UI diperbarui.

**Poin kunci:**
- Objek UI umumnya tidak aman diakses dari thread selain thread utama.
- Hasil dari thread latar belakang dikirim kembali ke thread utama.
- Pembaruan state atau tampilan dilakukan di thread utama.
- Mengubah UI dari thread lain dapat menyebabkan crash atau tampilan rusak.

**Rujukan:** Dokumentasi Apple Developer

## KB-MOB-L-001 (performa)

**Pertanyaan:** Waktu start dingin aplikasi terasa lambat setelah beberapa fitur ditambahkan, bagaimana kamu mendiagnosis dan mengurangi penyebabnya secara sistematis?

**Jawaban model:** Mulai dengan mengukur, bukan menebak: rekam jejak (trace) proses start di perangkat nyata untuk melihat pekerjaan apa yang memblokir frame pertama. Setelah itu pindahkan atau tunda semua pekerjaan yang tidak dibutuhkan untuk tampilan pertama, seperti inisialisasi pustaka, pembacaan disk, dan jaringan. Ukur ulang setelah tiap perubahan agar dampaknya terbukti.

**Poin kunci:**
- Ukur dulu dengan profiling atau tracing sebelum mengoptimalkan.
- Fokus pada jalur kritis menuju frame pertama yang bermakna.
- Tunda atau pindahkan pekerjaan non-esensial dari thread utama.
- Perhatikan inisialisasi eager di titik masuk aplikasi, yang sering menumpuk diam-diam.
- Ukur ulang pada perangkat kelas bawah untuk memastikan perbaikan nyata.

**Rujukan:** Dokumentasi Android Developers

## KB-MOB-L-013 (kebocoran-memori)

**Pertanyaan:** Mengapa listener, observer, atau langganan stream yang tidak dilepas bisa membocorkan memori, dan bagaimana Anda menyusun disiplin pelepasannya?

**Jawaban model:** Sumber peristiwa menyimpan referensi ke pendengarnya, sehingga pendengar beserta objek yang ditangkapnya tidak bisa dilepas selama sumber masih hidup. Pasangkan setiap pendaftaran dengan pelepasan pada titik siklus hidup yang sepadan, misalnya mendaftar saat mulai tampil dan melepas saat selesai. Gunakan mekanisme yang terikat siklus hidup agar pelepasan tidak bergantung pada ingatan pengembang.

**Poin kunci:**
- Sumber peristiwa memegang referensi ke pendengar selama langganan aktif.
- Pendaftaran dan pelepasan harus berpasangan pada tahap siklus hidup yang sepadan.
- Sumber berumur lebih panjang daripada pendengar adalah pola risiko tertinggi.
- Komponen yang sadar siklus hidup mengurangi risiko lupa melepas.
- Review kode perlu memeriksa setiap pendaftaran punya pelepasan yang jelas.

**Rujukan:** tidak ada

## KB-BA-D-001 (requirement)

**Pertanyaan:** Apa yang dimaksud dengan requirement dalam analisis bisnis?

**Jawaban model:** Requirement adalah kebutuhan yang dinyatakan secara jelas tentang apa yang harus dipenuhi oleh suatu solusi agar memberi nilai bagi pemangku kepentingan. Requirement bisa berupa kondisi atau kemampuan yang dibutuhkan untuk menyelesaikan masalah atau mencapai tujuan. Requirement menjadi dasar bagi desain, pengembangan, dan pengujian solusi.

**Poin kunci:**
- Requirement menyatakan kebutuhan yang harus dipenuhi solusi.
- Requirement berasal dari kebutuhan pemangku kepentingan.
- Requirement terkait masalah atau tujuan yang ingin dicapai.
- Requirement menjadi dasar desain, pengembangan, dan pengujian.

**Rujukan:** BABOK Guide (IIBA)

## KB-BA-D-013 (user-story)

**Pertanyaan:** Mengapa user story sebaiknya berfokus pada nilai bagi pengguna dan bukan pada solusi teknis?

**Jawaban model:** Fokus pada nilai menjaga tim tetap memahami masalah yang ingin diselesaikan. Dengan begitu, tim bebas mencari solusi terbaik dan tidak terkunci pada satu cara implementasi. Story yang menentukan solusi teknis terlalu dini membatasi pilihan.

**Poin kunci:**
- Nilai bagi pengguna menjelaskan mengapa story dikerjakan.
- Fokus pada masalah memberi ruang untuk memilih solusi terbaik.
- Menetapkan solusi teknis terlalu dini membatasi pilihan tim.
- Story tetap dapat dipahami oleh pihak non-teknis.

**Rujukan:** tidak ada

## KB-BA-M-001 (bpmn)

**Pertanyaan:** Apa perbedaan sequence flow dan message flow dalam diagram BPMN, dan kapan masing-masing dipakai?

**Jawaban model:** Sequence flow menunjukkan urutan eksekusi elemen di dalam satu proses, sehingga tidak boleh melintasi batas pool. Message flow menggambarkan pertukaran pesan antara dua partisipan yang terpisah, misalnya antar pool. Jadi interaksi dengan pihak lain, seperti pelanggan atau sistem eksternal, digambarkan dengan message flow.

**Poin kunci:**
- Sequence flow mengatur urutan aktivitas dalam satu pool.
- Sequence flow tidak boleh menyeberangi batas pool.
- Message flow menghubungkan dua partisipan yang berbeda, misalnya antar pool.
- Message flow tidak dipakai untuk menghubungkan elemen dalam pool yang sama.

**Rujukan:** Spesifikasi BPMN (OMG)

## KB-BA-M-013 (prioritisasi)

**Pertanyaan:** Bagaimana model Kano membantu BA memprioritaskan fitur dibandingkan sekadar menanyakan fitur mana yang paling diinginkan pengguna?

**Jawaban model:** Model Kano membedakan fitur menurut hubungan antara tingkat pemenuhannya dan kepuasan pengguna, yaitu kebutuhan dasar, kebutuhan kinerja, dan pemikat. Kebutuhan dasar harus ada karena ketiadaannya menimbulkan ketidakpuasan, sedangkan pemikat memberi nilai tambah tetapi tidak diharapkan. Dengan begitu BA tidak hanya mengikuti permintaan terbanyak, melainkan menyeimbangkan investasi antarkategori.

**Poin kunci:**
- Fitur dasar tidak menambah kepuasan bila ada, tetapi sangat mengecewakan bila tidak ada.
- Fitur kinerja meningkatkan kepuasan secara bertahap seiring tingkat pemenuhannya.
- Fitur pemikat tidak diharapkan, tetapi menciptakan kesan positif yang kuat.
- Kategori suatu fitur dapat bergeser seiring waktu dan ekspektasi pengguna.

**Rujukan:** tidak ada

## KB-BA-L-001 (analisis-dampak)

**Pertanyaan:** Ketika sponsor meminta perubahan requirement di tengah proyek, langkah apa yang kamu lakukan sebelum memberi estimasi dampak?

**Jawaban model:** Pertama, pastikan kebutuhan di balik permintaan itu dipahami: masalah bisnis apa yang ingin diselesaikan, bukan hanya solusi yang diminta. Setelah itu, identifikasi requirement, komponen, dan pemangku kepentingan yang terkait, lalu nilai dampaknya terhadap lingkup, jadwal, biaya, dan risiko. Estimasi baru diberikan setelah dampak tersebut dipetakan, bukan sebelumnya.

**Poin kunci:**
- Klarifikasi tujuan bisnis di balik perubahan, bukan hanya bentuk solusinya.
- Petakan requirement dan komponen yang terkait dengan perubahan.
- Identifikasi pemangku kepentingan yang terdampak.
- Nilai dampak pada lingkup, jadwal, biaya, dan risiko.
- Tunda estimasi sampai dependensi dipahami.

**Rujukan:** BABOK Guide (IIBA)

## KB-BA-L-014 (trade-off)

**Pertanyaan:** Bagaimana kamu menimbang perbaikan cepat jangka pendek terhadap perubahan struktural jangka panjang ketika bisnis menekan agar masalah segera teratasi?

**Jawaban model:** Saya akan memisahkan penanganan gejala dari akar masalah, lalu menawarkan solusi sementara yang jelas batasnya sambil merencanakan perbaikan struktural. Pemangku kepentingan perlu memahami biaya menunda perbaikan permanen, seperti utang teknis atau pekerjaan manual berulang. Solusi sementara harus punya pemilik, batas waktu, dan kriteria penggantian agar tidak menjadi permanen tanpa disadari.

**Poin kunci:**
- Bedakan gejala dari akar masalah sebelum memilih solusi.
- Solusi sementara dapat meredakan tekanan bisnis, asalkan batasnya dinyatakan terbuka.
- Tunjukkan biaya jangka panjang dari menunda perbaikan struktural.
- Tetapkan pemilik, tenggat, dan kriteria pengganti untuk solusi sementara.

**Rujukan:** BABOK Guide (IIBA)
