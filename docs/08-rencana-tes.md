# 08. Rencana tes

Kualitas dibuktikan di enam level dengan fokus terbesar pada engine: setiap soal harus valid sebelum pernah tampil. Semua tes otomatis berjalan di GitHub Actions pada setiap push.

| Level | Apa yang diuji | Alat | Target |
|---|---|---|---|
| Unit | Generator, solver, penilaian, jadwal SM-2, rencana harian, sanitasi CV, backup | `flutter_test`, `test` | Cakupan engine 90% atau lebih |
| Property-based | Invarian semua generator pada ribuan seed acak | `glados` | 10.000 seed per tipe dan kesulitan, 0 gagal |
| Lintas platform | `Rng` dan soal identik di VM dan Chrome | `dart test -p vm,chrome` | Nilai emas sama |
| Widget dan golden | Komponen inti, layar sesi, review, render soal figural | `flutter_test`, golden | Semua layar v1; terang dan (setelah T21) gelap |
| Integrasi | Alur penuh | `integration_test` | 3 alur utama |
| Evaluasi LLM | Konsistensi penilai wawancara | Skrip dan test set | Selisih skor maksimal 1 poin pada 80% kasus |
| Manual | Pemakaian di HP asli dan browser | Checklist | Sebelum setiap rilis |

## Invarian engine (property test)

Berlaku untuk setiap generator yang terdaftar:

1. Tepat satu opsi benar menurut solver, dan sama dengan `correctIndex`.
2. Tidak ada dua opsi yang identik.
3. Seed sama menghasilkan soal identik (determinisme), termasuk setelah serialisasi JSON bolak-balik.
4. Posisi jawaban benar tersebar merata di semua posisi opsi (uji chi-kuadrat sederhana pada 10.000 seed, ambang ditetapkan di test).
5. Semua nilai dalam batas: angka wajar, gambar di dalam kotak, teks tidak kosong, `explanation` tidak kosong.
6. Waktu pembuatan satu soal di bawah 50 ms (diukur di VM; target HP kelas menengah dipantau manual).
7. Tidak melempar `GenerationFailure` pada seed mana pun dalam rentang uji, dan persentase soal yang butuh percobaan ulang dicatat.

Aturan: kegagalan invarian diperbaiki di generator, bukan dengan melonggarkan invarian. Setiap bug engine yang ditemukan menjadi test baru sebelum diperbaiki.

## Alur integrasi (3 alur utama)

1. **Profil sampai statistik:** buat profil Umum, simulasi satu subtes, lihat hasil dan pembahasan, buka statistik. Periksa angka konsisten.
2. **Buku kesalahan:** jawab salah, kartu terbentuk jatuh tempo besok, majukan jam palsu ke besok, ulangi benar tiga kali, kartu dikuasai.
3. **Capture:** simpan soal Capture, kerjakan di sesi latihan, jawab salah, kartu muncul di buku kesalahan; ekspor backup lalu impor di database bersih.

## Evaluasi LLM wawancara (v1.3)

- 25 jawaban contoh dengan skor yang diharapkan: 10 kuat, 10 lemah, 5 ambigu.
- Dijalankan 3 kali; dicatat rata-rata selisih skor dan kestabilan keputusan gali atau lanjut.
- Hasil disimpan di `docs/eval/` sebagai bukti untuk README.

## Checklist manual (tiap rilis)

- Simulasi tetap berjalan benar setelah app ditutup paksa (posisi dan sisa waktu).
- Soal figural terbaca di layar 360 dp dan di mode gelap (setelah T21).
- Semua layar terbaca di ukuran font sistem 130% dan 200%, tanpa teks terpotong.
- Setiap layar data menampilkan empat kondisi dengan teks dari spesifikasi.
- Wawancara tanpa internet beralih ke kartu template (v1.3).
- Ekspor dan impor backup tidak kehilangan data; key API tidak ada di berkas.
- Demo web bisa dibuka di Chrome Android tanpa login.
- Buka app di luar ruangan pada cahaya terang: teks masih terbaca.
- Satu tugas utama dijalankan dari awal sampai selesai tanpa langkah yang janggal.

## Pemeriksaan UI otomatis

- `tool/check_tokens.sh` gagal bila ada hex mentah, `Colors.*`, atau jarak di luar skala di `lib/` (kecuali `app_tokens.dart`).
- Golden test komponen inti terang dan gelap.
- Uji semantik: setiap ikon tanpa teks punya label.

## Pelacakan bug

GitHub Issues dengan label `bug`, `severity:1`, `severity:2`, `severity:3`, dan ID fitur (misalnya `F04`). Tingkat keparahan:
- `severity:1`: soal salah (lebih dari satu kunci, kunci salah), data hilang, sesi rusak.
- `severity:2`: fitur tidak jalan tetapi ada jalan lain, tampilan rusak di layar 360 dp.
- `severity:3`: kosmetik, teks, kontras kecil.

Setiap bug `severity:1` diperbaiki sebelum rilis berikutnya.

## Kriteria rilis v1.0.0

- Semua test otomatis hijau di CI; property test 10.000 seed per tipe.
- Tiga alur integrasi lulus.
- Checklist manual terisi di `docs/eval/checklist-v1.0.0.md`.
- Tidak ada bug `severity:1` terbuka.
- Web terbit di GitHub Pages dan APK terlampir di GitHub Releases.
