"""Pass 1: membuat kandidat soal VRB-SYN dan VRB-ANA lewat `claude -p` (T07, F04).

Contoh:
  python tool/pregenerate/gen_verbal.py --per-type 170        # perintah penuh
  python tool/pregenerate/gen_verbal.py --per-type 6 --batch 3 --out tool/pregenerate/out/smoke

Keluaran: <out>/candidates.jsonl (satu soal per baris). Boleh dijalankan ulang;
soal baru ditambahkan dan kata yang sudah dipakai dikirim ke model agar tidak berulang.
"""
from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

from common import (DIFFICULTIES, OUT_DIR, Runner, append_jsonl, claude_runner,
                    extract_json, norm, read_jsonl)
from schema import validate_item

SYSTEM = (
    "Kamu penyusun soal latihan psikotes verbal berbahasa Indonesia baku untuk "
    "pelamar kerja IT. Setiap soal pilihan ganda 4 opsi dengan TEPAT SATU jawaban "
    "benar yang tidak bisa diperdebatkan menurut KBBI. Pengecoh harus masuk akal "
    "tetapi jelas salah. Jangan menyalin soal dari penerbit tes mana pun (SHL, "
    "CCAT, Papi Kostick, soal perusahaan); buat dari kosakata umum sendiri. "
    "Jawab HANYA dengan satu array JSON, tanpa teks lain."
)

# Tingkat kesulitan VRB-SYN menurut frekuensi kata, VRB-ANA menurut jenis relasi.
SYN_LEVEL = {
    "easy": "kata sehari-hari yang sangat sering dipakai (mis. cepat, besar, mulai)",
    "medium": "kata baku yang lazim di bacaan dan kantor (mis. efisien, akurat, kendala)",
    "hard": "kata formal, serapan, atau jarang dipakai (mis. nirlaba, redundan, esensial)",
}
ANA_LEVEL = {
    "easy": "relasi sederhana: sinonim, antonim, bagian-keseluruhan, alat-fungsi umum",
    "medium": "relasi sebab-akibat, pelaku-hasil kerja, alat-pengguna, tempat-kegiatan",
    "hard": "relasi tingkatan intensitas, bahan-produk, kategori-contoh abstrak, "
            "proses-tahap, atau relasi yang dibalik di pengecoh",
}
THEMES = ("pekerjaan dan kantor", "teknologi dan perangkat", "sekolah dan belajar",
          "alam dan cuaca", "perasaan dan sikap", "ekonomi dan keuangan",
          "kesehatan dan olahraga", "kota dan transportasi", "makanan dan rumah",
          "komunikasi dan media")


def build_prompt(qtype: str, difficulty: str, mode: str, theme: str, n: int,
                 avoid: list[str]) -> str:
    avoid_txt = ", ".join(avoid[-60:]) if avoid else "(belum ada)"
    if qtype == "VRB-SYN":
        kind = "sinonim" if mode == "sinonim" else "antonim"
        stem_fmt = ('Padanan kata "KATA" adalah ...' if kind == "sinonim"
                    else 'Lawan kata "KATA" adalah ...')
        spec = (
            f"Buat {n} soal {kind.upper()} (tingkat {difficulty}: {SYN_LEVEL[difficulty]}). "
            f"Tema kata: {theme}.\nFormat stem persis: {stem_fmt}\n"
            "Opsi berupa kata atau frasa pendek. Pengecoh = kata terkait atau mirip makna "
            "tetapi BUKAN padanan/lawan yang tepat. Kata di soal tidak boleh jadi opsi.\n"
            '"kata" = [kata yang ditanyakan].'
        )
    else:
        spec = (
            f"Buat {n} soal ANALOGI KATA (tingkat {difficulty}: {ANA_LEVEL[difficulty]}). "
            f"Tema: {theme}.\nFormat stem persis: A : B = C : ...\n"
            "Pengecoh = kata yang berelasi dengan C tetapi relasinya terbalik atau "
            "berbeda dari relasi A:B. Kata A, B, C tidak boleh jadi opsi.\n"
            '"kata" = [A, B, C]; "relasi" = nama relasi A:B (mis. alat-fungsi).'
        )
    return (
        f"{spec}\n\nHindari kata yang sudah dipakai: {avoid_txt}.\n\n"
        "Keluaran: array JSON, tiap elemen:\n"
        '{"kata": [...], "stem": "...", "options": ["...","...","...","..."], '
        '"correctIndex": 0, "explanation": "satu atau dua kalimat alasan", '
        '"relasi": "..."}\n'
        "Taruh jawaban benar di posisi bebas; correctIndex = indeks (mulai 0) jawaban benar."
    )


def shuffle_options(item: dict, rng: random.Random) -> dict:
    """Acak urutan opsi (model cenderung menaruh kunci di posisi tertentu)."""
    order = list(range(len(item["options"])))
    rng.shuffle(order)
    item["options"] = [item["options"][i] for i in order]
    item["correctIndex"] = order.index(item["correctIndex"])
    return item


def generate_batch(runner: Runner, qtype: str, difficulty: str, mode: str,
                   theme: str, n: int, avoid: list[str]) -> list[dict]:
    raw = runner(build_prompt(qtype, difficulty, mode, theme, n, avoid), SYSTEM)
    data = extract_json(raw)
    if not isinstance(data, list):
        raise ValueError("model tidak mengembalikan array")
    return [d for d in data if isinstance(d, dict)]


def next_ids(existing: list[dict]) -> dict[str, int]:
    last = {"VRB-SYN": 0, "VRB-ANA": 0}
    for c in existing:
        t, _, num = c["id"].rpartition("-")
        last[t] = max(last[t], int(num))
    return last


def run(runner: Runner, per_type: int, batch: int, out: Path, seed: int = 1) -> dict:
    """Buat `per_type` kandidat valid-bentuk per tipe, rata antar kesulitan."""
    path = out / "candidates.jsonl"
    existing = read_jsonl(path)
    counters = next_ids(existing)
    rng = random.Random(seed + len(existing))
    stats = {"diminta": 0, "ditolak_bentuk": 0, "kembar": 0, "batch_gagal": 0, "ditambah": 0}
    seen_stems = {norm(c["stem"]) for c in existing}

    for qtype in ("VRB-SYN", "VRB-ANA"):
        have = {d: sum(1 for c in existing if c["type"] == qtype and c["difficulty"] == d)
                for d in DIFFICULTIES}
        target = {d: per_type // 3 + (1 if i < per_type % 3 else 0)
                  for i, d in enumerate(DIFFICULTIES)}
        for diff in DIFFICULTIES:
            guard = 0
            while have[diff] < target[diff] and guard < 4 * (target[diff] // batch + 2):
                guard += 1
                n = min(batch, target[diff] - have[diff])
                mode = rng.choice(("sinonim", "antonim")) if qtype == "VRB-SYN" else ""
                theme = rng.choice(THEMES)
                avoid = [w for c in read_jsonl(path) if c["type"] == qtype
                         for w in c.get("kata", [])]
                stats["diminta"] += n
                print(f"{qtype} {diff} {mode or 'analogi'} / {theme}: minta {n} "
                      f"(ada {have[diff]}/{target[diff]})", flush=True)
                try:
                    items = generate_batch(runner, qtype, diff, mode, theme, n, avoid)
                except Exception as e:  # noqa: BLE001 - satu batch gagal tidak menghentikan semuanya
                    stats["batch_gagal"] += 1
                    print(f"  batch gagal: {e}", file=sys.stderr)
                    continue
                accepted = []
                for it in items:
                    counters[qtype] += 1
                    cand = {
                        "id": f"{qtype}-{counters[qtype]:04d}",
                        "type": qtype,
                        "difficulty": diff,
                        "stem": str(it.get("stem", "")).strip(),
                        "options": [str(o).strip() for o in it.get("options", [])],
                        "correctIndex": it.get("correctIndex"),
                        "explanation": str(it.get("explanation", "")).strip(),
                        "kata": [str(w).strip() for w in it.get("kata", [])],
                        "relasi": str(it.get("relasi", "")).strip(),
                        "needsReview": False,
                    }
                    if validate_item(cand, candidate=True):
                        counters[qtype] -= 1
                        stats["ditolak_bentuk"] += 1
                        continue
                    key = norm(cand["stem"])
                    if key in seen_stems:
                        counters[qtype] -= 1
                        stats["kembar"] += 1
                        continue
                    seen_stems.add(key)
                    shuffle_options(cand, rng)
                    accepted.append(cand)
                append_jsonl(path, accepted)
                have[diff] += len(accepted)
                stats["ditambah"] += len(accepted)
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--per-type", type=int, default=170,
                    help="kandidat per tipe (default 170; bundel mengambil 150 setelah verifikasi)")
    ap.add_argument("--batch", type=int, default=10, help="soal per panggilan claude")
    ap.add_argument("--model", default=None, help="mis. sonnet; kosong = bawaan claude")
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    stats = run(claude_runner(args.model), args.per_type, args.batch, args.out, args.seed)
    print("Ringkasan pass 1:", stats)
    return 0


if __name__ == "__main__":
    sys.exit(main())
