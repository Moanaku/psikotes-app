"""Bagian bersama skrip pre-generate bank verbal (T07, F04).

Hanya pustaka standar Python. Pembuatan dan verifikasi soal memakai `claude -p`
(langganan, bukan API berbayar; ADR-12). Tidak ada kunci API di sini.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Callable, Iterable

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parent / "out"
BANK_PATH = ROOT / "assets" / "verbal_bank.json"
SAMPLE_PATH = ROOT / "docs" / "eval" / "verbal_sample.md"

TYPES = ("VRB-SYN", "VRB-ANA")
DIFFICULTIES = ("easy", "medium", "hard")
LABELS = "ABCDEFGH"

CMD_UNSAFE = re.compile(r'["%^&|<>]')

# runner(prompt, system) -> teks jawaban model
Runner = Callable[[str, str], str]


def claude_runner(model: str | None = None, timeout: int = 600, retries: int = 2) -> Runner:
    """Runner nyata: `claude -p` tanpa alat, tanpa sesi tersimpan, dijalankan di
    folder sementara supaya CLAUDE.md proyek tidak ikut terbaca."""

    def run(prompt: str, system: str) -> str:
        exe = shutil.which("claude")
        if exe is None:
            raise RuntimeError("perintah claude tidak ditemukan di PATH")
        # Shim .cmd/.bat hanya bisa dijalankan lewat cmd.exe; argumen harus aman.
        use_shell = exe.lower().endswith((".cmd", ".bat"))
        if use_shell and CMD_UNSAFE.search(system):
            raise ValueError('system prompt memuat karakter khusus cmd.exe (" % ^ & | < >)')
        cmd = [
            exe, "-p",
            "--output-format", "text",
            "--tools", "",
            "--no-session-persistence",
            "--system-prompt", system,
        ]
        if model:
            cmd += ["--model", model]
        last = ""
        for attempt in range(retries + 1):
            with tempfile.TemporaryDirectory() as cwd:
                proc = subprocess.run(
                    cmd, input=prompt, capture_output=True, text=True,
                    encoding="utf-8", timeout=timeout, cwd=cwd,
                    shell=use_shell,
                )
            if proc.returncode == 0 and proc.stdout.strip():
                return proc.stdout
            last = (proc.stderr or proc.stdout or "").strip()[:300]
            print(f"  claude gagal (percobaan {attempt + 1}): {last}", file=sys.stderr)
        raise RuntimeError(f"claude -p gagal berulang: {last}")

    return run


def extract_json(text: str):
    """Ambil array atau objek JSON pertama dari jawaban model (boleh berpagar kode)."""
    text = text.strip()
    fenced = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if fenced:
        text = fenced.group(1).strip()
    starts = [i for i in (text.find("["), text.find("{")) if i >= 0]
    if not starts:
        raise ValueError("tidak ada JSON di jawaban model")
    start = min(starts)
    closer = "]" if text[start] == "[" else "}"
    end = text.rfind(closer)
    if end < start:
        raise ValueError("JSON tidak lengkap")
    return json.loads(text[start:end + 1])


def norm(s: str) -> str:
    """Normalisasi untuk membandingkan teks: huruf kecil, spasi dan tanda baca ujung dibuang."""
    return re.sub(r"\s+", " ", s).strip().strip(".,;:!?\"'").lower()


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def append_jsonl(path: Path, rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_jsonl(path: Path, rows: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
