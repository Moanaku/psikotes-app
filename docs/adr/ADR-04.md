# ADR-04: Soal verbal dari pre-generate LLM + verifikasi, dibundel

Status: diterima

## Konteks

Keputusan ini diambil selama brainstorming blueprint Simulator Psikotes IT (Oktober 2026). Lihat `../01-prd.md` untuk masalah dan scope.

## Keputusan

Soal verbal dari pre-generate LLM + verifikasi, dibundel.

## Alasan

Offline, Rp0 saat runtime, kunci bisa dicek.

## Alternatif yang ditolak

LLM saat runtime; LLM on-device.

## Konsekuensi

Bank berukuran tetap sehingga soal verbal bisa berulang; pemeriksaan manual 10% wajib.
