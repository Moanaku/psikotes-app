import 'package:question_engine/question_engine.dart';

import 'catalog.dart';
import 'session.dart';

/// Petunjuk dan trik per tipe soal untuk S06 ("Buka petunjuk") dan S09 ("Pola
/// dan trik"). `switch` tanpa cabang bawaan: tipe baru di engine membuat kode
/// ini gagal dikompilasi sampai diberi teks.

/// Aturan soal tanpa menyebut jawaban (S06).
String questionTypeHint(QuestionType type) => switch (type) {
      QuestionType.numSeq => 'Cari selisih atau perbandingan antar suku. '
          'Bila belum ketemu, pisahkan suku urutan ganjil dan genap.',
      QuestionType.numAri => 'Kerjakan yang di dalam kurung lebih dulu, lalu '
          'kali dan bagi dari kiri, baru tambah dan kurang.',
      QuestionType.numWord => 'Baca pertanyaannya dulu, lalu ambil hanya baris '
          'dan kolom tabel yang disebut.',
      QuestionType.logSyl => 'Anggap semua premis benar. Pilih kesimpulan yang '
          'pasti benar di setiap keadaan, bukan yang hanya mungkin.',
      QuestionType.figMtx => 'Baca tiap baris dan tiap kolom. Catat ciri yang '
          'berubah (jumlah, ukuran, isian, putaran) dan ciri yang tetap.',
      QuestionType.figSeq =>
        'Bandingkan gambar satu ke gambar berikutnya. Tiap '
            'ciri punya aturannya sendiri: bentuk, jumlah, ukuran, isian, atau '
            'putaran.',
      QuestionType.figMir => 'Bayangkan cermin di sisi yang disebut. Sumbu '
          'vertikal menukar kiri dan kanan, sumbu horizontal menukar atas dan '
          'bawah.',
      QuestionType.figOdd => 'Cari ciri yang dimiliki empat gambar sekaligus, '
          'lalu pilih gambar yang tidak memilikinya.',
      QuestionType.vrbSyn => 'Cari kata yang paling dekat artinya. Perhatikan '
          'apakah yang ditanya persamaan atau lawan kata.',
      QuestionType.vrbAna => 'Tentukan hubungan pasangan kata pertama, lalu '
          'cari pasangan lain dengan hubungan yang sama.',
      QuestionType.vrbRc => 'Baca pertanyaan lebih dulu, lalu cari jawabannya '
          'di bacaan. Jangan memakai pengetahuan di luar teks.',
      QuestionType.krp => 'Jaga kecepatan dan ketelitian. Jangan berhenti '
          'memperbaiki satu angka.',
      QuestionType.itPse => 'Telusuri kode langkah demi langkah dengan nilai '
          'awal dari soal. Catat nilai tiap variabel.',
      QuestionType.itFlw => 'Ikuti panah dari awal. Di tiap percabangan, '
          'putuskan jalur Ya atau Tidak dari nilai saat itu.',
      QuestionType.itXls => 'Hitung rumus dari dalam ke luar dan periksa '
          'rujukan sel serta rentangnya.',
      QuestionType.perPapi ||
      QuestionType.perDisc =>
        'Pilih pernyataan yang paling menggambarkan dirimu, bukan yang '
            'menurutmu dicari perusahaan.',
    };

/// Pola umum dan cara mempercepat tipe soal (S09, "Pola dan trik").
String questionTypeTrick(QuestionType type) => switch (type) {
      QuestionType.numSeq => 'Hitung selisih antar suku dulu, lalu cek apakah '
          'selisih itu punya pola sendiri. Deret selang-seling: tulis dua '
          'deret terpisah.',
      QuestionType.numAri => 'Perkirakan hasilnya lebih dulu untuk membuang '
          'opsi yang jauh. Pecahan, desimal, dan persen lebih mudah '
          'dibandingkan bila disamakan bentuknya.',
      QuestionType.numWord =>
        'Garis bawahi satuan dan baris yang ditanya. Baris '
            'lain di tabel sering hanya pengalih.',
      QuestionType.logSyl => 'Untuk setiap opsi, cari satu keadaan yang '
          'membuatnya salah. Bila ada, opsi itu belum pasti benar.',
      QuestionType.figMtx => 'Kerjakan satu ciri sekali waktu. Coret opsi yang '
          'melanggar satu saja dari aturan yang sudah kamu temukan.',
      QuestionType.figSeq => 'Cocokkan opsi dengan aturan per ciri, bukan '
          'dengan kesan keseluruhan. Putaran dihitung dari satu langkah ke '
          'langkah berikutnya.',
      QuestionType.figMir => 'Pindahkan sel satu per satu ke posisi cerminnya '
          'dan bandingkan dengan opsi. Waspada opsi yang hanya bergeser satu '
          'sel.',
      QuestionType.figOdd => 'Bila dua ciri tampak berbeda, uji ciri lain: '
          'hanya satu ciri yang benar-benar membedakan satu gambar.',
      QuestionType.vrbSyn =>
        'Coba kata itu dalam kalimat pendek. Bila dua opsi '
            'mirip, pilih yang paling umum dipakai.',
      QuestionType.vrbAna => 'Ubah hubungan menjadi kalimat ("A adalah bagian '
          'dari B"), lalu uji tiap opsi dengan kalimat yang sama.',
      QuestionType.vrbRc => 'Tandai kata kunci pertanyaan dan cari kata yang '
          'sama di bacaan sebelum memilih.',
      QuestionType.krp => 'Pertahankan ritme yang sama dari awal sampai akhir '
          'agar grafik konsistensimu rata.',
      QuestionType.itPse => 'Buat tabel kecil nilai variabel tiap iterasi. '
          'Kesalahan paling sering ada pada batas perulangan.',
      QuestionType.itFlw => 'Beri nomor tiap kotak lalu catat urutan yang kamu '
          'lewati. Periksa kondisi di percabangan dua kali.',
      QuestionType.itXls => 'Selesaikan fungsi paling dalam lebih dulu dan '
          'perhatikan rujukan mutlak dan relatif.',
      QuestionType.perPapi ||
      QuestionType.perDisc =>
        'Tidak ada jawaban benar. Jawab sesuai kebiasaanmu sehari-hari dan '
            'jaga konsistensi antar soal.',
    };

/// Nama butir rencana untuk judul layar: tipe engine, atau kategori buatan
/// pengguna untuk soal Capture.
String planItemName(PlanItem item) {
  final type = item.type;
  return type == null ? item.kategoriCode : questionTypeName(type);
}

/// Petunjuk butir rencana (S06). Soal Capture tidak punya aturan tipe.
String planItemHint(PlanItem item) {
  final type = item.type;
  return type == null
      ? 'Baca soal dan semua opsinya sampai habis. Buang opsi yang jelas '
          'salah, lalu pilih yang paling cocok.'
      : questionTypeHint(type);
}

/// "Pola dan trik" butir rencana (S09).
String planItemTrick(PlanItem item) {
  final type = item.type;
  return type == null
      ? 'Soal ini kamu simpan sendiri. Catat polanya di pembahasan lewat '
          'Capture supaya mudah dikenali di tes berikutnya.'
      : questionTypeTrick(type);
}
