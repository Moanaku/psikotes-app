#!/usr/bin/env bash
# Menyiapkan dua berkas yang dibutuhkan database di web: web/sqlite3.wasm dan
# web/drift_worker.js (lihat lib/data/db/connection.dart dan A44). Keduanya tidak
# di-commit (.gitignore); jalankan ini setelah `flutter pub get` dan sebelum
# `flutter run -d chrome` atau `flutter build web`.
#
# - drift_worker.js dikompilasi dari tool/web/drift_worker.dart.
# - sqlite3.wasm diambil dari paket drift yang sudah ada di cache pub (dibangun
#   dari versi paket sqlite3 yang sama), jadi tanpa unduhan dari luar.
set -euo pipefail
cd "$(dirname "$0")/.."

PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

drift_dir="$($PY - <<'PYEOF'
import json, sys
cfg = json.load(open('.dart_tool/package_config.json', encoding='utf-8'))
for pkg in cfg['packages']:
    if pkg['name'] == 'drift':
        root = pkg['rootUri']
        if root.startswith('file:///'):
            root = root[len('file:///'):]
            if len(root) > 2 and root[1] == ':':
                pass
            else:
                root = '/' + root
        else:
            root = '.dart_tool/' + root
        print(root)
        sys.exit(0)
sys.exit('paket drift tidak ada di package_config.json; jalankan flutter pub get')
PYEOF
)"
drift_dir="$(printf '%s' "$drift_dir" | sed 's#%20# #g;s#/$##')"

wasm="$drift_dir/extension/devtools/build/sqlite3.wasm"
[ -f "$wasm" ] || { echo "GAGAL: $wasm tidak ditemukan"; exit 1; }
cp "$wasm" web/sqlite3.wasm

dart compile js -O4 tool/web/drift_worker.dart -o web/drift_worker.js >/dev/null
rm -f web/drift_worker.js.deps web/drift_worker.js.map

echo "prepare_web: OK ($(wc -c < web/sqlite3.wasm) byte sqlite3.wasm, $(wc -c < web/drift_worker.js) byte drift_worker.js)"
