#!/usr/bin/env python3
"""Pemeriksaan aturan UI yang perlu membaca kode lintas baris.

Dipanggil oleh tool/check_tokens.sh. Membaca seluruh isi berkas, bukan baris demi baris,
karena `dart format` memecah EdgeInsets dan sejenisnya ke beberapa baris.
Penggunaan: check_tokens_scan.py ROOT   (memindai ROOT/lib)
Keluar 1 bila ada pelanggaran.
"""
import re
import sys
from pathlib import Path

SPACING_OK = {0, 4, 8, 12, 16, 24, 32, 48}
RADIUS_OK = {0, 4, 8, 12, 999}
TOKENS_FILE = "core/theme/app_tokens.dart"

# Bentuk (nama konstruktor) yang argumennya dicek terhadap skala jarak.
SPACING_CALLS = re.compile(
    r"(?:EdgeInsets\.(?:all|symmetric|only|fromLTRB)|EdgeInsetsDirectional\.\w+"
    r"|SizedBox(?:\.square)?|BoxConstraints)\s*\("
)
RADIUS_CALLS = re.compile(r"(?:BorderRadius|Radius)\.circular\s*\(")
NUMBER = re.compile(r"(?<![A-Za-z_.\d])(\d+(?:\.\d+)?)(?![\d.]*[A-Za-z_])")
IDENT_REF = re.compile(r"\b(?:AppSpace|AppSizes|AppRadius)\.\w+")
EMOJI = re.compile("[←-⇿☀-➿⭐⭕\U0001f000-\U0001faff]")
BANNED_COPY = re.compile(
    r"""['"][^'"\n]*\b(?:Oops|Something went wrong|No data|Submit)\b[^'"\n]*['"]"""
)
RAW_EXCEPTION = re.compile(
    r"""Text\(\s*(?:['"][^'"\n]*\$\{?(?:e|ex|err|error|exception)\b|"""
    r"""(?:e|ex|err|error|exception)(?:\.toString\(\)|\.message)?\s*[,)])"""
)


def strip_comments(src: str) -> str:
    """Ganti isi komentar dengan spasi agar posisi baris tetap."""

    def blank(m: re.Match) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))

    src = re.sub(r"/\*.*?\*/", blank, src, flags=re.S)
    return re.sub(r"(?<!:)//[^\n]*", blank, src)


def balanced_args(src: str, open_idx: int) -> str:
    """Isi kurung yang dibuka di open_idx (tanpa kurung terluar)."""
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return src[open_idx + 1 : i]
    return src[open_idx + 1 :]


def line_of(src: str, idx: int) -> int:
    return src.count("\n", 0, idx) + 1


def numbers_off_scale(args: str, allowed: set, allow_big: bool) -> list:
    cleaned = IDENT_REF.sub("", args)
    bad = []
    for n in NUMBER.findall(cleaned):
        v = float(n)
        if v in allowed or (allow_big and v >= 48):
            continue
        bad.append(n)
    return bad


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    lib = root / "lib"
    findings: dict[str, list[str]] = {}

    def add(rule: str, path: Path, line: int, text: str) -> None:
        findings.setdefault(rule, []).append(f"{path.relative_to(root).as_posix()}:{line}: {text}")

    for path in sorted(lib.rglob("*.dart")):
        is_tokens = path.as_posix().endswith(TOKENS_FILE)
        src = strip_comments(path.read_text(encoding="utf-8"))
        lines = src.split("\n")

        for m in SPACING_CALLS.finditer(src):
            if m.group(0).startswith("BoxConstraints") and is_tokens:
                continue
            args = balanced_args(src, m.end() - 1)
            bad = numbers_off_scale(args, SPACING_OK, allow_big=True)
            if bad and not is_tokens:
                add("Jarak literal di luar skala 4, 8, 12, 16, 24, 32, 48; pakai AppSpace.sN atau AppSizes",
                    path, line_of(src, m.start()), f"{m.group(0).strip()}...{' '.join(bad)}")

        if is_tokens:
            continue

        for m in RADIUS_CALLS.finditer(src):
            args = balanced_args(src, m.end() - 1)
            bad = numbers_off_scale(args, RADIUS_OK, allow_big=False)
            if bad:
                add("Radius di luar 4, 8, 12 (atau bulat penuh); pakai AppRadius",
                    path, line_of(src, m.start()), f"{m.group(0).strip()}{' '.join(bad)})")

        for m in re.finditer(r"fontSize\s*:\s*\d", src):
            add("Ukuran teks literal; pakai AppType", path, line_of(src, m.start()), "fontSize")
        for m in re.finditer(r"\bduration\s*:\s*(?:const\s+)?Duration\s*\(", src):
            add("Durasi literal; pakai AppMotion.duration atau context.motion", path, line_of(src, m.start()), "duration")
        for m in re.finditer(r"\bcurve\s*:\s*Curves\.", src):
            add("Kurva literal; pakai AppMotion.curve", path, line_of(src, m.start()), "curve")
        for m in re.finditer(r"\bOpacity\s*\(|\.withOpacity\s*\(", src):
            add("Opacity dilarang; teks sekunder memakai inkMuted", path, line_of(src, m.start()), m.group(0))
        for m in re.finditer(r"BoxShadow|\bboxShadow\b|\belevation\s*:\s*[1-9]", src):
            add("Elevasi dan bayangan dilarang (elevasi 0)", path, line_of(src, m.start()), m.group(0))
        for m in re.finditer(r"Icons\.\w+_(?:rounded|sharp)\b|CupertinoIcons\.", src):
            add("Satu keluarga ikon: garis (outlined)", path, line_of(src, m.start()), m.group(0))
        for m in EMOJI.finditer(src):
            add("Emoji, panah, atau simbol dingbat di kode; pakai AppIcons", path, line_of(src, m.start()), repr(m.group(0)))
        for m in BANNED_COPY.finditer(src):
            add("Microcopy generik dilarang", path, line_of(src, m.start()), m.group(0).strip())
        for m in RAW_EXCEPTION.finditer(src):
            add("Pesan exception mentah di Text; tulis pesan untuk pengguna", path, line_of(src, m.start()), m.group(0).strip())

    for rule, items in findings.items():
        print(f"GAGAL: {rule}")
        print("\n".join(items))
        print()
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
