#!/usr/bin/env bash
# Pemeriksaan sebelum rilis. Hanya memeriksa dan mencetak; tidak mengubah repo, tidak membuat
# tag, tidak mengubah visibilitas. Perintah yang tidak bisa dibatalkan dicetak untuk dijalankan pemilik.
#
#   bash tool/rilis.sh            # tag diambil dari pubspec.yaml (v<versi>)
#   bash tool/rilis.sh v1.0.0     # tag yang diminta
#
# Keluar 0 bila semua pemeriksaan lulus, 1 bila ada yang merah.
set -u
cd "$(dirname "$0")/.."

fail=0
ok()  { echo "  [ok]    $1"; }
bad() { echo "  [MERAH] $1"; fail=1; }

version="$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -n 1)"
tag="${1:-v$version}"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
echo "Rilis: tag $tag, pubspec $version, repo ${repo:-tidak terbaca}"

echo "1. Cabang dan pohon kerja"
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "main" ]; then ok "di cabang main"; else bad "di cabang $branch, bukan main"; fi
if [ -z "$(git status --porcelain)" ]; then ok "pohon kerja bersih"; else bad "ada perubahan yang belum di-commit"; fi

echo "2. Sinkron dengan origin"
if git fetch -q origin 2>/dev/null; then
  if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    ok "HEAD sama dengan origin/main"
  else
    bad "HEAD berbeda dari origin/main (pull atau push dulu)"
  fi
else
  bad "git fetch gagal"
fi

echo "3. Versi dan tag"
if [ "${tag#v}" = "$version" ]; then ok "tag $tag cocok dengan versi pubspec $version"; else bad "tag $tag tidak cocok dengan versi pubspec $version"; fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || [ -n "$(git ls-remote --tags origin "$tag" 2>/dev/null)" ]; then
  bad "tag $tag sudah ada"
else
  ok "tag $tag belum dipakai"
fi

echo "4. Pemindaian rahasia (semua revisi, pola dan nama berkas)"
pola='AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
hits=0
while read -r chunk; do
  # shellcheck disable=SC2086
  if git grep -I -q -E "$pola" $chunk -- 2>/dev/null; then hits=1; fi
done < <(git rev-list --all | xargs -n 40 echo)
if [ "$hits" -eq 0 ]; then ok "tidak ada pola kunci atau kunci privat"; else bad "ada pola kunci di riwayat (cari dengan git grep -E)"; fi
names="$(git log --all --name-only --format= | sort -u | grep -E '\.jks$|\.keystore$|google-services|(^|/)\.env($|\.)|key\.properties$|\.pem$|id_rsa' || true)"
if [ -z "$names" ]; then ok "tidak ada .jks, keystore, google-services, .env, key.properties di riwayat"; else bad "berkas sensitif pernah ada: $names"; fi

echo "5. CI main terakhir"
ci="$(gh run list --branch main --workflow ci --limit 1 --json status,conclusion,headSha -q '.[0] | .status+" "+.conclusion+" "+.headSha' 2>/dev/null || true)"
if [ -z "$ci" ]; then
  bad "tidak bisa membaca CI (gh run list)"
else
  set -- $ci
  if [ "$1" = "completed" ] && [ "${2:-}" = "success" ]; then ok "CI main hijau"; else bad "CI main: status=$1 hasil=${2:-kosong}"; fi
  if [ "${3:-}" = "$(git rev-parse origin/main 2>/dev/null)" ]; then ok "CI itu untuk commit origin/main"; else bad "CI terakhir bukan untuk commit origin/main"; fi
fi

echo "6. Secret keystore di GitHub (hanya nama)"
have="$(gh secret list 2>/dev/null | cut -f1 || true)"
for s in KEYSTORE_BASE64 KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
  if echo "$have" | grep -qx "$s"; then ok "$s ada"; else bad "$s belum ada (lihat docs/RILIS-APK.md bagian 1 dan 2)"; fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "HASIL: MERAH. Perbaiki butir bertanda [MERAH] sebelum merilis."
else
  echo "HASIL: HIJAU. Semua pemeriksaan lulus."
fi
cat <<EOT

Langkah untuk pemilik (skrip ini tidak menjalankannya; urutan penting, jangan dijalankan sebelum semua hijau):

  # a. Jadikan repo publik (tidak mudah dibatalkan: isi dan riwayat terlihat semua orang)
  gh repo edit ${repo:-<pemilik>/<repo>} --visibility public --accept-visibility-change-consequences

  # b. Nyalakan GitHub Pages dengan sumber GitHub Actions
  gh api -X POST repos/${repo:-<pemilik>/<repo>}/pages -f build_type=workflow

  # c. Buat dan dorong tag (memicu release-apk dan pages)
  git checkout main && git pull
  git tag -a $tag -m "$tag"
  git push origin $tag

Sebelum (c): ganti "belum dirilis" di CHANGELOG.md dengan tanggal rilis lewat pull request kecil.
Bila tag salah: git push origin --delete $tag lalu git tag -d $tag.
EOT
exit "$fail"
