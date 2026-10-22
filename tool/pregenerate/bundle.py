"""Langkah akhir: menyusun assets/verbal_bank.json dan sampel pemeriksaan manual (T07, F04).

Contoh:
  python tool/pregenerate/bundle.py                       # tulis bank + sampel 30 soal
  python tool/pregenerate/bundle.py --check               # hanya validasi assets/verbal_bank.json
  python tool/pregenerate/bundle.py --out tool/pregenerate/out/smoke --bank out/smoke/bank.json \
      --sample-path out/smoke/sample.md --per-type 2 --sample 4 --allow-partial

Aturan: hanya soal yang lolos pass 2 dan tidak ditandai needsReview. ID soal yang
meragukan ditulis satu per baris di docs/eval/verbal_flags.txt; bundel membuangnya
sampai pemilik memeriksanya (disimpan di <out>/needs_review.jsonl). ID dipertahankan
dari pass 1, jadi bank boleh punya celah nomor.
"""
from __future__ import annotations

import argparse
import datetime
import json
import random
import sys
from pathlib import Path

from common import (BANK_PATH, DIFFICULTIES, OUT_DIR, ROOT, SAMPLE_PATH, TYPES, LABELS,
                    norm, read_jsonl, write_jsonl)
from schema import validate_bank

FLAGS_PATH = ROOT / "docs" / "eval" / "verbal_flags.txt"
BANK_VERSION = 1


def load_flags(path: Path) -> set[str]:
    if not path.exists():
        return set()
    flags = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            flags.add(line)
    return flags


def to_bank_item(c: dict) -> dict:
    return {
        "id": c["id"], "type": c["type"], "difficulty": c["difficulty"],
        "stem": c["stem"], "options": c["options"], "correctIndex": c["correctIndex"],
        "explanation": c["explanation"], "needsReview": False,
        "passes": {"generate": "pass1", "verify": "pass2-agree"},
    }


def select(verified: list[dict], flags: set[str], per_type: int) -> tuple[list[dict], dict]:
    """Pilih `per_type` soal per tipe, rata antar kesulitan; buang bertanda, kembar, atau kata ganda."""
    report: dict = {"ditandai_dibuang": 0, "kembar_dibuang": 0, "kekurangan": {}}
    flagged = [c for c in verified if c["id"] in flags or c.get("needsReview")]
    report["ditandai_dibuang"] = len(flagged)
    pool = [c for c in verified if c["id"] not in flags and not c.get("needsReview")]
    chosen: list[dict] = []
    seen_stem: set[str] = set()
    seen_word: set[tuple[str, str]] = set()
    for qtype in TYPES:
        want = {d: per_type // 3 + (1 if i < per_type % 3 else 0)
                for i, d in enumerate(DIFFICULTIES)}
        for diff in DIFFICULTIES:
            got = 0
            for c in sorted((c for c in pool if c["type"] == qtype and c["difficulty"] == diff),
                            key=lambda c: c["id"]):
                if got >= want[diff]:
                    break
                stem_key = norm(c["stem"])
                word_key = (qtype, norm(c["kata"][0])) if qtype == "VRB-SYN" and c.get("kata") else None
                if stem_key in seen_stem or (word_key and word_key in seen_word):
                    report["kembar_dibuang"] += 1
                    continue
                seen_stem.add(stem_key)
                if word_key:
                    seen_word.add(word_key)
                chosen.append(c)
                got += 1
            if got < want[diff]:
                report["kekurangan"][f"{qtype}/{diff}"] = want[diff] - got
    return sorted(chosen, key=lambda c: c["id"]), report


def render_sample(items: list[dict], n: int, seed: int = 7) -> str:
    """Sampel n soal, seimbang tipe dan kesulitan, tetap sama untuk bank yang sama."""
    rng = random.Random(seed)
    per_cell = max(1, n // (len(TYPES) * len(DIFFICULTIES)))
    picked: list[dict] = []
    for t in TYPES:
        for d in DIFFICULTIES:
            cell = [i for i in items if i["type"] == t and i["difficulty"] == d]
            picked += rng.sample(cell, min(per_cell, len(cell)))
    rest = [i for i in items if i not in picked]
    picked += rng.sample(rest, min(n - len(picked), len(rest))) if len(picked) < n else []
    picked.sort(key=lambda i: i["id"])
    out = [
        "# Sampel pemeriksaan manual bank verbal",
        "",
        f"{len(picked)} soal dari bank ({len(items)} soal), dipilih acak tetap (seed {seed}) dan seimbang "
        "antar tipe dan kesulitan. Kunci sudah ditandai (**tebal**).",
        "",
        "Cara memeriksa: untuk tiap soal tanyakan (1) apakah kuncinya benar menurut KBBI, "
        "(2) apakah ada pengecoh yang juga bisa dibenarkan, (3) apakah pembahasan cocok. "
        "Soal yang meragukan: tulis ID-nya satu per baris di `docs/eval/verbal_flags.txt`, "
        "lalu jalankan ulang `python tool/pregenerate/bundle.py`. Soal bertanda dibuang dari "
        "bank sampai diperiksa, dan bundel mengisi penggantinya dari kandidat lolos lainnya.",
        "",
    ]
    for it in picked:
        out.append(f"## {it['id']} ({it['difficulty']})")
        out.append("")
        out.append(it["stem"])
        out.append("")
        for i, o in enumerate(it["options"]):
            text = f"**{o}**" if i == it["correctIndex"] else o
            out.append(f"- {LABELS[i]}. {text}")
        out.append("")
        out.append(f"Pembahasan: {it['explanation']}")
        out.append("")
        out.append("Hasil periksa: [ ] benar  [ ] ragu (masukkan ke verbal_flags.txt)")
        out.append("")
    return "\n".join(out)


def build(out: Path, bank_path: Path, sample_path: Path, per_type: int, sample_n: int,
          flags_path: Path = FLAGS_PATH, allow_partial: bool = False,
          today: datetime.date | None = None) -> int:
    verified = read_jsonl(out / "verified.jsonl")
    flags = load_flags(flags_path)
    chosen, report = select(verified, flags, per_type)
    items = [to_bank_item(c) for c in chosen]
    counts = {t: sum(1 for i in items if i["type"] == t) for t in TYPES}
    bank = {
        "versi": BANK_VERSION,
        "dibuat": (today or datetime.date.today()).isoformat(),
        "jumlah": counts,
        "soal": items,
    }
    errs = validate_bank(bank) if items else ["tidak ada soal lolos"]
    report.update({"terverifikasi": len(verified), "dibundel": counts, "galat_skema": errs})
    write_jsonl(out / "needs_review.jsonl", [c for c in verified if c["id"] in flags])
    (out / "bundle_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Laporan bundel:", json.dumps(report, ensure_ascii=False))
    if errs:
        print("GAGAL: skema tidak valid:", *errs[:20], sep="\n  ", file=sys.stderr)
        return 1
    if report["kekurangan"] and not allow_partial:
        print(f"GAGAL: kurang soal {report['kekurangan']}. Jalankan gen_verbal.py lagi "
              "(tambah --per-type) lalu verify_verbal.py, atau pakai --allow-partial.",
              file=sys.stderr)
        return 1
    bank_path.parent.mkdir(parents=True, exist_ok=True)
    bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sample_path.parent.mkdir(parents=True, exist_ok=True)
    sample_path.write_text(render_sample(items, sample_n) + "\n", encoding="utf-8")
    print(f"Ditulis: {bank_path} ({len(items)} soal) dan {sample_path}")
    return 0


def check(bank_path: Path) -> int:
    bank = json.loads(bank_path.read_text(encoding="utf-8"))
    errs = validate_bank(bank)
    if errs:
        print("GAGAL:", *errs[:30], sep="\n  ", file=sys.stderr)
        return 1
    print(f"OK: {bank_path} valid, {len(bank['soal'])} soal {bank.get('jumlah')}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    ap.add_argument("--bank", type=Path, default=BANK_PATH)
    ap.add_argument("--sample-path", type=Path, default=SAMPLE_PATH)
    ap.add_argument("--flags", type=Path, default=FLAGS_PATH)
    ap.add_argument("--per-type", type=int, default=150)
    ap.add_argument("--sample", type=int, default=30)
    ap.add_argument("--allow-partial", action="store_true")
    ap.add_argument("--check", action="store_true", help="hanya validasi berkas bank yang ada")
    args = ap.parse_args()
    if args.check:
        return check(args.bank)
    return build(args.out, args.bank, args.sample_path, args.per_type, args.sample,
                 args.flags, args.allow_partial)


if __name__ == "__main__":
    sys.exit(main())
