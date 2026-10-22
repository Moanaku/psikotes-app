# ADR-02: Engine sebagai package Dart murni

Status: diterima

## Konteks

Keputusan ini diambil selama brainstorming blueprint Simulator Psikotes IT (Oktober 2026). Lihat `../01-prd.md` untuk masalah dan scope.

## Keputusan

Engine sebagai package Dart murni.

## Alasan

Bisa diuji tanpa UI, dipakai ulang di web dan Android.

## Alternatif yang ditolak

Logika di dalam widget.

## Konsekuensi

Antarmuka engine harus stabil; tidak ada akses I/O di dalam engine.
