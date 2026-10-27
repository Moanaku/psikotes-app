# Rilis APK dan web (untuk pemilik)

Berkas ini berisi hal yang hanya bisa dilakukan pemilik repo: membuat keystore, mengisi secret, dan membuat tag rilis. Keystore, sandi, dan key jangan pernah masuk repo, log, chat, atau tangkapan layar.

## Gambaran

| Pemicu | Hasil |
|---|---|
| Push tag `v*` | Workflow `release-apk` membangun APK rilis dan melampirkannya ke GitHub Releases |
| Push tag `v*` atau jalankan manual | Workflow `pages` membangun web dan menerbitkannya ke GitHub Pages (lihat "Menunggu keputusan pemilik") |
| Push biasa dan pull request | Hanya `ci` yang jalan; tidak ada rilis |

Tanpa secret keystore, APK tetap dibangun tetapi ditandatangani kunci debug, dan catatan rilis menyebutnya. APK bertanda debug bisa dicoba di HP sendiri, tetapi tidak bisa menimpa app yang dipasang dari APK bertanda tangan lain, dan tidak cocok untuk dibagikan luas. Untuk rilis yang bisa diperbarui, buat keystore sekali saja dengan langkah di bawah.

## 1. Membuat keystore (sekali saja)

Lewat Android Studio (Windows):

1. Buka proyek ini di Android Studio, lalu buka folder `android` (File, Open, pilih `...\simulator-psikotes-it\android`). Tunggu sinkronisasi Gradle selesai.
2. Menu **Build**, pilih **Generate Signed App Bundle / APK...**.
3. Pilih **APK**, klik **Next**.
4. Di "Key store path", klik **Create new...**.
5. Klik ikon folder di "Key store path", pilih folder di luar repo (misalnya `C:\Users\<namamu>\Kunci`), ketik nama berkas `psikotes-release`, klik **OK**. Berkas jadi `psikotes-release.jks`.
6. Isi **Password** dan **Confirm** (sandi keystore). Catat di pengelola sandi.
7. Di bagian Key: **Alias** isi `psikotes`, **Password** dan **Confirm** isi sandi kunci (boleh sama dengan sandi keystore), **Validity (years)** isi `30`.
8. Di Certificate, isi minimal satu kolom (misalnya **First and Last Name**). Klik **OK**.
9. Jendela kembali ke "Generate Signed Bundle or APK". Tutup dengan **Cancel**; kita hanya butuh keystore-nya.

Cadangkan `psikotes-release.jks` dan kedua sandi di dua tempat aman (misalnya pengelola sandi dan flashdisk). Bila keystore hilang, app yang sudah terpasang tidak bisa diperbarui; harus dicopot lalu dipasang ulang (data hilang, jadi ekspor backup dulu).

Cara lain lewat terminal (JDK ada bersama Android Studio):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore C:\Users\<namamu>\Kunci\psikotes-release.jks -alias psikotes -keyalg RSA -keysize 2048 -validity 10950
```

## 2. Mengisi secret di GitHub

1. Ubah keystore menjadi teks base64 dan salin ke clipboard (PowerShell). Jangan tempel hasilnya di mana pun selain kolom secret:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\<namamu>\Kunci\psikotes-release.jks")) | Set-Clipboard
   ```

2. Buka repo di GitHub, **Settings**, **Secrets and variables**, **Actions**, tab **Secrets**, klik **New repository secret**.
3. Name `KEYSTORE_BASE64`, Secret: tempel clipboard, klik **Add secret**.
4. **New repository secret** lagi: `KEYSTORE_PASSWORD`, isi sandi keystore.
5. `KEY_ALIAS`, isi `psikotes`.
6. `KEY_PASSWORD`, isi sandi kunci.
7. Kosongkan clipboard (salin teks lain apa saja).

Keempatnya harus ada. Bila salah satu kosong, workflow memakai kunci debug.

## 3. Membangun APK rilis di komputer sendiri (opsional)

Tanpa `android/key.properties`, build rilis memakai kunci debug. Untuk menandatangani sendiri, buat `android\key.properties` (sudah di `.gitignore`):

```properties
storePassword=<sandi keystore>
keyPassword=<sandi kunci>
keyAlias=psikotes
storeFile=C:/Users/<namamu>/Kunci/psikotes-release.jks
```

Lalu `flutter build apk --release`. Hasil: `build\app\outputs\flutter-apk\app-release.apk`. Hapus `key.properties` bila tidak dipakai lagi.

## 4. Menerbitkan v1.0.0

Jalankan `bash tool/rilis.sh` (atau `bash tool/rilis.sh v1.0.0`) dari `main`. Skrip hanya memeriksa dan mencetak: cabang dan pohon bersih, sinkron dengan origin, versi pubspec cocok dengan tag, pemindaian rahasia di semua revisi, CI main hijau, dan empat secret keystore ada (hanya nama). Di akhir ia mencetak perintah untuk pemilik (repo publik, Pages, tag). Skrip tidak menjalankan satu pun langkah yang tidak bisa dibatalkan.

Lakukan setelah semua kotak di [eval/checklist-v1.0.0.md](eval/checklist-v1.0.0.md) lulus dan tidak ada bug `severity:1` terbuka.

1. Merge pull request T20 ke `main` (CI harus hijau).
2. `pubspec.yaml` sudah `version: 1.0.0+1`. Workflow menolak tag yang tidak sama dengan nomor versi di sana.
3. Di `CHANGELOG.md`, ganti `belum dirilis` pada `[1.0.0]` dengan tanggal rilis, commit lewat pull request kecil.
4. Buat dan dorong tag:

   ```bash
   git checkout main
   git pull
   git tag -a v1.0.0 -m "v1.0.0"
   git push origin v1.0.0
   ```

5. Pantau di tab **Actions**: `release-apk` (dan `pages`). Hasilnya di **Releases**, berkas `psikotes-it-v1.0.0.apk`.
6. Pasang di HP: unduh APK dari Releases, buka, izinkan "pasang dari sumber ini" bila diminta.

Bila tag salah dan belum dipakai, hapus: `git push origin --delete v1.0.0` dan `git tag -d v1.0.0`, hapus rilisnya di halaman Releases, perbaiki, lalu buat tag lagi.

## Menunggu keputusan pemilik

- **GitHub Pages dan repo privat.** Repo ini privat, dan Pages untuk repo privat butuh paket GitHub berbayar. Workflow `pages` sudah ditulis tetapi hanya jalan saat dipicu manual atau pada tag; selama paketnya belum ada, job `deploy` akan gagal (job `build` tetap hijau dan membuktikan web bisa dibangun). Pilihan: (a) jadikan repo publik, (b) tetap privat dan lewati demo web, (c) pakai paket berbayar (melanggar aturan biaya Rp0). Tag `v1.0.0` akan memicu `pages` juga; bila belum memutuskan, kegagalan itu diharapkan.
- Setelah memilih (a): Settings, Pages, Source: **GitHub Actions**, lalu jalankan workflow `pages` secara manual atau lewat tag.

## Ikon app

Ikon dibuat dari satu sumber, `tool/ikon/ikon.svg` (matriks 3x3, satu sel kosong di pojok kanan bawah bersorot stabilo; warna dari token). Untuk mengubahnya, ubah SVG lalu jalankan `python tool/ikon/gen_ikon.py` (Pillow dibutuhkan; `--preview <folder>` menulis contoh crop lingkaran dan kotak membulat). Skrip menulis ikon adaptif Android (foreground, background, monokrom), PNG untuk Android lama, ikon web, dan favicon. Jangan mengedit PNG-nya langsung.
