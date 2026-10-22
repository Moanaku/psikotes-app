# ADR-12: Konten pre-generate dibuat dengan Claude lewat langganan; wawancara memakai key Gemini atau Groq milik pengguna

Status: diterima

## Konteks

Keputusan ini diambil selama brainstorming blueprint Simulator Psikotes IT (Oktober 2026). Lihat `../01-prd.md` untuk masalah dan scope.

## Keputusan

Konten pre-generate dibuat dengan Claude lewat langganan; wawancara memakai key Gemini atau Groq milik pengguna.

## Alasan

Langganan Claude Pro tidak menyertakan API key, API ditagih terpisah; langganan cukup untuk menyusun bank soal dan bank pengetahuan sebelum rilis.

## Alternatif yang ditolak

Claude API saat runtime (berbayar).

## Konsekuensi

Skrip pre-generate dijalankan lewat Claude Code atau chat; penyedia LLM wawancara diputuskan sebelum v1.3.
