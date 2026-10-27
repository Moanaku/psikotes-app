"""Bank bacaan VRB-RC lewat `claude -p` (T26, F04).

  python tool/pregenerate/gen_reading.py all        # pass 1, pass 2, bundle
  python tool/pregenerate/gen_reading.py generate   # atau satu tahap saja
  python tool/pregenerate/gen_reading.py verify
  python tool/pregenerate/gen_reading.py bundle

Setiap bacaan fiktif (70 sampai 140 kata, tema tempat kerja IT) punya tiga
pernyataan: satu Benar, satu Salah, satu Tidak dapat ditentukan. Pass 2 hanya
melihat bacaan dan pernyataan (tanpa kunci) dan harus memilih jawaban yang
sama. Satu pernyataan menjadi satu soal VRB-RC; stem memuat bacaan dan
pernyataan, opsi selalu Benar, Salah, Tidak dapat ditentukan (urutan tetap).

Keluaran bundel: assets/reading_bank.json dengan skema soal yang sama dengan
assets/verbal_bank.json (tipe VRB-RC). Belum dipakai app (pemuat bank verbal
hanya mengenal VRB-SYN dan VRB-ANA); file ini disiapkan untuk tugas yang
menyambungkan tipe Bacaan ke sesi.

Batas jujur: kedua pass memakai model yang sama; lolos berarti sepakat. Sampel
10% di docs/eval/reading_sample.md diperiksa pemilik; id meragukan ditulis di
docs/eval/reading_flags.txt lalu `bundle` dijalankan lagi.
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

from common import OUT_DIR, ROOT, Runner, append_jsonl, claude_runner, extract_json, norm, read_jsonl

BANK_PATH = ROOT / "assets" / "reading_bank.json"
SAMPLE_PATH = ROOT / "docs" / "eval" / "reading_sample.md"
FLAGS_PATH = ROOT / "docs" / "eval" / "reading_flags.txt"
CANDIDATES = OUT_DIR / "reading_candidates.jsonl"
VERIFIED = OUT_DIR / "reading_verified.jsonl"
DROPPED = OUT_DIR / "reading_dropped.jsonl"
REPORT = OUT_DIR / "reading_report.json"

LABELS = ["Benar", "Salah", "Tidak dapat ditentukan"]
DIFFICULTIES = ("easy", "medium", "hard")
PASSAGES = 16          # bacaan kandidat (tiga soal per bacaan)
PER_CALL = 4
VERIFY_BATCH = 12
TARGET = 30            # soal di bank: 10 per kesulitan

THEMES = [
    "tim kecil merilis fitur baru aplikasi pemesanan", "migrasi data pelanggan ke sistem baru",
    "jadwal pengujian sebelum rilis", "kebijakan cadangan data harian",
    "rapat peninjauan kode mingguan", "program pelatihan untuk pengembang baru",
    "penanganan keluhan pengguna aplikasi", "pemilihan alat pelacak tugas oleh tim",
    "pemadaman server terjadwal pada akhir pekan", "perubahan alur persetujuan cuti di aplikasi internal",
    "audit keamanan kata sandi", "dokumentasi API untuk mitra",
    "rencana kerja jarak jauh bagi tim teknologi", "pengurangan waktu muat halaman",
    "pembagian tugas dalam proyek aplikasi seluler", "evaluasi vendor layanan awan",
]

SYSTEM_GEN = (
    "Kamu penyusun soal latihan pemahaman bacaan berbahasa Indonesia untuk pelamar kerja IT. "
    "Bacaan harus fiktif, netral, dan berdiri sendiri: jawaban hanya boleh bergantung pada isi bacaan, "
    "bukan pengetahuan di luar bacaan. Jangan menyalin soal dari SHL, CCAT, buku, atau tes perusahaan "
    "mana pun, dan jangan memakai nama perusahaan sungguhan. "
    "Jawab HANYA dengan satu array JSON, tanpa teks lain."
)

SYSTEM_VERIFY = (
    "Kamu peserta tes pemahaman bacaan yang teliti. Untuk setiap bacaan dan pernyataan, pilih tepat satu: "
    "Benar bila bacaan menyatakannya secara jelas atau pasti menyiratkannya, Salah bila bacaan "
    "bertentangan dengannya, Tidak dapat ditentukan bila bacaan tidak cukup untuk memutuskan. "
    "Gunakan hanya isi bacaan. Jawab HANYA dengan satu array JSON, tanpa teks lain."
)


def build_gen_prompt(themes: list[str], start: int) -> str:
    listed = "\n".join(f"{i}. {t}" for i, t in enumerate(themes, 1))
    return (
        f"Buat {len(themes)} bacaan, satu per tema berikut, berurutan:\n{listed}\n\n"
        "Setiap bacaan adalah objek JSON dengan kunci:\n"
        "- bacaan: 70 sampai 140 kata, beberapa kalimat, memuat fakta konkret (urutan, jumlah, aturan, alasan);\n"
        "- pernyataan: tepat tiga objek {teks, jawaban, alasan, kesulitan}, satu untuk setiap jawaban "
        "\"Benar\", \"Salah\", dan \"Tidak dapat ditentukan\" (urutan acak);\n"
        "  - teks: satu kalimat pernyataan, paling banyak 25 kata;\n"
        "  - alasan: satu kalimat yang menunjuk bagian bacaan atau menjelaskan mengapa tidak cukup informasi;\n"
        "  - kesulitan: \"easy\" (jelas tertulis), \"medium\" (perlu menyimpulkan atau membandingkan), "
        "\"hard\" (jebakan halus, misalnya kata semua, selalu, atau hanya, atau hal yang terasa wajar tetapi tidak tertulis).\n"
        "Sebarkan kesulitan: dari seluruh pernyataan, kira-kira sepertiga easy, sepertiga medium, sepertiga hard. "
        "Pernyataan Tidak dapat ditentukan harus benar-benar tidak bisa dipastikan dari bacaan."
    )


def problems(p: dict) -> list[str]:
    out = []
    text = str(p.get("bacaan", "")).strip()
    words = len(text.split())
    if not 60 <= words <= 160:
        out.append(f"bacaan {words} kata, harus 60..160")
    st = p.get("pernyataan")
    if not isinstance(st, list) or len(st) != 3:
        return out + ["pernyataan harus tepat 3"]
    if sorted(str(s.get("jawaban")) for s in st if isinstance(s, dict)) != sorted(LABELS):
        out.append("jawaban harus Benar, Salah, dan Tidak dapat ditentukan masing-masing sekali")
    for s in st:
        if not isinstance(s, dict):
            out.append("pernyataan bukan objek")
            continue
        t = str(s.get("teks", "")).strip()
        if not 5 <= len(t.split()) <= 30:
            out.append("teks pernyataan harus 5..30 kata")
        if not str(s.get("alasan", "")).strip():
            out.append("alasan kosong")
        if s.get("kesulitan") not in DIFFICULTIES:
            out.append("kesulitan tidak dikenal")
        if norm(t) in norm(text):
            out.append("pernyataan menyalin kalimat bacaan")
    return out


class QuotaExhausted(Exception):
    pass


def call(runner: Runner, prompt: str, system: str) -> str:
    try:
        return runner(prompt, system)
    except RuntimeError as e:
        raise QuotaExhausted(str(e)) from e


def generate(runner: Runner, passages: int = PASSAGES, path: Path = CANDIDATES) -> None:
    rows = read_jsonl(path)
    themes = THEMES[:passages]
    todo = [t for t in themes if t not in {r["tema"] for r in rows}]
    for i in range(0, len(todo), PER_CALL):
        chunk = todo[i:i + PER_CALL]
        reply = call(runner, build_gen_prompt(chunk, len(rows) + 1), SYSTEM_GEN)
        try:
            parsed = extract_json(reply)
        except ValueError:
            continue
        fresh = []
        for tema, p in zip(chunk, parsed if isinstance(parsed, list) else []):
            if not isinstance(p, dict) or problems(p):
                continue
            n = len(rows) + len(fresh) + 1
            fresh.append({"id": f"RC{n:03d}", "tema": tema, "bacaan": p["bacaan"].strip(),
                          "pernyataan": [{"teks": s["teks"].strip(), "jawaban": s["jawaban"],
                                          "alasan": s["alasan"].strip(), "kesulitan": s["kesulitan"]}
                                         for s in p["pernyataan"]]})
        append_jsonl(path, fresh)
        rows += fresh
        print(f"bacaan: {len(rows)}", file=sys.stderr)


def questions(passage: dict) -> list[dict]:
    """Tiga soal dari satu bacaan, id lokal RCnnn-k."""
    return [{"qid": f"{passage['id']}-{k}", "bacaan": passage["bacaan"], **s}
            for k, s in enumerate(passage["pernyataan"], 1)]


def build_verify_prompt(batch: list[dict]) -> str:
    parts = ["Untuk tiap soal jawab dengan objek {\"id\": ..., \"jawaban\": \"Benar\" atau \"Salah\" atau "
             "\"Tidak dapat ditentukan\"}.\n"]
    for q in batch:
        parts += [f"Soal {q['qid']}", f"Bacaan: {q['bacaan']}", f"Pernyataan: {q['teks']}", ""]
    return "\n".join(parts)


def verify(runner: Runner, cand_path: Path = CANDIDATES, ok_path: Path = VERIFIED,
           drop_path: Path = DROPPED) -> None:
    done = {r["qid"] for r in read_jsonl(ok_path)} | {r["qid"] for r in read_jsonl(drop_path)}
    todo = [q for p in read_jsonl(cand_path) for q in questions(p) if q["qid"] not in done]
    for i in range(0, len(todo), VERIFY_BATCH):
        batch = todo[i:i + VERIFY_BATCH]
        reply = call(runner, build_verify_prompt(batch), SYSTEM_VERIFY)
        try:
            parsed = extract_json(reply)
        except ValueError:
            parsed = []
        by_id = {v.get("id"): v for v in parsed if isinstance(v, dict)}
        ok, bad = [], []
        for q in batch:
            v = by_id.get(q["qid"])
            if v is None:
                continue
            agree = str(v.get("jawaban", "")).strip().lower() == q["jawaban"].lower()
            (ok if agree else bad).append({**q, "verifikasi": "sepakat" if agree else
                                           f"penguji menjawab {v.get('jawaban')}"})
        append_jsonl(ok_path, ok)
        append_jsonl(drop_path, bad)
        print(f"verifikasi {i + len(batch)}/{len(todo)}: lolos {len(ok)}, gugur {len(bad)}",
              file=sys.stderr)


def read_flags(path: Path = FLAGS_PATH) -> set[str]:
    if not path.exists():
        return set()
    return {ln.split("#")[0].strip() for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.split("#")[0].strip()}


def pick(rows: list[dict], target: int) -> list[dict]:
    """target soal, sepertiga per kesulitan, tiap jawaban dan bacaan merata."""
    per = {d: target // len(DIFFICULTIES) for d in DIFFICULTIES}
    chosen: list[dict] = []
    for d in DIFFICULTIES:
        pool = sorted((r for r in rows if r["kesulitan"] == d), key=lambda r: r["qid"])
        by_label: dict[str, list[dict]] = {}
        for r in pool:
            by_label.setdefault(r["jawaban"], []).append(r)
        taken: list[dict] = []
        while len(taken) < per[d] and any(by_label.values()):
            for lst in by_label.values():
                if lst and len(taken) < per[d]:
                    taken.append(lst.pop(0))
        chosen += taken
    return sorted(chosen, key=lambda r: r["qid"])


def to_soal(r: dict, number: int) -> dict:
    return {
        "id": f"VRB-RC-{number:04d}", "type": "VRB-RC", "difficulty": r["kesulitan"],
        "stem": f"{r['bacaan']}\n\nPernyataan: {r['teks']}",
        "options": list(LABELS), "correctIndex": LABELS.index(r["jawaban"]),
        "explanation": r["alasan"], "needsReview": False,
        "passes": {"generate": "pass1", "verify": "pass2-agree", "kandidat": r["qid"]},
    }


def build_bank(verified: list[dict], flags: set[str], today: str, target: int = TARGET) -> dict:
    rows = [r for r in verified if r["qid"] not in flags]
    soal = [to_soal(r, i) for i, r in enumerate(pick(rows, target), 1)]
    return {"versi": 1, "dibuat": today, "jumlah": {"VRB-RC": len(soal)}, "soal": soal}


def validate(bank: dict) -> list[str]:
    issues, ids, stems = [], set(), set()
    for s in bank.get("soal", []):
        if s["id"] in ids:
            issues.append(f"{s['id']}: id kembar")
        ids.add(s["id"])
        if s["stem"] in stems:
            issues.append(f"{s['id']}: stem kembar")
        stems.add(s["stem"])
        if s["options"] != LABELS or not 0 <= s["correctIndex"] < len(LABELS):
            issues.append(f"{s['id']}: opsi atau kunci salah")
        if s["needsReview"] is not False or not s["explanation"].strip():
            issues.append(f"{s['id']}: needsReview atau penjelasan salah")
        if not re.fullmatch(r"VRB-RC-\d{4,}", s["id"]):
            issues.append(f"{s['id']}: format id")
    return issues


def write_sample(bank: dict, path: Path = SAMPLE_PATH) -> int:
    items = bank["soal"]
    k = max(1, round(len(items) * 0.1))
    step = max(1, len(items) // k)
    chosen = items[::step][:k]
    lines = ["# Sampel bank bacaan VRB-RC (T26)", "",
             f"Dibuat {bank['dibuat']}: {len(chosen)} dari {len(items)} soal (sekitar 10%). "
             "Periksa apakah kuncinya benar menurut bacaan saja. Id yang meragukan ditulis di "
             "`docs/eval/reading_flags.txt` (pakai kode kandidat di judul, mis. RC003-2), lalu jalankan "
             "`python tool/pregenerate/gen_reading.py bundle`.", ""]
    for s in chosen:
        lines += [f"## {s['id']} ({s['difficulty']}, kandidat {s['passes']['kandidat']})", "",
                  s["stem"], "",
                  f"**Kunci:** {s['options'][s['correctIndex']]}", "",
                  f"**Alasan:** {s['explanation']}", ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return len(chosen)


def bundle(today: str | None = None, target: int = TARGET, bank_path: Path = BANK_PATH,
           sample_path: Path = SAMPLE_PATH, ok_path: Path = VERIFIED) -> dict:
    today = today or datetime.date.today().isoformat()
    bank = build_bank(read_jsonl(ok_path), read_flags(), today, target)
    issues = validate(bank)
    if issues:
        raise SystemExit("bank tidak sah:\n" + "\n".join(issues[:20]))
    bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n",
                         encoding="utf-8", newline="\n")
    n = write_sample(bank, sample_path)
    per_diff = {d: sum(1 for s in bank["soal"] if s["difficulty"] == d) for d in DIFFICULTIES}
    per_key = {l: sum(1 for s in bank["soal"] if s["options"][s["correctIndex"]] == l) for l in LABELS}
    report = {"soal": len(bank["soal"]), "target": target, "kurang": max(0, target - len(bank["soal"])),
              "kesulitan": per_diff, "kunci": per_key, "sampel": n}
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main(argv: list[str] | None = None, runner: Runner | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("step", choices=["generate", "verify", "bundle", "all"])
    ap.add_argument("--passages", type=int, default=PASSAGES)
    ap.add_argument("--model", default=None)
    args = ap.parse_args(argv)
    runner = runner or claude_runner(model=args.model)
    try:
        if args.step in ("generate", "all"):
            generate(runner, args.passages)
        if args.step in ("verify", "all"):
            verify(runner)
    except QuotaExhausted as e:
        print(f"\nBerhenti: {e}\nYang sudah jadi tersimpan di {OUT_DIR}.\n"
              f"Lanjutkan nanti dengan: python tool/pregenerate/gen_reading.py {args.step}",
              file=sys.stderr)
        return 3
    if args.step in ("bundle", "all"):
        print(json.dumps(bundle(), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
