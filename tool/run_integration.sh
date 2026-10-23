#!/usr/bin/env bash
# Menjalankan tiga integration_test (integration_test/*_test.dart).
#
#   bash tool/run_integration.sh              # mesin uji bawaan Flutter, tanpa perangkat
#   bash tool/run_integration.sh <id>         # di perangkat atau emulator (flutter devices)
#
# Mesin uji bawaan (`-d flutter-tester`) hanya mau menjalankan satu berkas per
# perintah, jadi berkasnya dijalankan satu per satu. Berkas yang gagal tidak
# menghentikan yang lain; hasil akhir gagal bila ada satu saja yang gagal.
set -u
cd "$(dirname "$0")/.."
device="${1:-flutter-tester}"
fail=0
for f in integration_test/*_test.dart; do
  echo "== $f ($device)"
  flutter test "$f" -d "$device" || fail=1
done
if [ "$fail" -ne 0 ]; then
  echo "GAGAL: ada integration_test yang tidak lulus."
  exit 1
fi
echo "integration_test: OK"
