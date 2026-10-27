"""Pool pernyataan kepribadian Papi-style lewat `claude -p` (T22, F12).

Contoh:
  python tool/pregenerate/gen_personality.py                 # 12 pernyataan per sifat
  python tool/pregenerate/gen_personality.py --per-trait 16  # tambah sampai 16
  python tool/pregenerate/gen_personality.py --bundle-only   # tulis ulang aset dari out/

Keluaran: tool/pregenerate/out/personality.jsonl (satu pernyataan per baris),
assets/personality_pool.json, dan docs/eval/personality_sample.md. Boleh
dijalankan ulang: sifat yang sudah cukup tidak diminta lagi. Pernyataan yang
ID-nya ditulis di docs/eval/personality_flags.txt dibuang dari pool.

Aturan isi (docs/06-bank-konten.md, "Pool kepribadian"): tanpa jawaban benar
atau salah, tanpa istilah klinis, tidak menyalin item Papi Kostick atau DISC
asli. Pernyataan dibuat sama-sama wajar agar pilihan paksa tidak punya opsi
yang jelas "lebih baik".
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

from common import OUT_DIR, ROOT, Runner, append_jsonl, claude_runner, extract_json, norm, read_jsonl

POOL_PATH = ROOT / "assets" / "personality_pool.json"
SAMPLE_PATH = ROOT / "docs" / "eval" / "personality_sample.md"
FLAGS_PATH = ROOT / "docs" / "eval" / "personality_flags.txt"
RAW_PATH = OUT_DIR / "personality.jsonl"

MIN_PER_TRAIT = 10
MAX_PER_TRAIT = 20
MIN_LEN = 25
MAX_LEN = 110

# Sifat kerja yang edukatif, bukan faktor tes asli. relevansiRole: tinggi atau sedang.
TRAITS = [
    {"id": "keteraturan", "kode": "KTR", "nama": "Keteraturan dan ketelitian",
     "arti": "Kecenderungan bekerja terstruktur dan memeriksa detail sebelum selesai.",
     "relevansiRole": {"qa": "tinggi", "mobile": "sedang", "ba": "sedang"}},
    {"id": "ketekunan", "kode": "TKN", "nama": "Ketekunan",
     "arti": "Kecenderungan bertahan pada tugas sampai tuntas walau membosankan atau sulit.",
     "relevansiRole": {"qa": "tinggi", "mobile": "tinggi", "ba": "sedang"}},
    {"id": "inisiatif", "kode": "INS", "nama": "Inisiatif dan kemandirian",
     "arti": "Kecenderungan memulai sendiri, mencari jalan, dan bekerja tanpa banyak arahan.",
     "relevansiRole": {"qa": "sedang", "mobile": "tinggi", "ba": "sedang"}},
    {"id": "kerjasama", "kode": "KRS", "nama": "Kerja sama tim",
     "arti": "Kecenderungan bekerja bersama, berbagi beban, dan menjaga suasana tim.",
     "relevansiRole": {"qa": "sedang", "mobile": "sedang", "ba": "tinggi"}},
    {"id": "komunikasi", "kode": "KOM", "nama": "Komunikasi",
     "arti": "Kecenderungan menjelaskan, bertanya, dan menyampaikan pendapat dengan jelas.",
     "relevansiRole": {"qa": "sedang", "mobile": "sedang", "ba": "tinggi"}},
    {"id": "kepemimpinan", "kode": "PIM", "nama": "Mengarahkan orang lain",
     "arti": "Kecenderungan mengambil peran memimpin, membagi tugas, dan mengambil keputusan.",
     "relevansiRole": {"qa": "sedang", "mobile": "sedang", "ba": "sedang"}},
    {"id": "ketenangan", "kode": "TEN", "nama": "Tenang saat ditekan",
     "arti": "Kecenderungan tetap fokus ketika tenggat dekat, ada masalah, atau rencana berubah.",
     "relevansiRole": {"qa": "tinggi", "mobile": "sedang", "ba": "sedang"}},
    {"id": "belajar", "kode": "BLJ", "nama": "Rasa ingin tahu",
     "arti": "Kecenderungan mencari tahu cara kerja sesuatu dan mempelajari hal baru.",
     "relevansiRole": {"qa": "sedang", "mobile": "tinggi", "ba": "sedang"}},
]

# Istilah yang menyiratkan diagnosis klinis atau kondisi kesehatan jiwa.
CLINICAL = re.compile(
    r"\b(depresi|depresif|cemas|kecemasan|gangguan|diagnosis|trauma|bipolar|adhd|"
    r"autis|ocd|obsesif|kompulsif|panik|fobia|psikolog|psikiater|terapi|obat|"
    r"stres berat|mental|jiwa|insomnia|sakit)\w*",
    re.I,
)

SYSTEM = (
    "Kamu penyusun pernyataan latihan tes kepribadian kerja bergaya pilihan paksa "
    "berbahasa Indonesia baku untuk pelamar kerja IT. Tidak ada jawaban benar atau salah. "
    "Semua pernyataan harus sama-sama wajar dan positif atau netral, sehingga tidak ada "
    "yang terdengar jelas lebih baik. Jangan memakai istilah klinis, kesehatan jiwa, atau "
    "diagnosis. Jangan menyalin item Papi Kostick, DISC, atau tes resmi mana pun. "
    "Jawab HANYA dengan satu array JSON berisi string, tanpa teks lain."
)


def build_prompt(trait: dict, n: int, avoid: list[str]) -> str:
    avoid_txt = "\n".join(f"- {a}" for a in avoid[-40:]) or "(belum ada)"
    return (
        f"Sifat: {trait['nama']}. Arti: {trait['arti']}\n"
        f"Buat {n} pernyataan orang pertama yang menggambarkan sifat ini dalam situasi "
        "kerja sehari-hari (proyek, tim, tugas, belajar). Aturan:\n"
        "- satu kalimat, diawali \"Saya\", 6 sampai 16 kata, diakhiri titik;\n"
        "- perilaku yang bisa diamati, bukan penilaian diri seperti \"saya hebat\";\n"
        "- tanpa kata \"tidak\", \"jarang\", \"benar\", atau \"salah\";\n"
        "- setiap pernyataan berbeda situasinya.\n"
        f"Jangan mengulang yang sudah ada:\n{avoid_txt}"
    )


def problems(text: str) -> list[str]:
    """Pelanggaran aturan isi untuk satu pernyataan; kosong berarti lolos."""
    out = []
    t = text.strip()
    if not t.startswith("Saya "):
        out.append("tidak diawali Saya")
    if not t.endswith("."):
        out.append("tidak diakhiri titik")
    if not MIN_LEN <= len(t) <= MAX_LEN:
        out.append(f"panjang {len(t)} di luar {MIN_LEN}..{MAX_LEN}")
    if CLINICAL.search(t):
        out.append("istilah klinis")
    if re.search(r"\b(tidak|jarang|benar|salah)\b", t, re.I):
        out.append("kata negatif atau benar/salah")
    if re.search(r'["\\]', t):
        out.append("tanda kutip atau garis miring terbalik")
    return out


def generate(runner: Runner, per_trait: int, raw_path: Path = RAW_PATH) -> None:
    rows = read_jsonl(raw_path)
    for trait in TRAITS:
        mine = [r for r in rows if r["sifat"] == trait["id"]]
        tries = 0
        while len(mine) < per_trait and tries < 3:
            tries += 1
            need = per_trait - len(mine)
            reply = runner(build_prompt(trait, need + 2, [r["teks"] for r in mine]), SYSTEM)
            seen = {norm(r["teks"]) for r in rows}
            fresh = []
            for text in extract_json(reply):
                if not isinstance(text, str):
                    continue
                text = re.sub(r"\s+", " ", text).strip()
                if problems(text) or norm(text) in seen:
                    continue
                seen.add(norm(text))
                fresh.append({
                    "id": f"PER-{trait['kode']}-{len(mine) + len(fresh) + 1:03d}",
                    "sifat": trait["id"], "teks": text,
                })
                if len(mine) + len(fresh) == per_trait:
                    break
            append_jsonl(raw_path, fresh)
            rows += fresh
            mine += fresh
            print(f"{trait['id']}: {len(mine)} pernyataan", file=sys.stderr)


def read_flags(path: Path = FLAGS_PATH) -> set[str]:
    if not path.exists():
        return set()
    return {line.split("#")[0].strip() for line in path.read_text(encoding="utf-8").splitlines()
            if line.split("#")[0].strip()}


def build_pool(rows: list[dict], flags: set[str], today: str) -> dict:
    sifat = []
    for trait in TRAITS:
        items = [{"id": r["id"], "teks": r["teks"]} for r in rows
                 if r["sifat"] == trait["id"] and r["id"] not in flags]
        sifat.append({
            "id": trait["id"], "nama": trait["nama"], "arti": trait["arti"],
            "relevansiRole": trait["relevansiRole"],
            "pernyataan": items[:MAX_PER_TRAIT],
        })
    return {"versi": 1, "dibuat": today, "sifat": sifat}


def validate_pool(pool: dict) -> list[str]:
    """Pelanggaran skema dan aturan isi pool; kosong berarti sah."""
    issues = []
    if pool.get("versi") != 1:
        issues.append("versi bukan 1")
    ids, texts = set(), set()
    traits = pool.get("sifat", [])
    if len(traits) < 2:
        issues.append("kurang dari dua sifat")
    for t in traits:
        n = len(t.get("pernyataan", []))
        if not MIN_PER_TRAIT <= n <= MAX_PER_TRAIT:
            issues.append(f"{t.get('id')}: {n} pernyataan, harus {MIN_PER_TRAIT}..{MAX_PER_TRAIT}")
        for key in ("id", "nama", "arti"):
            if not str(t.get(key, "")).strip():
                issues.append(f"sifat tanpa {key}")
        for p in t.get("pernyataan", []):
            if p["id"] in ids:
                issues.append(f"ID kembar {p['id']}")
            if norm(p["teks"]) in texts:
                issues.append(f"teks kembar {p['id']}")
            ids.add(p["id"])
            texts.add(norm(p["teks"]))
            for prob in problems(p["teks"]):
                issues.append(f"{p['id']}: {prob}")
    return issues


def write_sample(pool: dict, path: Path = SAMPLE_PATH, per_trait: int = 3) -> None:
    lines = [
        "# Sampel pool kepribadian (T22)",
        "",
        f"Dibuat {pool['dibuat']} dari `assets/personality_pool.json` "
        f"({sum(len(t['pernyataan']) for t in pool['sifat'])} pernyataan, "
        f"{len(pool['sifat'])} sifat). Untuk diperiksa pemilik: nada netral, tanpa "
        "jawaban benar atau salah, tanpa istilah klinis, tidak mirip item tes resmi.",
        "Pernyataan yang meragukan: tulis ID-nya satu per baris di "
        "`docs/eval/personality_flags.txt`, lalu jalankan "
        "`python tool/pregenerate/gen_personality.py --bundle-only`.",
        "",
    ]
    for t in pool["sifat"]:
        lines.append(f"## {t['nama']} (`{t['id']}`)")
        lines.append("")
        lines.append(t["arti"])
        lines.append("")
        for p in t["pernyataan"][:per_trait]:
            lines.append(f"- `{p['id']}` {p['teks']}")
        lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def bundle(raw_path: Path = RAW_PATH, pool_path: Path = POOL_PATH,
           sample_path: Path = SAMPLE_PATH, flags_path: Path = FLAGS_PATH,
           today: str | None = None) -> dict:
    pool = build_pool(read_jsonl(raw_path), read_flags(flags_path),
                      today or datetime.date.today().isoformat())
    issues = validate_pool(pool)
    if issues:
        raise SystemExit("pool tidak sah:\n" + "\n".join(issues))
    pool_path.parent.mkdir(parents=True, exist_ok=True)
    pool_path.write_text(json.dumps(pool, ensure_ascii=False, indent=2) + "\n",
                         encoding="utf-8", newline="\n")
    write_sample(pool, sample_path)
    return pool


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--per-trait", type=int, default=12)
    ap.add_argument("--model", default=None)
    ap.add_argument("--bundle-only", action="store_true")
    args = ap.parse_args()
    if not MIN_PER_TRAIT <= args.per_trait <= MAX_PER_TRAIT:
        raise SystemExit(f"--per-trait harus {MIN_PER_TRAIT}..{MAX_PER_TRAIT}")
    if not args.bundle_only:
        generate(claude_runner(args.model), args.per_trait)
    pool = bundle()
    print(f"pool: {sum(len(t['pernyataan']) for t in pool['sifat'])} pernyataan di {POOL_PATH}")


if __name__ == "__main__":
    main()
