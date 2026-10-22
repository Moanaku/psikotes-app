#!/usr/bin/env bash
# Pemeriksaan aturan UI proyek (CLAUDE.md, docs/04-sistem-desain.md).
# Gagal (exit 1) bila widget memakai warna mentah, Colors.*, fromSeed, atau jarak di luar skala.
set -u
cd "$(dirname "$0")/.."
TOOLS="$(pwd)/tool"
# CHECK_TOKENS_ROOT dipakai tool/check_tokens_test.sh untuk memeriksa contoh pelanggaran.
cd "${CHECK_TOKENS_ROOT:-.}"
fail=0
SRC="lib"
THEME="lib/core/theme/app_tokens.dart"

# Python 3 wajib ada; tanpa itu pemeriksaan jarak diam-diam lolos.
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 &&
    "$cand" -c 'import sys; sys.exit(sys.version_info[0] < 3)' >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "GAGAL: Python 3 tidak ditemukan; pemeriksaan tidak bisa jalan."
  exit 1
fi

# Hapus baris komentar (// dan ///) dari hasil grep -n.
nocomment() { grep -vE "^[^:]+:[0-9]+:[[:space:]]*//" || true; }

report() { echo "GAGAL: $1"; echo "$2"; echo; fail=1; }

# 1. Hex mentah, Color(0x...), Color.fromARGB/fromRGBO/from di luar app_tokens.dart
out=$(grep -rnE "Color\(0x[0-9A-Fa-f]+\)|Color\.from(ARGB|RGBO)?\(" "$SRC" --include=*.dart | grep -v "^$THEME" | nocomment)
[ -n "$out" ] && report "Warna mentah di luar app_tokens.dart" "$out"

# 2. Colors.* (kecuali Colors.transparent)
out=$(grep -rnE "(^|[^A-Za-z_])Colors\.[a-zA-Z]+" "$SRC" --include=*.dart | grep -v "Colors.transparent" | nocomment)
[ -n "$out" ] && report "Colors.* dilarang; pakai context.tokens atau colorScheme" "$out"

# 3. ColorScheme.fromSeed dan dynamic color
out=$(grep -rnE "fromSeed|DynamicColorBuilder|dynamic_color" "$SRC" pubspec.yaml | nocomment)
[ -n "$out" ] && report "fromSeed / dynamic color dilarang" "$out"

# 4. Gradien
out=$(grep -rnE "LinearGradient|RadialGradient|SweepGradient" "$SRC" --include=*.dart | nocomment)
[ -n "$out" ] && report "Gradien dilarang" "$out"

# 5. Font bawaan yang dilarang
out=$(grep -rniE "Inter|Poppins|Roboto" "$SRC" --include=*.dart | grep -iE "fontFamily|GoogleFonts" | nocomment)
[ -n "$out" ] && report "Font Inter/Poppins/Roboto dilarang" "$out"

# 6. Pemeriksaan lintas baris (jarak, radius, ukuran teks, durasi, kurva, Opacity, bayangan,
#    keluarga ikon, emoji, microcopy generik, exception mentah). Lihat tool/check_tokens_scan.py.
"$PY" "$TOOLS/check_tokens_scan.py" . || fail=1

# 7. Font terlarang di pubspec.yaml
out=$(grep -nE "family:[[:space:]]*['\"]?(Inter|Poppins|Roboto)" pubspec.yaml 2>/dev/null || true)
[ -n "$out" ] && report "Font Inter/Poppins/Roboto dilarang di pubspec.yaml" "$out"

if [ "$fail" -eq 0 ]; then echo "check_tokens: OK"; fi
exit "$fail"
