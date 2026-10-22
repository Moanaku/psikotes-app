#!/usr/bin/env bash
# Membuat ulang golden di Linux dengan versi Flutter yang dipin di CI (ADR-13).
# Di Windows memakai WSL; di Linux berjalan langsung. Hasil ditulis ke test/core/goldens.
# Penggunaan: bash tool/update_goldens.sh             membuat ulang golden
#             bash tool/update_goldens.sh --verify    hanya memeriksa golden di Linux, tanpa menimpa
set -eu
cd "$(dirname "$0")/.."

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    command -v wsl >/dev/null 2>&1 || { echo "GAGAL: WSL tidak ditemukan. Pasang WSL (Ubuntu) atau jalankan skrip ini di Linux."; exit 1; }
    repo_win="$(pwd -W)"
    repo_wsl="$(MSYS_NO_PATHCONV=1 wsl wslpath -a "$repo_win" | tr -d '\r')"
    MSYS_NO_PATHCONV=1 wsl bash "$repo_wsl/tool/update_goldens_linux.sh" "$repo_wsl" "$@"
    ;;
  *)
    bash tool/update_goldens_linux.sh "$(pwd)" "$@"
    ;;
esac
