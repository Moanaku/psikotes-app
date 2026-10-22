#!/usr/bin/env bash
# Bagian Linux dari tool/update_goldens.sh. Jangan dipanggil langsung kecuali di Linux.
# Menyalin repo ke ~/.cache (cepat, tidak menyentuh .dart_tool Windows), memasang Flutter
# versi pin dari ci.yml bila belum ada, menjalankan test golden dengan --update-goldens,
# lalu menyalin PNG kembali ke repo.
set -eu
repo="$1"
shift
verify=0
if [ "${1:-}" = "--verify" ]; then
  verify=1
  shift
fi
cache="${XDG_CACHE_HOME:-$HOME/.cache}/psikotes-goldens"
version="$(grep -E '^\s*flutter-version:' "$repo/.github/workflows/ci.yml" | head -1 | sed -E 's/.*flutter-version:\s*//; s/\r//; s/["'\'']//g')"
[ -n "$version" ] || { echo "GAGAL: flutter-version tidak ditemukan di .github/workflows/ci.yml"; exit 1; }

mkdir -p "$cache/bin"
# Flutter butuh unzip. Tanpa itu (dan tanpa sudo), pakai pengganti kecil berbasis Python.
if ! command -v unzip >/dev/null 2>&1; then
  cat >"$cache/bin/unzip" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, zipfile
args, dest, files, i = sys.argv[1:], ".", [], 0
while i < len(args):
    if args[i] == "-d": dest = args[i + 1]; i += 2; continue
    if not args[i].startswith("-"): files.append(args[i])
    i += 1
z = zipfile.ZipFile(files[0])
for info in z.infolist():
    path = z.extract(info, dest)
    mode = (info.external_attr >> 16) & 0o777
    if mode: os.chmod(path, mode)
PYEOF
  chmod +x "$cache/bin/unzip"
  export PATH="$cache/bin:$PATH"
fi

flutter_dir="$cache/flutter-$version"
if [ ! -d "$flutter_dir" ]; then
  echo "Memasang Flutter $version di $flutter_dir ..."
  git clone --depth 1 -b "$version" https://github.com/flutter/flutter.git "$flutter_dir"
fi
export PATH="$flutter_dir/bin:$PATH"
export CI=true
flutter --version >"$cache/version.txt" 2>&1 || { cat "$cache/version.txt"; exit 1; }
head -1 "$cache/version.txt"

work="$cache/repo"
rm -rf "$work"
mkdir -p "$work"
exclude_goldens=--exclude=test/core/goldens
[ "$verify" -eq 1 ] && exclude_goldens=--exclude=.git
(cd "$repo" && tar --exclude=.git --exclude=.dart_tool --exclude=build --exclude=.idea \
  $exclude_goldens -cf - .) | tar -xf - -C "$work"
cd "$work"
flutter pub get >/dev/null
if [ "$verify" -eq 1 ]; then
  flutter test test/core --tags golden "$@"
  echo "Golden cocok (Flutter $version, Linux)."
  exit 0
fi
flutter test test/core --tags golden --update-goldens "$@"

mkdir -p "$repo/test/core/goldens"
cp -f test/core/goldens/*.png "$repo/test/core/goldens/"
echo "Golden diperbarui di test/core/goldens (Flutter $version, Linux)."
