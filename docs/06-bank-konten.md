# 06. Bank konten dan spesifikasi generator

Setiap tipe soal adalah generator dengan tiga bagian yang sama: **aturan pembuatan**, **pembuat pengecoh**, dan **solver** yang membuktikan hanya satu opsi benar. Tingkat kesulitan diatur lewat parameter, bukan soal yang berbeda. Semua keacakan datang dari `Rng` (lihat `02-arsitektur.md`).

## Katalog tipe soal

| Kode | Tipe | Sumber | Parameter kesulitan | Pengecoh dibuat dengan | Rilis |
|---|---|---|---|---|---|
| NUM-SEQ | Deret angka | Generator | Jenis pola (aritmetika, geometri, selang-seling, bertingkat), besar angka, panjang deret | Pola yang hampir benar, off-by-one | v1 |
| NUM-ARI | Hitungan cepat, persen, perbandingan | Generator | Jumlah operasi, desimal, angka besar | Salah urutan operasi, salah pembulatan | v1 |
| NUM-WORD | Soal cerita dan tabel | Template dan generator | Jumlah langkah, data pengalih | Memakai data yang salah | v1 |
| LOG-SYL | Silogisme dan logika | Template dan generator | Jumlah premis, negasi | Kesimpulan yang tidak pasti | v1 |
| FIG-MIR | Mirror dan water image | Generator SVG | Kerumitan bentuk | Rotasi, cermin sumbu lain | v1 |
| FIG-SEQ | Deret gambar | Generator SVG | Jumlah atribut yang berubah | Melanggar satu aturan | v1 |
| FIG-MTX | Matriks 3x3 | Generator SVG | Jumlah aturan (1-3), jenis aturan | Melanggar tepat satu aturan | v1 |
| FIG-ODD | Odd one out | Generator SVG | Kemiripan atribut | Perbedaan yang lebih halus | v1 |
| VRB-SYN | Sinonim dan antonim | Bank pre-generate | Frekuensi kata | Kata terkait tapi bukan padanan | v1 |
| VRB-ANA | Analogi kata | Bank pre-generate | Jenis relasi | Relasi terbalik | v1 |
| VRB-RC | Bacaan: Benar, Salah, Tidak dapat ditentukan | Bank pre-generate | Panjang teks | Pernyataan tersirat | v1.1 |
| KRP | Kraepelin/Pauli | Generator | Durasi, jumlah kolom | Tidak ada (isian) | v1 sederhana, v1.1 penuh |
| IT-PSE | Trace pseudocode | Generator | Loop, kondisi, nesting | Off-by-one, salah kondisi | v1.1 |
| IT-FLW | Logika flowchart | Generator | Jumlah cabang | Jalur cabang lain | v1.1 |
| IT-XLS | Rumus Excel | Generator tabel dan rumus | Fungsi (SUM, IF, VLOOKUP, COUNTIF) | Rentang sel salah | v1.1 |
| PER-PAPI | Kepribadian forced-choice | Pool pernyataan | Tidak ada | Tidak ada | v1.1 |
| PER-DISC | Kepribadian most/least | Pool pernyataan | Tidak ada | Tidak ada | v1.1 |
| KB-* | Pengetahuan role | Bank pre-generate | Level (dasar, menengah, lanjut) | Tidak ada (jawaban model dan poin kunci) | v1.1 |

Kategori dan bobot: `verbal` (VRB-*), `numerik` (NUM-*), `logika` (LOG-*), `figural` (FIG-*), `kraepelin` (KRP), `kepribadian` (PER-*), `it` (IT-*), `pengetahuan` (KB-*).

## Format soal (keluaran engine)

```json
{
  "type": "FIG-MTX",
  "category": "figural",
  "seed": 20481,
  "difficulty": "medium",
  "stem": {
    "text": "Pilih gambar yang melengkapi pola.",
    "figure": { "kind": "matrix3x3", "cells": [ [ ... ] ] }
  },
  "options": [
    { "id": "A", "content": { "figure": { "kind": "single", "objects": [ ... ] } } },
    { "id": "B", "content": { "figure": { "kind": "single", "objects": [ ... ] } } }
  ],
  "correctIndex": 1,
  "explanation": "Baris 1: bentuk tetap lingkaran dan jumlah naik per kolom. Baris 3: kotak dengan jumlah 1, 2, jadi sel kosong berisi 3 kotak.",
  "estimatedSeconds": 45,
  "tags": ["rule:constant-row", "rule:progress-col"]
}
```

Aturan format:
- `options` berisi 2 sampai 8 opsi. Posisi kunci diacak oleh `Rng`.
- `stem.text` atau `stem.figure` wajib ada salah satu. Opsi memakai `text` atau `figure`.
- `explanation` wajib tidak kosong dan menyebut aturan yang dipakai.
- Soal tidak disimpan. Penyimpanan hanya `(type, seed, difficulty)`.

### Spesifikasi gambar (`FigureSpec`)

Satu objek: `{shape, count, fill, rotation, size}`.

| Atribut | Nilai |
|---|---|
| `shape` | `circle`, `triangle`, `square`, `diamond`, `pentagon`, `cross` |
| `count` | 1 sampai 4 |
| `fill` | `empty`, `solid`, `hatch` |
| `rotation` | 0, 90, 180, 270 |
| `size` | `s`, `m`, `l` |

Aturan keterbacaan: opsi tidak boleh dibedakan hanya oleh warna; `fill` dibedakan lewat pola (kosong, penuh, arsir). Gambar digambar dengan `CustomPainter` dari data ini, tanpa aset gambar, dan harus tetap terbaca di 360 dp.

## FIG-MTX (matriks 3x3), spesifikasi lengkap

Bagian paling berisiko, dikerjakan pertama (tugas T04).

1. Sel berisi objek dengan atribut `shape`, `count`, `fill`, `rotation`, `size`.
2. Pilih 1 sampai 3 aturan sesuai kesulitan: konstan per baris, naik per kolom, rotasi bertahap, tiga nilai berbeda per baris (distribusi), penjumlahan atau pengurangan bentuk antar sel.
3. Bangun 9 sel; sel ke-9 adalah jawaban.
4. Pengecoh: 5 sampai 7 kandidat yang masing-masing melanggar tepat satu aturan, ditambah satu kandidat yang sama dengan sel lain di matriks.
5. Solver: periksa tiap opsi terhadap semua aturan. Soal diterima hanya jika tepat satu opsi lolos dan tidak ada opsi kembar. Jika gagal, ulangi dengan seed turunan (`Rng.derive(seed, attempt)`), maksimal 20 kali, lalu lempar `GenerationFailure`.
6. Pembahasan otomatis menyebut aturan per baris dan kolom.
7. Kesulitan: easy = 1 aturan; medium = 2 aturan; hard = 3 aturan atau aturan distribusi.

Invarian khusus: tiap aturan yang dipilih berlaku pada semua baris atau kolom yang relevan; dua aturan yang dipilih tidak boleh bertabrakan pada atribut yang sama.

## Spesifikasi ringkas tipe lain (v1)

| Tipe | Aturan pembuatan | Pengecoh | Solver |
|---|---|---|---|
| FIG-SEQ | Deret 4 sampai 5 gambar; 1 sampai 3 atribut berubah dengan aturan tetap (rotasi tiap langkah, jumlah naik, isian bergantian) | Melanggar tepat satu aturan pada gambar berikutnya | Terapkan semua aturan ke langkah berikutnya, bandingkan dengan tiap opsi |
| FIG-MIR | Bentuk tersusun dari 4 sampai 9 sel tidak simetris; soal minta bayangan cermin (sumbu vertikal) atau water image (sumbu horizontal) | Rotasi, cermin sumbu lain, bentuk dengan satu sel bergeser | Hitung transformasi tepat, banding tiap opsi |
| FIG-ODD | 5 gambar; 4 berbagi aturan atribut, 1 melanggar | Pelanggar yang halus (satu atribut berbeda) | Tepat satu gambar melanggar aturan yang dipilih |
| NUM-SEQ | Jenis pola: aritmetika, geometri, selang-seling dua deret, bertingkat (selisih membentuk deret). Panjang 5 sampai 8 | Hasil pola yang hampir benar, off-by-one pada selisih | Hitung suku berikutnya dari aturan; periksa tidak ada opsi lain yang konsisten dengan seluruh deret |
| NUM-ARI | 1 sampai 4 operasi dengan urutan operasi, persen, atau perbandingan; angka bulat atau desimal terkontrol | Salah urutan operasi, salah pembulatan | Evaluasi ekspresi dengan aritmetika pecahan eksak (hindari galat desimal) |
| NUM-WORD | Templat cerita dengan slot angka; tabel kecil; data pengalih | Memakai data yang salah | Hitung dari model data, bukan dari teks |
| LOG-SYL | 2 sampai 3 premis dengan kuantor (semua, sebagian, tidak ada); pertanyaan: kesimpulan mana yang pasti benar | Kesimpulan yang tidak pasti | Pemeriksa model himpunan: enumerasi model kecil untuk membuktikan kesimpulan wajib benar di semua model |
| KRP | Kolom angka 0 sampai 9; tugas menjumlah pasangan berurutan dari atas ke bawah dan menulis angka terakhirnya; durasi per kolom dari subtes profil (A104) | Tidak ada (isian) | Hitung jawaban per pasangan; skor = kecepatan (isian per kolom), ketelitian (persen benar), konsistensi (selisih dan simpangan antar kolom) |
| IT-PSE | Pseudocode bahasa Indonesia dari templat (cabang, ULANGI, SELAMA, bersarang, digit); pertanyaan: nilai tampil, nilai akhir variabel, atau berapa kali baris dijalankan (A102) | Program yang diubah satu bagian: batas loop plus-minus satu, `<` jadi `<=`, operator tertukar | Interpreter mini buatan sendiri dengan batas langkah; diuji 22 kasus tulisan tangan |
| IT-FLW | Flowchart sebagai tabel kotak (No, Kotak, Lanjut ke); 1 keputusan (mudah), 2 (sedang), perulangan (sulit) | Jalur cabang lain (satu keputusan dibalik), batas kondisi bergeser | Jalankan dari kotak 1; dibandingkan dengan solver kedua independen |
| IT-XLS | Tabel lembar kerja A sampai C dan satu rumus di E1: SUM, COUNTIF, IF, VLOOKUP, gabungannya | Rentang sel salah (ujung bergeser, kolom tertukar), kriteria `>=` jadi `>`, kolom VLOOKUP meleset | Evaluasi rumus dengan pecahan eksak; dibandingkan dengan solver kedua independen |

## Bank verbal (pre-generate)

Tipe VRB-SYN, VRB-ANA (v1) dan VRB-RC (v1.1) dibuat sekali di luar app, lalu dibundel.

Alur (`tool/pregenerate/`):
1. `gen_verbal.py`: meminta Claude membuat soal dalam JSON sesuai skema di bawah. Dijalankan lewat Claude Code (`claude -p`) atau chat dengan langganan; tidak memakai API berbayar (ADR-12).
2. `verify_verbal.py`: pass kedua dengan prompt berbeda menjawab soal **tanpa melihat kunci**. Soal dibuang jika jawabannya tidak sama dengan kunci.
3. Sampel 10% diperiksa manual; yang meragukan ditandai `needsReview: true` dan dibuang dari bundel sampai diperiksa.
4. `bundle.py`: menulis `assets/verbal_bank.json` dengan nomor versi dan hitungan per tipe. Target v1: 300 soal terverifikasi.

Skema `assets/verbal_bank.json`:
```json
{
  "versi": 1,
  "dibuat": "2026-10-21",
  "soal": [
    {
      "id": "VRB-SYN-0001",
      "type": "VRB-SYN",
      "difficulty": "medium",
      "stem": "Padanan kata \"efisien\" adalah ...",
      "options": ["hemat tenaga dan waktu", "boros", "lambat", "rumit"],
      "correctIndex": 0,
      "explanation": "Efisien berarti mencapai hasil dengan sumber daya sesedikit mungkin.",
      "needsReview": false,
      "passes": { "generate": "pass1", "verify": "pass2-agree" }
    }
  ]
}
```
Aturan: tepat satu opsi benar; tidak ada opsi kembar; kata soal tidak muncul di opsi sebagai jawaban; tidak menyalin soal dari penerbit tes.

## Bank pengetahuan role (F17)

Dibuat dengan alur yang sama (generate, verifikasi pass kedua, sampel manual), dibundel sebagai `assets/knowledge_bank.json`. Daftar topik awal adalah usulan dan disusun ulang dari lowongan yang dilamar.

| Role | Dasar | Menengah | Lanjut |
|---|---|---|---|
| QA Engineer | test case vs test scenario, severity vs priority | boundary value, siklus bug, pengujian API | strategi tes, flaky test, CI, mencari bug dari skenario |
| Mobile / App Developer | siklus hidup layar, state, layout | arsitektur MVVM, async, penyimpanan lokal | performa, kebocoran memori, desain offline-first |
| IT Business Analyst | requirement, user story, use case | BPMN, prioritisasi, UAT | analisis dampak, trade-off, kasus dari awal sampai akhir |

Skema:
```json
{
  "versi": 1,
  "dibuat": "2026-10-21",
  "butir": [
    {
      "id": "KB-QA-D-001",
      "role": "qa",
      "level": "dasar",
      "topik": "siklus-bug",
      "pertanyaan": "Apa beda severity dan priority pada sebuah bug?",
      "jawabanModel": "Severity adalah seberapa parah dampak bug pada sistem. Priority adalah seberapa cepat bug harus diperbaiki menurut kebutuhan bisnis.",
      "poinKunci": [
        "Severity dinilai dari dampak teknis",
        "Priority ditentukan oleh urgensi bisnis",
        "Contoh: salah ketik di logo, severity rendah tapi priority tinggi"
      ],
      "sumber": null,
      "needsVerification": true
    }
  ]
}
```
Aturan: `role` bernilai `qa`, `mobile`, `ba`, atau `umum`; `level` bernilai `dasar`, `menengah`, `lanjut`; butir tanpa `sumber` ditandai `needsVerification: true` dan tampil dengan tag "perlu verifikasi" di app. Level Lanjut dinilai dengan `poinKunci`, bukan satu jawaban benar. Mode Umum memilih butir lintas role (`role` apa pun, kecuali yang sudah dikuasai).

## Pool kepribadian (F12)

`assets/personality_pool.json`:
```json
{
  "versi": 1,
  "sifat": [
    {
      "id": "keteraturan",
      "nama": "Keteraturan dan ketelitian",
      "arti": "Kecenderungan bekerja terstruktur dan memeriksa detail.",
      "relevansiRole": { "qa": "tinggi", "mobile": "sedang", "ba": "sedang" },
      "pernyataan": [
        { "id": "PER-KTR-001", "teks": "Saya teliti memeriksa pekerjaan sampai detail kecil sebelum diserahkan." }
      ]
    }
  ]
}
```
Aturan: tiap sifat punya 10 sampai 20 pernyataan; setiap sesi memasangkan pernyataan dari dua sifat berbeda secara acak; tidak ada skor benar atau salah; interpretasi edukatif, bukan diagnosis. Tidak menyalin item Papi Kostick atau DISC asli.

## Blueprint tes per profil (template awal)

Angka berikut adalah asumsi awal. Pertanyaan terbuka: daftar tes nyata yang sudah dijalani (perusahaan, subtes, jumlah soal, durasi) untuk menggantinya.

| Profil | Subtes | Soal | Durasi | Bobot |
|---|---|---|---|---|
| CCAT-style | Campuran verbal, numerik, logika, figural | 50 | 15 menit | 30/30/20/20 |
| Psikotes Bank-style | Verbal, numerik, figural, Kraepelin, kepribadian | 120 dan koran | 90 sampai 120 menit | 25/25/20/15/15 |
| QA | Fokus ketelitian, logika deduktif, Kraepelin | Sesuai format | Sesuai format | Ketelitian dan logika naik |
| Mobile Dev | Fokus figural induktif, pseudocode, numerik | Sesuai format | Sesuai format | Induktif dan IT naik |
| IT BA | Fokus verbal, bacaan, tabel, silogisme | Sesuai format | Sesuai format | Verbal dan data naik |
| Umum | Semua kategori kognitif aktif | Sesuai format | Sesuai format | Rata |

Pemilihan role menaikkan bobot kategori tertentu sebesar +50% relatif dari bobot dasar lalu dinormalkan ke 100%. Profil Umum memakai bobot rata tanpa penyesuaian.

## Aturan hak cipta

- Tidak menyalin item SHL, CCAT, Papi Kostick asli, atau soal perusahaan.
- Soal Capture tetap lokal dan tidak masuk repo; `.gitignore` menutup folder datanya.
- README menyebut bahwa app tidak berafiliasi dengan penerbit tes mana pun.
