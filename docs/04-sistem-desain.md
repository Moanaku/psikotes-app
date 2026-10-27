# 04. Sistem desain

Berkas ini mengikuti dokumen panduan "Bikin Aplikasi Mobile yang Tidak Terlihat AI Slop" dan blok "Aturan UI untuk Claude" di project. Nilai pasti ada di `design/tokens.json` dan diterjemahkan ke Dart di `lib/core/theme/app_tokens.dart`. Kalau ada selisih, `app_tokens.dart` yang berlaku, lalu perbarui berkas ini.

Desain 20 layar: artefak Claude Design "Desain UI Simulator Psikotes IT" (https://claude.ai/artifact/6PGmJzUf73k7eC67AhSLkG). Wawancara (S15 sampai S17) hanya UI.

## Arah visual

Tenang, padat, mudah dibaca: seperti buku latihan soal yang ditandai stabilo. Dipakai pelamar kerja di sela waktu belajar, sering di HP dan kadang di bawah cahaya terang. Hierarki datang dari ukuran dan garis, bukan dari kartu dan bayangan.

Struktur yang diambil dari aplikasi lain, bukan warnanya:
- Anki: daftar padat dengan jadwal ulang, untuk Buku kesalahan.
- Stimuler: dialog bergiliran, untuk wawancara.
- Buku soal cetak: nomor soal, opsi berhuruf, pembahasan di bawah soal.

## Token

### Warna (tema terang)

| Token | Nilai | Peran |
|---|---|---|
| `surface` | `#F1F2ED` | Latar layar |
| `surfaceContainer` | `#FAFAF7` | Panel, input, opsi soal |
| `surfaceContainerHigh` | `#E4E7DF` | Tombol sekunder, trek progres, kontrol segmen |
| `ink` | `#1B1E1C` | Teks utama, tombol utama, tanda "selesai" |
| `inkMuted` | `#565C57` | Teks sekunder, label nav tidak aktif |
| `outlineVariant` | `#CDD2C8` | Garis pemisah, batas panel |
| `outline` | `#7F867F` | Batas komponen interaktif (input, opsi, chip) |
| `accent` (stabilo) | `#F2CF3D` | Satu aksen: posisi sekarang, pilihan terpilih, kelemahan terbesar |
| `ok` / `okContainer` | `#2B6A4B` / `#E0EDE4` | Hanya untuk benar, kuat |
| `bad` / `badContainer` | `#A23B2F` / `#F5E2DE` | Hanya untuk salah |

Aturan pemakaian:
- Aksen hanya satu. `ok` dan `bad` adalah warna semantik, bukan aksen, dan selalu ditemani ikon dan teks.
- Tidak ada putih atau hitam murni. Teks di atas `accent` selalu `ink`.
- Tidak ada `Colors.*` atau hex mentah di widget. Semua lewat `AppTokens` atau `ColorScheme`.
- Opacity tidak dipakai untuk teks sekunder; pakai `inkMuted`.
- Dynamic color mati. `ColorScheme.fromSeed` tidak dipakai; skema ditulis eksplisit dari tabel di atas.

### Kontras terukur (tema terang)

| Pasangan | Rasio | Syarat | Lolos |
|---|---|---|---|
| `ink` di atas `surface` | 14,9 : 1 | 4,5 | Ya |
| `ink` di atas `surfaceContainer` | 16,1 : 1 | 4,5 | Ya |
| `ink` di atas `surfaceContainerHigh` | 13,4 : 1 | 4,5 | Ya |
| `inkMuted` di atas `surface` | 6,1 : 1 | 4,5 | Ya |
| `inkMuted` di atas `surfaceContainerHigh` | 5,5 : 1 | 4,5 | Ya |
| `ink` di atas `accent` | 11,0 : 1 | 4,5 | Ya |
| `surfaceContainer` di atas `ink` (tombol utama) | 16,1 : 1 | 4,5 | Ya |
| `ok` di atas `okContainer` | 5,3 : 1 | 4,5 | Ya |
| `bad` di atas `badContainer` | 5,3 : 1 | 4,5 | Ya |
| Placeholder `#6B716C` di atas `surfaceContainer` | 4,8 : 1 | 4,5 | Ya |
| `outline` di atas `surface` | 3,3 : 1 | 3,0 (batas komponen) | Ya |
| `outline` di atas `surfaceContainer` | 3,6 : 1 | 3,0 | Ya |

`outlineVariant` (garis pemisah) sengaja di bawah 3 : 1 karena hanya memisahkan baris, bukan batas komponen interaktif.

### Warna (tema gelap, usulan, belum diperiksa per layar)

| Token | Nilai |
|---|---|
| `surface` | `#151816` |
| `surfaceContainer` | `#1D211E` |
| `surfaceContainerHigh` | `#2A2F2B` |
| `ink` | `#ECEEE8` |
| `inkMuted` | `#A9AFA8` |
| `outlineVariant` | `#3A403B` |
| `outline` | `#7F867F` |
| `accent` | `#F2CF3D` (sama; teks di atasnya tetap `#1B1E1C`) |
| `ok` / `okContainer` | `#7FD1A0` / `#1F3A2B` |
| `bad` / `badContainer` | `#EE9A8F` / `#3B1F1B` |

Kontras terukur: `ink` di atas `surface` 15,3 : 1; `inkMuted` di atas `surface` 8,0 : 1; `inkMuted` di atas `surfaceContainerHigh` 6,1 : 1; `ok` di atas `okContainer` 6,8 : 1; `bad` di atas `badContainer` 6,9 : 1; `outline` di atas `surface` 4,8 : 1. Tombol utama di tema gelap: latar `ink` `#ECEEE8`, teks `#151816`, 15,3 : 1. Tema gelap dikerjakan di tugas T21; sebelum itu hanya tema terang yang dirilis.

### Tipografi

Satu keluarga: Instrument Sans (lisensi OFL), dibundel di `assets/fonts/` agar tidak ada unduhan saat runtime. Aktifkan `FontFeature.tabularFigures()` untuk semua angka (timer, skor, nomor soal, statistik).

| Peran | Ukuran / tinggi baris | Bobot | Dipakai untuk |
|---|---|---|---|
| `caption` | 12 / 16 | 600 | Label tab bawah, angka di bulatan nomor soal |
| `label` | 14 / 20 | 500 sampai 600 | Teks sekunder, label isian, tag, chip |
| `body` | 16 / 24 | 400 sampai 600 | Isi, baris daftar, tombol |
| `title` | 20 / 28 | 600 sampai 700 | Judul layar, judul seksi |
| `headline` | 28 / 36 | 700 | Judul onboarding, soal deret angka, angka statistik |
| `display` | 36 / 44 | 700 | Skor hasil sesi |

Enam ukuran dipakai (batas tujuh). Dua ukuran tidak pernah beda 1 sp.

### Jarak

Skala tunggal: 4, 8, 12, 16, 24, 32, 48. Tidak ada nilai lain. Jarak antar grup lebih besar dari jarak di dalam grup: label ke nilai 4, antar baris 8 sampai 16, antar seksi 24.

Margin layar horizontal 16. Tinggi minimum baris daftar 56. Tinggi tombol, input, dan target sentuh 48.

### Bentuk

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `radiusSm` | 4 | Tag, bilah progres, sudut kecil gelembung chat |
| `radiusMd` | 8 | Tombol, input, opsi soal, kontrol segmen, panel catatan |
| `radiusLg` | 12 | Panel "Latihan hari ini", gelembung chat |
| bulat penuh | 999 | Chip, bulatan nomor, tombol ikon bulat. Dihitung bentuk, bukan nilai radius |

Elevasi: 0 di semua tempat. Pemisahan lewat garis `outlineVariant` dan perbedaan lapisan permukaan. Satu tingkat tambahan (1) dicadangkan untuk bottom sheet jika dibutuhkan.

### Gerak

Satu kurva: `Curves.easeOut`. Satu durasi: 150 ms untuk perubahan state (pilih opsi, ganti segmen, ganti tab). Tidak ada animasi masuk di tiap bagian. Gerak hanya sebagai respons atas aksi pengguna. Hormati `MediaQuery.disableAnimations` dan reduced motion di web.

### Ikon

Satu keluarga, satu gaya: garis (outlined), tebal 2, sudut membulat, ukuran dasar 24 (20 di dalam teks, 16 di dalam tag). Dipasang sebagai SVG di `assets/icons/` atau lewat set ikon outlined yang konsisten. Tidak ada emoji dan tidak ada ikon terisi. Ikon tanpa teks wajib punya `Semantics(label: ...)`.

Ikon yang dipakai: home, grid, chat, chart, sliders, close, back, next, down, clock, check, camera, book, note, plus, minus, download, upload, lock, eye, target, layers, image, key, bulb, mic, send, alert (peringatan, dipakai di pesan galat isian).

## Komponen inti

Dibangun sebelum layar (tugas T02). Layar hanya merakit komponen ini. Membuat komponen baru perlu persetujuan dan satu baris di sini.

| Komponen | Spesifikasi |
|---|---|
| `AppButton` | Tiga varian. Utama: latar `ink`, teks `surfaceContainer`. Sekunder: latar `surfaceContainerHigh`, teks `ink`. Garis: latar `surfaceContainer`, batas `outline` 1. Tinggi 48, radius 8, teks `body` 600. Satu aksi utama per layar |
| `AppIconButton` | 48 x 48, ikon 24, radius 8, wajib label semantik |
| `AppTopBar` | Tinggi minimal 56, bertambah bila judul panjang atau font besar. Kembali (48) di kiri, judul `title`, aksi di kanan. Dipasang di badan layar, bukan `Scaffold.appBar` (yang memaksa tinggi tetap) |
| `AppBottomNav` | Empat tab: Beranda, Psikotes, Wawancara, Statistik. Tab aktif: ikon di dalam pil 56 x 32 berlatar `accent`, label `ink` tebal. Tab tidak aktif: `inkMuted` |
| `ListRow` | Min 56, garis bawah `outlineVariant`, ikon opsional di kiri, `body` 600 untuk judul, `label` `inkMuted` untuk keterangan, chevron di kanan bila bisa dibuka. Bukan kartu |
| `ChoiceRow` | Baris radio untuk pilihan tunggal (role di S01). Terpilih: latar `accent` sampai tepi layar, titik radio `ink`, keterangan `ink` |
| `OptionTile` | Opsi soal. Batas `outline` 1, latar `surfaceContainer`, radius 8. Terpilih: latar `accent`, batas `ink` 2, huruf opsi berlatar `ink`. Isi berupa teks atau widget (gambar figural, dengan `semanticLabel`). Batas digambar sebagai lapisan depan, jadi tata letak tidak bergeser saat dipilih |
| `FigureView` | Menggambar `FigureSpec` (single, sequence, matrix3x3, grid, table) dari data dengan `CustomPainter`, tanpa aset. Bentuk `ink`, kerangka `outline` 1, garis dalam `outlineVariant`, sel yang dijawab berlatar `accent` dengan "?". Isian dibedakan lewat pola (kosong, penuh, arsir 45°), bukan warna. Lebar mengikuti ruang, label semantik dari `describeFigure`. Tabel memakai baris dan garis pemisah, bukan kartu |
| `AppChip` | Tinggi 44, bulat penuh, batas `outline`. Terpilih: latar `accent`, batas `ink` 2, teks tebal. Area sentuh 48 |
| `SegmentedControl` | Latar `surfaceContainerHigh`, isi 4, tombol 40, radius 8 (tombol terpilih radius 4). Terpilih: latar `accent`. Area sentuh tiap segmen 48 |
| `NumberBubble` | 32, bulat. Terjawab: latar `ink`, teks terang. Sekarang: latar `accent`, batas `ink` 2. Belum: batas `outline`, teks `inkMuted`. Bila bisa diketuk, area sentuh 48 |
| `ScoreBar` | Tinggi 8, trek `surfaceContainerHigh`, isi `ink`. Kelemahan terbesar: isi `accent` dengan batas `ink`. Nilai selalu ditulis sebagai teks di sampingnya |
| `StatusTag` | Tinggi 24, radius 4, `label`. Netral: batas `outline`. Perlu perhatian: latar `accent`. Kuat: `okContainer` dengan ikon centang |
| `NoteBox` | Info tambahan: ikon kiri, `label`, latar `surfaceContainer`, batas `outline` 1, radius 8. Tanpa garis tebal di sisi |
| `AppTextField` | Label di atas (`label` 600), tinggi 48, batas `outline`, latar `surfaceContainer`, teks 16. Fokus: kontur `ink` 2 |
| `StatRow` | Tiga kolom dipisah garis vertikal `outlineVariant`; angka `headline`, keterangan `label` `inkMuted` |
| `QuadrantGrid` | 2 x 2 untuk cepat atau lambat dan benar atau salah. Benar di `okContainer`, salah di `badContainer`, tiap sel punya ikon dan teks. Angka di atas, judul sel di bawahnya, agar angka sejajar walau judul turun baris |
| `ChatBubble` | Pewawancara: `surfaceContainer`, batas `outlineVariant`, radius 12 dengan sudut kiri bawah 4. Pengguna: latar `ink`, teks terang, sudut kanan bawah 4 |
| `CodeBlock` | Teks kode dengan `AppType.code` (IBM Plex Mono 14 / 20, Regular dan SemiBold, OFL; lisensi di `assets/fonts/IBMPlexMono-OFL.txt`). Indentasi awal dipertahankan, baris panjang dipatahkan di spasi dengan indentasi gantung 2 karakter. Tanpa latar atau bingkai. Dipakai untuk pseudocode IT-PSE; tabel IT-FLW dan IT-XLS memakai gaya yang sama lewat `FigureView(mono: true)` |
| `EmptyView` | Judul `title`, satu kalimat penjelasan, satu tombol aksi (boleh tanpa tombol bila tidak ada yang bisa dilakukan, mis. "Tidak ada kartu jatuh tempo hari ini") |
| `SkeletonList` | Baris abu `surfaceContainerHigh` berbentuk baris daftar asli. Bukan spinner di tengah layar |
| `ErrorView` | Apa yang gagal, apa yang bisa dilakukan, tombol "Coba lagi" di tempatnya. Tidak pernah menampilkan teks exception |
| `OfflineView` | Dibedakan dari galat biasa. Judul "Tidak ada internet", apa yang tidak jalan, lalu `NoteBox` berikon centang yang menyebut fitur apa yang tetap jalan tanpa internet, dan tombol opsional |

## Empat kondisi

Setiap layar yang memuat data punya empat kondisi, dikerjakan bersama layarnya. "Belum ada data sama sekali" dibedakan dari "hasil filter kosong". Salinan teks per layar ada di `05-spek-layar.md`. Pola umum:

| Kondisi | Pola teks | Contoh |
|---|---|---|
| Kosong (pertama kali) | Apa ini, satu aksi | "Buku kesalahan masih kosong. Soal yang salah akan masuk ke sini dan muncul lagi beberapa hari kemudian." Tombol: "Mulai latihan" |
| Filter kosong | Sebut filternya, tawarkan reset | "Tidak ada kartu Capture yang jatuh tempo." Tombol: "Tampilkan semua" |
| Memuat | Skeleton berbentuk konten | Tiga baris abu setinggi baris asli |
| Galat | Sebab dan langkah berikutnya | "Backup tidak bisa dibaca. Berkasnya bukan hasil ekspor dari app ini. Pilih berkas lain." Tombol: "Pilih berkas" |
| Offline (wawancara) | Yang tetap jalan | "Tidak ada internet. Wawancara memakai kartu pertanyaan template. Psikotes tetap jalan seperti biasa." Tombol: "Pakai kartu template" |

Dilarang: "Oops", "Something went wrong", "No data", "Submit", dan teks exception mentah.

## Microcopy

- Bahasa Indonesia, kalimat pendek, kalimat biasa dan huruf kecil di awal kata selain kata pertama.
- Tombol memakai kata kerja dan menyebut objeknya: "Simpan ke bank pribadi", "Mulai simulasi", "Ulangi yang jatuh tempo". Aksi yang sama punya nama yang sama di seluruh alur.
- Pesan galat menyebut apa yang gagal dan apa yang bisa dilakukan. Tidak meminta maaf.
- Tidak ada label huruf kapital semua, titik tengah ("A · B"), tanda panah di teks tombol, atau label dekoratif di atas konten.
- Teks diuji dengan kalimat terpanjang yang mungkin dan tidak boleh terpotong di 360 dp.

## Aturan anti AI slop (dari dokumen project)

Larangan konkret:
- Tanpa gradien sebagai latar utama, apalagi ungu-biru.
- Tanpa Inter, Poppins, atau Roboto.
- Tanpa `ColorScheme.fromSeed` tanpa override; tanpa dynamic color.
- Tanpa membungkus semua konten dalam kartu. Daftar adalah baris dan garis pemisah.
- Tanpa radius dan bayangan yang sama di semua elemen.
- Tanpa tiga kartu seragam berjajar.
- Tanpa emoji sebagai ikon; tanpa campuran ikon outlined dan filled.
- Tanpa spinner di tengah layar sebagai satu-satunya loading.
- Tanpa microcopy generik.
- Tanpa angka jarak di luar skala.
- Tanpa warna biru sebagai aksen (keputusan pemilik; terlihat generik).

Alur kerja: token sebelum layar; komponen sebelum layar; layar baru harus bisa dibangun dari token yang ada, dan kalau butuh nilai baru, ubah token dulu, jangan menambal di layar.

## Keputusan desain sadar per kelompok layar

| Kelompok | Keputusan |
|---|---|
| Setup dan beranda (S01 sampai S04) | Pilihan role berupa baris yang distabilo, bukan kartu. Satu-satunya panel berbingkai di beranda adalah "Latihan hari ini", karena itu aksi utamanya |
| Latihan (S05 sampai S09) | Stabilo hanya berarti "posisimu sekarang" (soal aktif, jawaban terpilih, kelemahan terbesar). Benar dan salah selalu bersama ikon dan teks, dan soal salah di strip pembahasan bergaris putus |
| Data dan pengaturan (S10 sampai S13, S18) | Daftar berupa baris dan garis. Catatan privasi muncul tepat di dekat isiannya (API key, Capture) |
| Kepribadian dan pengetahuan (S14, S19, S20) | Tidak ada warna benar atau salah karena tidak ada jawaban benar; profil memakai satu warna |
| Wawancara (S15 sampai S17) | Gelembung pengguna berlatar tinggi, bukan aksen; stabilo hanya untuk pilihan dan penanda "goyah" |

## Checklist UI sebelum menyatakan selesai

Jalankan dan laporkan poin per poin untuk setiap layar yang dibangun.

1. Semua warna, jarak, radius, ukuran teks berasal dari token? Sebutkan pelanggaran.
2. Hitung rasio kontras setiap pasangan teks dan latar yang dipakai (4,5 : 1 teks normal, 3 : 1 teks besar dan batas komponen). Tampilkan angkanya.
3. Keempat kondisi ada dan dirancang? Sebutkan yang belum.
4. Target sentuh minimal 48 dp? Setiap ikon punya label aksesibilitas?
5. Tema gelap diperiksa per layar?
6. Label diuji dengan teks Indonesia terpanjang dan ukuran font sistem 130 sampai 200%?
7. Sebutkan satu hal di layar ini yang merupakan keputusan desain sadar, bukan default.

## Yang belum ada di desain

- Papan kondisi (kosong, memuat, galat, offline) untuk layar data. Spesifikasi teksnya ada di `05-spek-layar.md`; papan visual dikerjakan bersama layarnya di tugas masing-masing.
- Tema gelap per layar (T21).
- Versi tablet dan layar lebar untuk demo web: tata letak web memakai kolom tengah selebar 480 dp.
