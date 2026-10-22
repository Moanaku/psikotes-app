"""Pass 2: menjawab kandidat TANPA kunci dengan prompt berbeda, lalu membuang yang tidak cocok (T07, F04).

Contoh:
  python tool/pregenerate/verify_verbal.py
  python tool/pregenerate/verify_verbal.py --out tool/pregenerate/out/smoke --batch 3

Membaca <out>/candidates.jsonl, menulis <out>/verified.jsonl (lolos) dan
<out>/dropped.jsonl (dibuang, lengkap dengan alasannya), dan <out>/verify_report.json.
Kunci jawaban tidak pernah dikirim ke model; urutan opsi diacak ulang per soal supaya
bias posisi tidak menolong. Soal dibuang bila jawaban penjawab berbeda dari kunci, atau
penjawab menyatakan ada lebih dari satu opsi yang bisa dibenarkan.
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

from common import LABELS, OUT_DIR, Runner, append_jsonl, claude_runner, extract_json, read_jsonl

SYSTEM = (
    "Kamu penjawab soal psikotes verbal berbahasa Indonesia yang teliti. Jawab hanya "
    "berdasarkan makna kata menurut KBBI dan relasi yang tampak pada soal. Kamu tidak "
    "diberi kunci. Jawab HANYA dengan satu array JSON, tanpa teks lain."
)


def build_prompt(batch: list[tuple[str, str, list[str]]]) -> str:
    lines = []
    for ref, stem, opts in batch:
        lines.append(f"[{ref}] {stem}")
        lines += [f"  {LABELS[i]}. {o}" for i, o in enumerate(opts)]
    body = "\n".join(lines)
    return (
        "Kerjakan soal berikut satu per satu. Untuk tiap soal pilih SATU opsi paling tepat. "
        "Jika ada opsi lain yang juga bisa dibenarkan secara wajar, atau tidak ada yang tepat, "
        'tandai "ambigu": true.\n\n'
        f"{body}\n\n"
        'Keluaran: array JSON, satu elemen per soal: {"ref": "...", "jawaban": "A", '
        '"ambigu": false, "alasan": "satu kalimat"}'
    )


def shuffled_view(item: dict) -> tuple[list[str], list[int]]:
    """Opsi diacak ulang; `order[i]` = indeks asli opsi yang tampil di posisi i."""
    rng = random.Random("verify:" + item["id"])
    order = list(range(len(item["options"])))
    rng.shuffle(order)
    return [item["options"][i] for i in order], order


def verify_batch(runner: Runner, items: list[dict]) -> dict[str, dict]:
    views = {it["id"]: shuffled_view(it) for it in items}
    prompt = build_prompt([(it["id"], it["stem"], views[it["id"]][0]) for it in items])
    answers = extract_json(runner(prompt, SYSTEM))
    result: dict[str, dict] = {}
    for a in answers if isinstance(answers, list) else []:
        ref = a.get("ref")
        if ref not in views:
            continue
        label = str(a.get("jawaban", "")).strip().upper()[:1]
        order = views[ref][1]
        picked = order[LABELS.index(label)] if label and label in LABELS[:len(order)] else None
        result[ref] = {"answer": picked, "ambigu": bool(a.get("ambigu")),
                       "alasan": str(a.get("alasan", ""))[:200]}
    return result


def judge(item: dict, res: dict | None) -> tuple[bool, str]:
    if res is None or res["answer"] is None:
        return False, "tidak dijawab"
    if res["ambigu"]:
        return False, "penjawab menandai ambigu"
    if res["answer"] != item["correctIndex"]:
        return False, "jawaban berbeda dari kunci"
    return True, "cocok"


def run(runner: Runner, out: Path, batch: int = 10) -> dict:
    cands = read_jsonl(out / "candidates.jsonl")
    done = {v["id"] for v in read_jsonl(out / "verified.jsonl")} | \
           {v["id"] for v in read_jsonl(out / "dropped.jsonl")}
    todo = [c for c in cands if c["id"] not in done]
    stats = {"diperiksa": 0, "lolos": 0, "dibuang": 0, "batch_gagal": 0}
    for i in range(0, len(todo), batch):
        chunk = todo[i:i + batch]
        print(f"verifikasi {i + 1}-{i + len(chunk)} dari {len(todo)}", flush=True)
        try:
            results = verify_batch(runner, chunk)
        except Exception as e:  # noqa: BLE001
            stats["batch_gagal"] += 1
            print(f"  batch gagal: {e}", file=sys.stderr)
            continue  # tidak ditulis; dijalankan ulang akan mencoba lagi
        ok_rows, bad_rows = [], []
        for it in chunk:
            ok, why = judge(it, results.get(it["id"]))
            row = dict(it, verify={"agree": ok, "alasan": why,
                                   "penjawab": (results.get(it["id"]) or {}).get("alasan", "")})
            (ok_rows if ok else bad_rows).append(row)
        append_jsonl(out / "verified.jsonl", ok_rows)
        append_jsonl(out / "dropped.jsonl", bad_rows)
        stats["diperiksa"] += len(chunk)
        stats["lolos"] += len(ok_rows)
        stats["dibuang"] += len(bad_rows)

    verified = read_jsonl(out / "verified.jsonl")
    dropped = read_jsonl(out / "dropped.jsonl")
    report = {
        "kandidat": len(cands), "lolos": len(verified), "dibuang": len(dropped),
        "belum_diperiksa": len(cands) - len(verified) - len(dropped),
        "alasan_dibuang": {},
    }
    for d in dropped:
        why = d["verify"]["alasan"]
        report["alasan_dibuang"][why] = report["alasan_dibuang"].get(why, 0) + 1
    (out / "verify_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Laporan pass 2:", report)
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    ap.add_argument("--batch", type=int, default=10)
    ap.add_argument("--model", default=None)
    args = ap.parse_args()
    run(claude_runner(args.model), args.out, args.batch)
    return 0


if __name__ == "__main__":
    sys.exit(main())
