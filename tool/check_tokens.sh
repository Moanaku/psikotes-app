#!/usr/bin/env bash
# Pemeriksaan aturan UI proyek (CLAUDE.md, docs/04-sistem-desain.md).
# Gagal (exit 1) bila widget memakai warna mentah, Colors.*, fromSeed, atau jarak di luar skala.
set -u
cd "$(dirname "$0")/.."
fail=0
SRC="lib"
THEME="lib/core/theme/app_tokens.dart"

# Hapus baris komentar (// dan ///) dari hasil grep -n.
nocomment() { grep -vE "^[^:]+:[0-9]+:[[:space:]]*//" || true; }

report() { echo "GAGAL: $1"; echo "$2"; echo; fail=1; }

# 1. Hex mentah atau Color(0x...) di luar app_tokens.dart
out=$(grep -rnE "Color\(0x[0-9A-Fa-f]+\)" "$SRC" --include=*.dart | grep -v "^$THEME" | nocomment)
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

# 6. Jarak di luar skala pada EdgeInsets / SizedBox literal (skala 4,8,12,16,24,32,48)
out=$(grep -rnE "(EdgeInsets\.(all|symmetric|only|fromLTRB)|SizedBox)\(" "$SRC" --include=*.dart \
  | grep -v "$THEME" \
  | grep -oE "^[^:]+:[0-9]+:.*" \
  | python3 -c '
import re,sys
ok={0,4,8,12,16,24,32,48}
bad=[]
for line in sys.stdin:
    body=line.split(":",2)[2]
    for m in re.finditer(r"(?:all|symmetric|only|fromLTRB|SizedBox)\(([^)]*)\)",body):
        if "AppSpace" in m.group(1) and not re.search(r"(?<![A-Za-z_.])\d+(?:\.\d+)?(?![A-Za-z_])",re.sub(r"AppSpace\.s\d+","",m.group(1))):
            continue
        for n in re.findall(r"(?<![A-Za-z_.\d])(\d+(?:\.\d+)?)(?![\d.]*[A-Za-z_])",re.sub(r"AppSpace\.s\d+","",m.group(1))):
            v=float(n)
            if v not in ok and not (v>=48):
                bad.append(line.strip()); break
print("\n".join(dict.fromkeys(bad)))
' || true)
[ -n "$out" ] && report "Jarak literal di luar skala; pakai AppSpace.sN" "$out"

if [ "$fail" -eq 0 ]; then echo "check_tokens: OK"; fi
exit "$fail"
