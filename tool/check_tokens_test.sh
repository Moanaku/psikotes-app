#!/usr/bin/env bash
# Menguji tool/check_tokens.sh dengan contoh kode yang harus gagal dan yang harus lolos.
# Bug pemeriksa ditambahkan di sini dulu sebagai kasus baru, baru diperbaiki.
set -u
cd "$(dirname "$0")/.."
CHECK="$(pwd)/tool/check_tokens.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

# run_case <expect: fail|pass> <nama> <isi berkas widget> [path berkas, default lib/widget.dart]
run_case() {
  local expect="$1" name="$2" body="$3" file="${4:-lib/widget.dart}"
  local root="$work/case"
  rm -rf "$root"
  mkdir -p "$root/lib/core/theme" "$(dirname "$root/$file")"
  : >"$root/lib/core/theme/app_tokens.dart"
  printf 'name: contoh\n' >"$root/pubspec.yaml"
  printf '%s\n' "$body" >"$root/$file"
  local out rc
  out=$(CHECK_TOKENS_ROOT="$root" bash "$CHECK" 2>&1)
  rc=$?
  if [ "$expect" = fail ] && [ "$rc" -ne 0 ] && grep -q "GAGAL" <<<"$out"; then
    echo "ok    gagal sesuai harapan: $name"
  elif [ "$expect" = pass ] && [ "$rc" -eq 0 ]; then
    echo "ok    lolos sesuai harapan: $name"
  else
    echo "SALAH $name (harapan $expect, keluar $rc)"
    echo "$out" | sed 's/^/      /'
    failures=$((failures + 1))
  fi
}

# ---- harus gagal ----
run_case fail "hex mentah" "final a = Color(0xFF112233);"
run_case fail "Color.fromARGB" "final a = Color.fromARGB(255, 1, 2, 3);"
run_case fail "Color.fromRGBO" "final a = Color.fromRGBO(1, 2, 3, 1);"
run_case fail "Colors.red" "final a = Colors.red;"
run_case fail "fromSeed" "final a = ColorScheme.fromSeed(seedColor: x);"
run_case fail "gradien" "final a = LinearGradient(colors: x);"
run_case fail "font Roboto" "final a = TextStyle(fontFamily: 'Roboto');"
run_case fail "jarak satu baris" "final a = EdgeInsets.all(5);"
run_case fail "jarak SizedBox" "final a = SizedBox(height: 6);"
run_case fail "jarak beberapa baris (hasil dart format)" "final a = const EdgeInsets.symmetric(
  horizontal: 10,
  vertical: AppSpace.s8,
);"
run_case fail "jarak campur token dan angka" "final a = EdgeInsets.only(left: AppSpace.s8 + 2);"
run_case fail "BoxConstraints di luar skala" "final a = BoxConstraints(minHeight: 40);"
run_case fail "radius literal" "final a = BorderRadius.circular(6);"
run_case fail "ukuran teks literal" "final a = TextStyle(fontSize: 15);"
run_case fail "durasi literal" "final a = AnimatedContainer(duration: Duration(milliseconds: 300));"
run_case fail "kurva literal" "final a = AnimatedContainer(curve: Curves.easeIn);"
run_case fail "Opacity" "final a = Opacity(opacity: 0.5, child: x);"
run_case fail "withOpacity" "final a = c.withOpacity(0.5);"
run_case fail "bayangan" "final a = BoxDecoration(boxShadow: [BoxShadow()]);"
run_case fail "elevasi" "final a = Material(elevation: 2);"
run_case fail "ikon rounded" "final a = Icons.home_rounded;"
run_case fail "emoji" "final a = Text('Selesai 🎉');"
run_case fail "panah di teks" "final a = Text('Lanjut →');"
run_case fail "Oops" "final a = Text('Oops, terjadi kesalahan');"
run_case fail "Submit" "final a = Text('Submit');"
run_case fail "exception mentah" "final a = Text('Gagal: \$e');"
run_case fail "exception toString" "final a = Text(error.toString());"
printf 'name: x\nflutter:\n  fonts:\n    - family: Roboto\n' >"$work/pubspec_bad.yaml"
(
  root="$work/pub"
  mkdir -p "$root/lib/core/theme"
  : >"$root/lib/core/theme/app_tokens.dart"
  cp "$work/pubspec_bad.yaml" "$root/pubspec.yaml"
  if CHECK_TOKENS_ROOT="$root" bash "$CHECK" >/dev/null 2>&1; then
    echo "SALAH pubspec dengan font Roboto lolos"
    exit 1
  fi
  echo "ok    gagal sesuai harapan: pubspec dengan font Roboto"
) || failures=$((failures + 1))

# ---- harus lolos ----
run_case pass "komentar berisi pelanggaran" "// Colors.red, Color(0xFF000000), EdgeInsets.all(5)
/// Opacity(0.5) dan 'Oops'
final a = 1;"
run_case pass "Colors.transparent" "final a = Colors.transparent;"
run_case pass "jarak dari token" "final a = EdgeInsets.symmetric(
  horizontal: AppSpace.s16,
  vertical: 12,
);"
run_case pass "SizedBox 56 dan 48 ke atas" "final a = SizedBox(width: 56, height: AppSizes.touchTarget);"
run_case pass "radius dari token dan skala" "final a = [BorderRadius.circular(AppRadius.md), BorderRadius.circular(8), Radius.circular(AppRadius.full)];"
run_case pass "elevasi nol" "final a = Material(elevation: 0);"
run_case pass "URL di string tidak dianggap komentar" "final a = Text('Lihat https://contoh.id dan pelajari polanya');"
run_case pass "teks galat untuk pengguna" "final a = Text('Backup tidak bisa dibaca. Pilih berkas lain.');"
run_case pass "berkas token boleh berisi nilai mentah" "final a = Color(0xFF112233);
final d = Duration(milliseconds: 150);
final c = Curves.easeOut;" lib/core/theme/app_tokens.dart

if [ "$failures" -ne 0 ]; then
  echo
  echo "check_tokens_test: $failures kasus salah"
  exit 1
fi
echo
echo "check_tokens_test: semua kasus sesuai"
