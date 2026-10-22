# 09. Decision log

Tiga belas keputusan sudah diambil. Tambahkan baris baru di atas setiap ada keputusan penting dan satu berkas di `adr/` memakai templat di `adr/ADR-template.md`. Baris ini bahan menjawab pertanyaan "kenapa" saat wawancara.

| No | Keputusan | Alasan | Alternatif yang ditolak |
|---|---|---|---|
| [ADR-13](adr/ADR-13.md) | Golden test mengacu pada Linux dengan versi Flutter yang dipin; Windows melewati tag `golden` | CI di Linux; render glyph Windows dan Linux berbeda 1 sampai 10% piksel walau versi Flutter sama | Menaikkan ambang; golden per OS; golden tanpa tag |
| [ADR-12](adr/ADR-12.md) | Konten pre-generate dibuat dengan Claude lewat langganan; wawancara memakai key Gemini atau Groq milik pengguna | Langganan Claude Pro tidak menyertakan API key, API ditagih terpisah; langganan cukup untuk menyusun bank soal dan bank pengetahuan sebelum rilis | Claude API saat runtime (berbayar) |
| [ADR-11](adr/ADR-11.md) | Wawancara (F15, F18) dikerjakan paling akhir | Psikotes diuji dan dipakai dulu; wawancara paling bergantung pada layanan luar dan paling berisiko | Wawancara di v1.2 |
| [ADR-10](adr/ADR-10.md) | Mode Umum tanpa role dan Bank Pengetahuan Role (F17) | Pelamar bisa mulai tanpa memilih role; pertanyaan role dari dasar sampai lanjut melengkapi psikotes | Pertanyaan role hanya lewat wawancara |
| [ADR-09](adr/ADR-09.md) | Distribusi lewat web (GitHub Pages) dan APK, tanpa Play Store | Tujuannya portofolio; HR bisa mencoba tanpa install; Rp0 | Play Store (biaya, review, bukan tujuan) |
| [ADR-08](adr/ADR-08.md) | Wawancara berbasis CV dengan persona HR dan User | Relevansi: pertanyaan dari CV dan lowongan sendiri | Bank pertanyaan generik |
| [ADR-07](adr/ADR-07.md) | Scope dibatasi ke psikotes IT | Menjawab masalah sendiri; scope jelas | Semua jenis psikotes dan pelamar umum |
| [ADR-06](adr/ADR-06.md) | Tes gambar proyektif keluar dari scope | Tidak bisa dinilai offline secara jujur; nilai belajar rendah | Kanvas + checklist |
| [ADR-05](adr/ADR-05.md) | Generator figural jadi inti v1 | Soal bergambar dikunci berbayar di app lain; biaya generator hampir nol | Bank gambar manual |
| [ADR-04](adr/ADR-04.md) | Soal verbal dari pre-generate LLM + verifikasi, dibundel | Offline, Rp0 saat runtime, kunci bisa dicek | LLM saat runtime; LLM on-device |
| [ADR-03](adr/ADR-03.md) | Soal disimpan sebagai tipe + seed | Reproducible, hemat penyimpanan, mudah dites | Menyimpan soal utuh |
| [ADR-02](adr/ADR-02.md) | Engine sebagai package Dart murni | Bisa diuji tanpa UI, dipakai ulang di web dan Android | Logika di dalam widget |
| [ADR-01](adr/ADR-01.md) | Flutter | Stack yang dikuasai; satu kode untuk Android dan web | Kotlin native, React |

## Keputusan yang masih terbuka

Lihat `11-asumsi-dan-pertanyaan.md`.
