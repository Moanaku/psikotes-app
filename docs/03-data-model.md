# 03. Data model

Database lokal memakai Drift (SQLite, juga di web). Semua waktu disimpan sebagai epoch milidetik UTC (`INTEGER`). Soal tidak disimpan utuh; engine membuatnya ulang dari `(type, seed, difficulty, gen_versi)`. Setiap generator punya nomor `version`; mengubah perilaku generator menaikkan nomornya dan versi lama tetap bisa dibuat ulang (generator lama dipertahankan di engine selama masih ada jawaban yang memakainya; kalau tidak mungkin, pembahasan soal lama menampilkan pesan bahwa soalnya tidak bisa dibuat ulang).

## Tabel

### test_profile
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| nama | TEXT | mis. "QA, CCAT perusahaan target" |
| role | TEXT | `qa`, `mobile`, `ba`, `umum`, `lainnya` |
| format_tes | TEXT | `ccat`, `bank`, `kustom` |
| tanggal_tes | INTEGER NULL | opsional |
| aktif | INTEGER | 0 atau 1, tepat satu baris bernilai 1 |
| blueprint_json | TEXT | subtes, jumlah soal, durasi, bobot kategori |
| cv_teks | TEXT NULL | teks CV yang sudah disanitasi |
| dibuat | INTEGER | |

`blueprint_json`:
```json
{
  "subtes": [
    {"kategori": "verbal", "aktif": true, "jumlah": 20, "menit": 8},
    {"kategori": "numerik", "aktif": true, "jumlah": 20, "menit": 8}
  ],
  "bobot": {"verbal": 0.30, "numerik": 0.30, "logika": 0.20, "figural": 0.20}
}
```
Kategori yang valid: `verbal`, `numerik`, `logika`, `figural`, `kraepelin`, `kepribadian`, `it`, `pengetahuan`. Mode Umum memakai bobot rata di semua kategori kognitif aktif.

### session
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| profile_id | INTEGER FK | |
| mode | TEXT | `latihan`, `simulasi`, `diagnostik` |
| rencana_json | TEXT | daftar `(type, seed, difficulty)` berurutan, subtes, batas waktu |
| mulai | INTEGER | |
| selesai | INTEGER NULL | NULL berarti belum selesai (bisa dilanjutkan) |
| deadline | INTEGER NULL | batas waktu mutlak subtes yang berjalan, untuk Simulasi |
| posisi | INTEGER | indeks soal terakhir |
| skor | REAL NULL | persen, 0 sampai 100 |

Indeks: `(profile_id, mulai)`, `(selesai)`.

### answer
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| session_id | INTEGER FK | |
| posisi | INTEGER | indeks soal di rencana sesi; satu jawaban per `(session_id, posisi)`, menjawab ulang menggantikan |
| tipe | TEXT | kode tipe soal, mis. `FIG-MTX` |
| kategori | TEXT | |
| seed | INTEGER | |
| kesulitan | TEXT | `easy`, `medium`, `hard` |
| gen_versi | INTEGER | versi generator saat soal dibuat; dipakai agar pembahasan membuat ulang soal yang sama persis |
| sumber | TEXT | `engine`, `capture`, `bank`, `pengetahuan` |
| ref_id | INTEGER NULL | wajib bila bukan engine: id captured_question, atau nomor butir bank (`VRB-SYN-0042` = tipe `VRB-SYN`, ref_id 42) |
| opsi_dipilih | INTEGER NULL | NULL berarti dilewati |
| benar | INTEGER | 0 atau 1 |
| durasi_ms | INTEGER | |
| label | TEXT | `benar_cepat`, `benar_lambat`, `salah_cepat`, `salah_lambat` |
| dijawab | INTEGER NULL | ms UTC saat jawaban terakhir dicatat; NULL pada jawaban sebelum skema v2 dan soal dilewati (skema v2, A105) |

Indeks: `(session_id, posisi)` unik, `(tipe, id)` untuk statistik, `(kategori, id)`.

### mistake_card
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| tipe | TEXT | |
| kategori | TEXT | |
| seed | INTEGER NULL | seed asal; ulangan memakai seed baru. NULL untuk soal non-engine |
| sumber | TEXT | sama seperti answer.sumber |
| ref_id | INTEGER NULL | untuk Capture dan butir bank atau pengetahuan (wajib bila bukan engine); kartu dikenali dari `(sumber, tipe, ref_id)`, soal engine dari `(tipe, seed)` |
| jatuh_tempo | INTEGER | |
| interval_hari | INTEGER | |
| streak_benar | INTEGER | 0 sampai 3 |
| status | TEXT | `aktif`, `dikuasai` |
| dibuat | INTEGER | |

Indeks: `(status, jatuh_tempo)`.

### captured_question
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| teks | TEXT | |
| opsi_json | TEXT | 2 sampai 6 opsi |
| kunci | INTEGER | indeks opsi |
| pembahasan | TEXT NULL | |
| kategori | TEXT | boleh tipe baru buatan pengguna |
| foto_path | TEXT NULL | nama berkas foto di penyimpanan lokal app (bukan jalur lengkap); lokal saja (A86) |
| company_log_id | INTEGER NULL FK | |
| dibuat | INTEGER | |

### company_test_log
| Kolom | Tipe | Catatan |
|---|---|---|
| id | INTEGER PK | |
| perusahaan | TEXT | |
| tanggal | INTEGER | |
| subtes_json | TEXT | daftar kategori yang keluar |
| tipe_baru_json | TEXT | tag tipe baru, mis. "lipat kertas" |
| catatan | TEXT | |

### knowledge_progress (v1.1)
| Kolom | Tipe | Catatan |
|---|---|---|
| butir_id | TEXT PK | id dari `knowledge_bank.json` |
| level | TEXT | `dasar`, `menengah`, `lanjut` |
| terakhir | INTEGER | |
| dikuasai | INTEGER | 0 atau 1 |

### cv_profile dan interview_session (v1.3)
| Tabel | Kolom |
|---|---|
| cv_profile | id, ringkasan_json (klaim, skill, celah, kecocokan; tanpa data pribadi), dibuat |
| interview_session | id, profile_id, persona, bahasa, mode, rencana_json, transkrip_json, laporan_json, mulai, selesai |

### app_setting
Pasangan kunci dan nilai: `tema` (`terang`, `gelap`, `sistem`), `penyedia_ai`, `batas_wawancara_harian`, `onboarding_selesai`. Key API tidak disimpan di tabel ini (lihat arsitektur, keamanan).

## Jadwal SM-2 sederhana (F07)

Tangga interval: 1, 3, 7 hari. Keluar dari buku setelah 3 jawaban benar berturut-turut.

| Peristiwa | Aksi |
|---|---|
| Soal salah (di sesi mana pun) | Kartu dibuat atau diperbarui: `streak_benar = 0`, `interval_hari = 1`, `jatuh_tempo = hari ini + 1`, `status = aktif` |
| Ulangan benar | `streak_benar += 1`. Streak 1: interval 3. Streak 2: interval 7. Streak 3: `status = dikuasai`, tidak muncul lagi |
| Ulangan salah | `streak_benar = 0`, `interval_hari = 1`, `jatuh_tempo = hari ini + 1` |
| Kartu dikuasai | Satu pemeriksaan ulang pada 14 hari setelah dikuasai; jika salah, kembali `aktif` dengan interval 1 |

Asumsi A1: pemeriksaan 14 hari ini tafsiran dari "jadwal 1, 3, 7, 14 hari" di blueprint. Pemilik proyek perlu mengonfirmasi atau menghapusnya.

Penandaan pemeriksaan 14 hari tanpa kolom baru (A81): kartu `dikuasai` dengan `interval_hari = 14` menunggu pemeriksaan dan ikut ditarik saat `jatuh_tempo` tiba; setelah lulus `interval_hari = 0` dan kartu tidak muncul lagi. "Jatuh tempo hari ini" berarti sebelum tengah malam setempat (A80).

Ulangan soal engine memakai tipe yang sama dengan seed baru. Ulangan soal Capture dan butir pengetahuan memakai butir yang sama. Soal ulangan membawa `cardId` di `rencana_json` dan menjadwal ulang kartunya saat sesi selesai (A79).

## Rencana latihan harian (F03)

Masukan: profil aktif, riwayat jawaban 30 hari, kartu jatuh tempo, tanggal tes, target durasi (default 15 menit).

1. Jumlah soal `N = round(menit * 60 / median_detik_per_soal)`, dengan median dari 30 hari terakhir atau `estimatedSeconds` engine jika belum ada data.
2. Skor kelemahan tiap tipe `w = 1 - (benar + 1) / (jumlah + 2)` atas 30 jawaban terakhir (penghalus agar tipe baru tidak langsung terlemah). Tipe tanpa data diberi `w = 0.5`.
3. Komposisi: 50% dari tipe dengan `w` tertinggi, 30% dari kartu buku kesalahan jatuh tempo (jika kurang, sisanya diisi dari kelemahan), 20% acak berbobot sesuai `blueprint_json.bobot`.
4. Jika `tanggal_tes - hari ini < 7 hari`: tambahkan satu blok Simulasi satu subtes di akhir rencana.
5. Tidak ada `(type, seed)` yang sudah muncul dalam 30 hari, kecuali kartu buku kesalahan.

## Label cepat dan lambat (F06)

Ambang waktu per tipe adalah median `durasi_ms` jawaban benar tipe itu (30 hari). Jika belum ada data, pakai `estimatedSeconds` dari engine. Waktu di bawah atau sama dengan ambang berarti cepat.

## Format backup (F11)

Satu berkas JSON, dibuat dan dibaca oleh `BackupService`:

```json
{
  "format": "simulator-psikotes-backup",
  "versi": 1,
  "diekspor": 1760000000000,
  "tabel": {
    "test_profile": [],
    "session": [],
    "answer": [],
    "mistake_card": [],
    "captured_question": [],
    "company_test_log": [],
    "knowledge_progress": [],
    "app_setting": []
  }
}
```

Aturan: key API dan teks CV mentah tidak diekspor. Foto Capture tidak ikut (hanya `foto_path`), dan layar ekspor menyebut itu. Impor memvalidasi `format` dan `versi`, berjalan dalam satu transaksi, dan menggabungkan baris yang sama dan memetakan ulang nomor (id) yang bentrok: baris dikenali dari waktu pembuatan dan isian pembeda, bukan dari id; nomor yang dipakai baris lain di perangkat ini diganti nomor baru beserta semua rujukannya (A90). Versi lebih baru dari yang dikenal ditolak dengan pesan yang menyebut versi app yang dibutuhkan. Perincian penggabungan, validasi, dan hal yang tidak ikut: A89 dan A90.

## Migrasi

Drift `schemaVersion` dimulai dari 1. Setiap perubahan skema menambah langkah migrasi dan satu test migrasi (`drift_dev schema`). Tabel v1.1 (`knowledge_progress`) dan v1.3 (`cv_profile`, `interview_session`) ditambahkan lewat migrasi saat fiturnya dikerjakan, bukan dibuat lebih awal.
