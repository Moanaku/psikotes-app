"""Validator skema `assets/verbal_bank.json` dan kandidat soal (docs/06-bank-konten.md).

Tanpa dependensi luar. Setiap fungsi mengembalikan daftar pesan galat; kosong = valid.
"""
from __future__ import annotations

import re

from common import DIFFICULTIES, TYPES, norm

BANK_KEYS = {"id", "type", "difficulty", "stem", "options", "correctIndex",
             "explanation", "needsReview", "passes"}
ID_RE = re.compile(r"^(VRB-SYN|VRB-ANA)-\d{4}$")
OPTION_COUNT = 4  # bank verbal v1 selalu 4 opsi


def validate_item(item: dict, *, candidate: bool = False) -> list[str]:
    """Periksa satu soal. `candidate=True` mengizinkan kolom bantu (kata, relasi)."""
    errs: list[str] = []
    ref = item.get("id", "?")

    def err(msg: str) -> None:
        errs.append(f"{ref}: {msg}")

    if not candidate:
        extra = set(item) - BANK_KEYS
        missing = BANK_KEYS - set(item)
        if extra:
            err(f"kolom tidak dikenal {sorted(extra)}")
        if missing:
            err(f"kolom hilang {sorted(missing)}")
            return errs
    if not isinstance(item.get("id"), str) or not ID_RE.match(item["id"]):
        err("id harus berbentuk VRB-SYN-0001 atau VRB-ANA-0001")
    elif not item["id"].startswith(str(item.get("type"))):
        err("id tidak cocok dengan type")
    if item.get("type") not in TYPES:
        err(f"type harus salah satu {TYPES}")
    if item.get("difficulty") not in DIFFICULTIES:
        err(f"difficulty harus salah satu {DIFFICULTIES}")

    stem = item.get("stem")
    if not isinstance(stem, str) or not stem.strip():
        err("stem kosong")
        stem = ""
    elif "..." not in stem:
        err('stem harus memuat "..." sebagai tempat jawaban')

    opts = item.get("options")
    if not isinstance(opts, list) or len(opts) != OPTION_COUNT:
        err(f"options harus berisi {OPTION_COUNT} teks")
        opts = []
    elif not all(isinstance(o, str) and o.strip() for o in opts):
        err("ada opsi kosong atau bukan teks")
        opts = []
    keys = [norm(o) for o in opts]
    if len(set(keys)) != len(keys):
        err("ada opsi kembar")

    ci = item.get("correctIndex")
    if not isinstance(ci, int) or isinstance(ci, bool) or not (0 <= ci < len(opts)):
        err("correctIndex di luar rentang options")

    ex = item.get("explanation")
    if not isinstance(ex, str) or len(ex.strip()) < 10:
        err("explanation kosong atau terlalu pendek")

    # Kata di soal tidak boleh muncul sebagai opsi.
    words = [w for w in (item.get("kata") or []) if isinstance(w, str)]
    if not words:
        words = re.findall(r'"([^"]+)"', stem)
    for w in words:
        if norm(w) in keys:
            err(f'kata soal "{w}" muncul sebagai opsi')

    if not candidate:
        if not isinstance(item.get("needsReview"), bool):
            err("needsReview harus boolean")
        elif item["needsReview"]:
            err("needsReview true tidak boleh ada di bundel")
        passes = item.get("passes")
        if not (isinstance(passes, dict) and passes.get("generate") == "pass1"
                and passes.get("verify") == "pass2-agree"):
            err('passes harus {"generate":"pass1","verify":"pass2-agree"}')
    return errs


def validate_bank(bank: dict) -> list[str]:
    errs: list[str] = []
    if not isinstance(bank.get("versi"), int):
        errs.append("versi harus bilangan bulat")
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", str(bank.get("dibuat", ""))):
        errs.append("dibuat harus YYYY-MM-DD")
    soal = bank.get("soal")
    if not isinstance(soal, list) or not soal:
        return errs + ["soal harus daftar tidak kosong"]
    seen_ids: set[str] = set()
    seen_stems: set[str] = set()
    for item in soal:
        errs += validate_item(item)
        if item.get("id") in seen_ids:
            errs.append(f"{item.get('id')}: id ganda")
        seen_ids.add(item.get("id"))
        sk = norm(str(item.get("stem", "")))
        if sk in seen_stems:
            errs.append(f"{item.get('id')}: stem ganda")
        seen_stems.add(sk)
    counts = bank.get("jumlah")
    if counts is not None:
        actual: dict[str, int] = {}
        for item in soal:
            actual[item.get("type")] = actual.get(item.get("type"), 0) + 1
        if counts != actual:
            errs.append(f"jumlah {counts} tidak cocok dengan isi {actual}")
    return errs
