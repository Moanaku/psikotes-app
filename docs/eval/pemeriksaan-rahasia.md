# Pemeriksaan rahasia sebelum repo dijadikan publik

Tanggal: 2026-10-26. Cabang: `fitur/rilis-persiapan`. Hanya membaca; riwayat git tidak diubah.
Cakupan: semua cabang lokal dan remote (`git rev-list --all`, 63 revisi) dan seluruh pohon berkas tiap revisi, termasuk berkas yang kemudian dihapus. Nilai yang cocok tidak dicetak di sini; hanya lokasi dan jenisnya.

## Yang dicari, perintah, hasil

| Yang dicari | Perintah | Hasil |
|---|---|---|
| Pola kunci API (`AIza`, `sk-`, `ghp_`, `github_pat_`, `xox`) | `git grep -I -l -E '<pola>' $(git rev-list --all)` | Tidak ada |
| Kunci privat | `git grep -I -l -e '-----BEGIN' $(git rev-list --all)` | Tidak ada |
| Kata sandi/token di konfigurasi (`password`, `secret`, `api_key`, `token`, `storePassword`, `keyPassword` dengan nilai literal) | `git grep -I -l -E '<kata>\s*[:=]\s*"..."'` semua revisi | Tidak ada nilai literal. `docs/RILIS-APK.md` hanya memuat tempat kosong `<sandi keystore>` |
| Berkas keystore, `.env`, `key.properties`, `google-services`, `local.properties`, kunci SSH | `git log --all --name-only` disaring ekstensi dan nama | Tidak pernah ada di riwayat. `.gitignore` memuat `.env`, `.env.*`, `key.properties` |
| Berkas yang pernah ada lalu dihapus | `git log --all --diff-filter=D --name-only` | Satu berkas: `lib/domain/services/planning_placeholders.dart` (kode, bukan data pribadi) |
| Alamat email | `git grep -I -h -o -E '<pola email>'` semua revisi, plus `git log --all --format='%ae %ce'` | Isi berkas: hanya `rahasia@contoh.id` di `test/data/backup_service_test.dart` (data palsu untuk test backup). Metadata commit: hanya alamat noreply GitHub (`...+Moanaku@users.noreply.github.com`, `noreply@github.com`) |
| Nomor telepon | `git grep -n -E '(\+62\|08)[0-9 -]{8,13}'` | Hanya `0812-0000-0000` palsu di berkas test yang sama |
| Jalur lokal dengan nama pengguna Windows | `git grep -E '[A-Za-z]:\Users\<nama>'`, `/Users/`, `C:/Users/`, serta nama pengguna mesin | Hanya contoh umum `C:/Users/<namamu>/Kunci/...` di `docs/RILIS-APK.md`. Nama pengguna mesin tidak ditemukan di berkas teks (kecocokan "ACER" hanya di berkas font biner `InstrumentSans-*.ttf`) |
| Data pribadi di `assets/`, `docs/`, `tool/` (nama atau perusahaan nyata dari Capture, isi CV) | `git ls-files assets tool`, `git grep` kata Capture/CV/perusahaan, baca hasil | `assets/` hanya font dan `.gitkeep`; `tool/` hanya skrip. `docs/` memuat spesifikasi fitur Capture/CV tanpa isi nyata. Folder `uji-perangkat/` (screenshot) di-ignore dan tidak terlacak. `tool/pregenerate/out/` di-ignore |

Nama pemilik muncul sebagai nama penulis commit ("Dani Banan Husna"), nama pengguna GitHub `Moanaku` di jalur paket Android (`io.github.moanaku.psikotes`), dan pemilik di dokumen. Itu identitas publik yang disengaja, bukan rahasia.

## Penilaian

Tidak ada temuan nyata: tidak ada kunci, kata sandi, keystore, berkas `.env`, email pribadi, nomor telepon asli, atau jalur lokal dengan nama pengguna. Aman dijadikan publik dari sisi rahasia.

Batas pemeriksaan: pencarian memakai pola, jadi rahasia dengan bentuk tak lazim bisa lolos; berkas biner (selain pencocokan nama) tidak dibaca isinya; riwayat di luar repo ini (fork, cache GitHub) tidak diperiksa. Saran: sebelum publik, periksa sekali di GitHub bahwa tidak ada PR/issue yang memuat tangkapan layar berisi data pribadi.
