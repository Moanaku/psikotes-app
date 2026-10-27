# Pre-generate bank verbal (T07, F04)

Membuat `assets/verbal_bank.json` (VRB-SYN dan VRB-ANA) di luar app, dengan Claude lewat langganan (`claude -p`, ADR-12). Tidak memakai API berbayar. Hanya Python 3.10+ standar, tanpa `pip install`.

Folder kerja `tool/pregenerate/out/` di-ignore git. Setiap tahap bisa dijalankan ulang: soal yang sudah ada tidak dibuat atau diperiksa dua kali.

## Menjalankan (satu kali, memakai kuota langganan)

Jalankan dari akar repo. Perkiraan: sekitar 35 panggilan `claude -p` untuk pass 1 dan 35 untuk pass 2.

```bash
python tool/pregenerate/gen_verbal.py --per-type 170
python tool/pregenerate/verify_verbal.py
python tool/pregenerate/bundle.py
```

Lalu periksa `docs/eval/verbal_sample.md` (30 soal, 10% bank). Soal yang meragukan: tulis ID-nya satu per baris di `docs/eval/verbal_flags.txt`, jalankan `python tool/pregenerate/bundle.py` lagi. Soal bertanda dibuang dari bank (disimpan di `out/needs_review.jsonl`) dan diganti kandidat lolos lain.

Setelah bank jadi: buka komentar `assets/verbal_bank.json` di bagian `assets:` pada `pubspec.yaml`, dan validasi dengan `python tool/pregenerate/bundle.py --check`.

Bila `bundle.py` melapor kekurangan soal (karena banyak yang dibuang di pass 2), naikkan `--per-type` (mis. 200) pada `gen_verbal.py`, jalankan ulang `verify_verbal.py` dan `bundle.py`; soal lama dipertahankan.

## Tahap

| Berkas | Tugas | Keluaran di `out/` |
|---|---|---|
| `gen_verbal.py` | Pass 1: `claude -p` membuat kandidat per tipe, kesulitan, dan tema; opsi diacak ulang di skrip | `candidates.jsonl` |
| `verify_verbal.py` | Pass 2: prompt berbeda menjawab tanpa kunci, opsi diacak ulang; dibuang bila jawaban beda atau ditandai ambigu | `verified.jsonl`, `dropped.jsonl`, `verify_report.json` |
| `bundle.py` | Memilih 150 per tipe (50 per kesulitan), membuang yang bertanda, kembar, atau kata ganda; menulis bank dan sampel | `bundle_report.json`, `needs_review.jsonl` |
| `schema.py` | Validator skema (dipakai `bundle.py` dan tes) | |
| `common.py` | Runner `claude -p`, ekstraksi JSON, jsonl | |
| `test_pregenerate.py` | Tes dengan runner palsu, tanpa memanggil claude | |

Uji skrip: `python -m unittest discover -s tool/pregenerate -p "test_*.py"`.

Uji kecil dengan `claude` sungguhan (6 soal), tanpa menyentuh `assets/`:

```bash
python tool/pregenerate/gen_verbal.py --per-type 3 --batch 3 --out tool/pregenerate/out/smoke
python tool/pregenerate/verify_verbal.py --out tool/pregenerate/out/smoke --batch 6
python tool/pregenerate/bundle.py --out tool/pregenerate/out/smoke --bank tool/pregenerate/out/smoke/bank.json --sample-path tool/pregenerate/out/smoke/sample.md --per-type 3 --sample 6 --allow-partial
```

## Isi bank (target v1: 300 soal)

| Tipe | Jumlah | Easy | Medium | Hard | Isi |
|---|---|---|---|---|---|
| VRB-SYN | 150 | 50 | 50 | 50 | Sinonim dan antonim ("Padanan kata ... / Lawan kata ..."); kesulitan menurut frekuensi kata |
| VRB-ANA | 150 | 50 | 50 | 50 | Analogi kata `A : B = C : ...`; kesulitan menurut jenis relasi |

Skema (`docs/06-bank-konten.md`), ditambah `jumlah` (hitungan per tipe):

```json
{ "versi": 1, "dibuat": "YYYY-MM-DD", "jumlah": {"VRB-SYN": 150, "VRB-ANA": 150},
  "soal": [ { "id": "VRB-SYN-0001", "type": "VRB-SYN", "difficulty": "medium",
              "stem": "Padanan kata \"efisien\" adalah ...",
              "options": ["...", "...", "...", "..."], "correctIndex": 0,
              "explanation": "...", "needsReview": false,
              "passes": { "generate": "pass1", "verify": "pass2-agree" } } ] }
```

Aturan yang dijaga validator: 4 opsi tidak kembar (tanpa beda huruf besar atau spasi); `correctIndex` dalam rentang; kata di soal tidak muncul sebagai opsi; `stem` memuat `...`; `explanation` tidak kosong; `needsReview` selalu `false` di bundel; tidak ada `id` atau `stem` ganda; kolom hanya yang ada di skema. ID mengikuti nomor pass 1, jadi boleh ada celah nomor.

Keterbatasan: pass 2 memakai model yang sama, jadi memberi bukti kesepakatan, bukan bukti benar. Karena itu pemeriksaan manual 10% oleh pemilik tetap wajib sebelum T07 dianggap selesai penuh.

## Pool kepribadian (T22, F12)

`gen_personality.py` membuat `assets/personality_pool.json` (8 sifat, 12 pernyataan per sifat secara bawaan, 8 panggilan `claude -p`) dan `docs/eval/personality_sample.md`. Pernyataan disaring: diawali "Saya", 25 sampai 110 karakter, tanpa istilah klinis, tanpa "tidak", "jarang", "benar", "salah".

```bash
python tool/pregenerate/gen_personality.py                  # 12 per sifat
python tool/pregenerate/gen_personality.py --per-trait 16   # menambah sampai 16
python tool/pregenerate/gen_personality.py --bundle-only    # setelah mengisi docs/eval/personality_flags.txt
```

