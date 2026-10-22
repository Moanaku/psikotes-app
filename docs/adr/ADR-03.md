# ADR-03: Soal disimpan sebagai tipe + seed

Status: diterima

## Konteks

Keputusan ini diambil selama brainstorming blueprint Simulator Psikotes IT (Oktober 2026). Lihat `../01-prd.md` untuk masalah dan scope.

## Keputusan

Soal disimpan sebagai tipe + seed.

## Alasan

Reproducible, hemat penyimpanan, mudah dites.

## Alternatif yang ditolak

Menyimpan soal utuh.

## Konsekuensi

Perubahan generator bisa mengubah soal lama dari seed yang sama; generator diberi nomor versi bila diubah dan soal lama dari buku kesalahan dijaga lewat versi generator.
