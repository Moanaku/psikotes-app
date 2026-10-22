# ADR-01: Flutter

Status: diterima

## Konteks

Keputusan ini diambil selama brainstorming blueprint Simulator Psikotes IT (Oktober 2026). Lihat `../01-prd.md` untuk masalah dan scope.

## Keputusan

Flutter.

## Alasan

Stack yang dikuasai; satu kode untuk Android dan web.

## Alternatif yang ditolak

Kotlin native, React.

## Konsekuensi

Perlu menjaga kompatibilitas web untuk Drift dan plugin; ukuran build web lebih besar dari aplikasi web biasa.
