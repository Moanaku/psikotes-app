"""Bank pengetahuan role lewat `claude -p` (T26, F17).

Tiga tahap, masing-masing bisa dijalankan ulang tanpa mengulang pekerjaan:

  python tool/pregenerate/gen_knowledge.py generate   # pass 1: kandidat per role, level, topik
  python tool/pregenerate/gen_knowledge.py verify     # pass 2: penguji tanpa melihat kunci
  python tool/pregenerate/gen_knowledge.py bundle     # tulis assets/knowledge_bank.json dan sampel

Atau semuanya: `python tool/pregenerate/gen_knowledge.py all`.

Pass 2 tidak melihat jawaban model maupun poin kunci. Penguji hanya menerima
pertanyaan dan daftar pernyataan yang diacak: poin kunci asli bercampur dengan
dua pernyataan keliru yang dibuat pass 1. Butir lolos bila semua poin asli
dinilai benar, semua pernyataan keliru dinilai salah, dan penguji tidak
menandai masalah (ambigu, fakta keliru, terlalu spesifik versi).

Batas jujur: kedua pass memakai model yang sama, jadi lolos berarti sepakat,
bukan terbukti benar. Karena itu SEMUA butir bertanda needsVerification: true
dan sumber hanya berisi nama dokumen rujukan umum dari daftar putih
(tanpa halaman, bab, URL, atau tahun) yang belum dicocokkan dengan teks
aslinya. Pemilik memeriksa sampel di docs/eval/knowledge_sample.md; id yang
meragukan ditulis di docs/eval/knowledge_flags.txt lalu `bundle` dijalankan lagi.

Bila kuota langganan habis di tengah jalan, skrip berhenti dengan kode 3 dan
menulis perintah untuk melanjutkan; yang sudah jadi tersimpan di out/.
"""
from __future__ import annotations

import argparse
import datetime
import json
import random
import re
import sys
from pathlib import Path

from common import OUT_DIR, ROOT, Runner, append_jsonl, claude_runner, extract_json, norm, read_jsonl

BANK_PATH = ROOT / "assets" / "knowledge_bank.json"
SAMPLE_PATH = ROOT / "docs" / "eval" / "knowledge_sample.md"
FLAGS_PATH = ROOT / "docs" / "eval" / "knowledge_flags.txt"
CANDIDATES = OUT_DIR / "knowledge_candidates.jsonl"
VERIFIED = OUT_DIR / "knowledge_verified.jsonl"
DROPPED = OUT_DIR / "knowledge_dropped.jsonl"
REPORT = OUT_DIR / "knowledge_report.json"

PER_COMBO = 20          # butir per role dan level di bank (target awal)
OVERSHOOT = 1.35        # kandidat berlebih untuk menutup yang gugur di pass 2
MAX_BATCH = 9           # butir per panggilan pass 1
VERIFY_BATCH = 10       # butir per panggilan pass 2

ROLE_CODE = {"qa": "QA", "mobile": "MOB", "ba": "BA"}
ROLE_NAME = {"qa": "QA Engineer", "mobile": "Mobile atau App Developer",
             "ba": "IT Business Analyst"}
LEVEL_CODE = {"dasar": "D", "menengah": "M", "lanjut": "L"}
LEVEL_HINT = {
    "dasar": "pertanyaan konsep dasar untuk pemula; jawaban singkat",
    "menengah": "pertanyaan penerapan dan perbandingan untuk praktisi dengan pengalaman satu sampai dua tahun",
    "lanjut": "pertanyaan skenario dan pertimbangan untuk praktisi senior; jawaban berupa argumen dengan beberapa poin",
}

# (role, level) -> [(slug topik, uraian topik)]. Dari docs/06-bank-konten.md.
PLAN: dict[tuple[str, str], list[tuple[str, str]]] = {
    ("qa", "dasar"): [
        ("test-case", "perbedaan test case dan test scenario, isi test case yang baik"),
        ("severity-priority", "perbedaan severity dan priority serta contoh kombinasinya"),
    ],
    ("qa", "menengah"): [
        ("boundary-value", "boundary value analysis dan equivalence partitioning"),
        ("siklus-bug", "siklus hidup bug dari ditemukan sampai ditutup, laporan bug yang baik"),
        ("pengujian-api", "pengujian API: status code, validasi respons, kasus negatif"),
    ],
    ("qa", "lanjut"): [
        ("strategi-tes", "menyusun strategi tes: risiko, cakupan, piramida tes"),
        ("flaky-test", "penyebab dan penanganan flaky test"),
        ("ci", "pengujian dalam pipeline CI: tahapan, kecepatan, kegagalan"),
        ("analisis-skenario", "mencari bug dari sebuah skenario fitur yang diberikan"),
    ],
    ("mobile", "dasar"): [
        ("siklus-hidup-layar", "siklus hidup layar atau halaman pada aplikasi mobile"),
        ("state", "state dan perubahannya pada tampilan"),
        ("layout", "dasar layout: ukuran layar, orientasi, penyusunan widget atau view"),
    ],
    ("mobile", "menengah"): [
        ("arsitektur-mvvm", "pemisahan tampilan dan logika (MVVM atau setara)"),
        ("async", "pekerjaan asinkron: future, coroutine, thread utama"),
        ("penyimpanan-lokal", "penyimpanan data lokal: preferensi, database, migrasi"),
    ],
    ("mobile", "lanjut"): [
        ("performa", "performa tampilan dan startup aplikasi"),
        ("kebocoran-memori", "kebocoran memori: penyebab umum dan cara melacak"),
        ("desain-offline-first", "desain aplikasi offline-first: sinkronisasi dan konflik data"),
    ],
    ("ba", "dasar"): [
        ("requirement", "jenis requirement dan ciri requirement yang baik"),
        ("user-story", "menulis user story dan kriteria penerimaan"),
        ("use-case", "use case: aktor, alur utama, alur alternatif"),
    ],
    ("ba", "menengah"): [
        ("bpmn", "notasi proses bisnis BPMN dasar"),
        ("prioritisasi", "teknik prioritisasi requirement"),
        ("uat", "user acceptance test dan peran analis"),
    ],
    ("ba", "lanjut"): [
        ("analisis-dampak", "analisis dampak perubahan requirement"),
        ("trade-off", "menimbang trade-off antar solusi dan pemangku kepentingan"),
        ("kasus-end-to-end", "kasus dari awal sampai akhir: dari masalah bisnis sampai solusi"),
    ],
}

# Dokumen rujukan umum yang boleh disebut. Tanpa halaman, bab, URL, atau tahun.
SOURCES = {
    "qa": ["ISTQB Foundation Level Syllabus", "ISTQB Glossary"],
    "mobile": ["Dokumentasi Android Developers", "Dokumentasi Flutter",
               "Dokumentasi Apple Developer"],
    "ba": ["BABOK Guide (IIBA)", "Spesifikasi BPMN (OMG)", "Agile Alliance Glossary"],
}

# Karakter yang merusak argumen cmd.exe dilarang di prompt sistem.
SYSTEM_GEN = (
    "Kamu penyusun kartu latihan pengetahuan kerja untuk pelamar posisi IT berbahasa Indonesia. "
    "Setiap kartu berisi satu pertanyaan wawancara teknis, jawaban model, poin kunci, dan dua "
    "pernyataan keliru yang masuk akal. Tulis hanya hal yang kamu yakin benar dan berlaku luas. "
    "Jangan menulis angka versi, tahun, tanggal, statistik, nama perusahaan, atau nomor halaman. "
    "Jangan menyalin soal dari buku, kursus, bank soal, atau tes perusahaan mana pun. "
    "Jawab HANYA dengan satu array JSON, tanpa teks lain."
)

SYSTEM_VERIFY = (
    "Kamu penguji teknis yang teliti. Untuk setiap pertanyaan kamu menilai beberapa pernyataan: "
    "benar bila sebuah jawaban yang baik pasti mendukung pernyataan itu, salah bila pernyataan itu "
    "keliru atau menyesatkan. Kamu tidak diberi jawaban resmi. Tandai masalah pada pertanyaan bila "
    "pertanyaannya ambigu, ada fakta yang keliru, atau jawabannya bergantung pada versi atau alat "
    "tertentu. Jawab HANYA dengan satu array JSON, tanpa teks lain."
)

YEAR = re.compile(r"\b(19|20)\d{2}\b")
VERSION = re.compile(r"\bv?\d+\.\d+(\.\d+)?\b")


def combos():
    for (role, level), topics in PLAN.items():
        yield role, level, topics


def item_id(role: str, level: str, n: int) -> str:
    return f"KB-{ROLE_CODE[role]}-{LEVEL_CODE[level]}-{n:03d}"


def build_gen_prompt(role: str, level: str, slug: str, desc: str, n: int, avoid: list[str]) -> str:
    sources = ", ".join(SOURCES[role])
    avoid_txt = "\n".join(f"- {a}" for a in avoid[-30:]) or "(belum ada)"
    return (
        f"Peran: {ROLE_NAME[role]}. Level: {level} ({LEVEL_HINT[level]}).\n"
        f"Topik: {slug} ({desc}).\n"
        f"Buat {n} kartu berbeda. Setiap kartu adalah objek JSON dengan kunci:\n"
        "- pertanyaan: satu kalimat tanya, diakhiri tanda tanya;\n"
        "- jawabanModel: 2 sampai 4 kalimat yang merangkum poin kunci;\n"
        "- poinKunci: 3 sampai 5 kalimat pendek, masing-masing satu gagasan benar yang harus ada "
        "di jawaban yang baik;\n"
        "- poinKeliru: tepat 2 kalimat pendek yang terdengar masuk akal tetapi keliru untuk "
        "pertanyaan itu;\n"
        f"- sumber: salah satu dari [{sources}] hanya bila dokumen itu memang membahas konsepnya, "
        "selain itu null. Jangan menulis halaman, bab, URL, atau tahun.\n"
        "Tidak ada angka versi, tahun, atau statistik. Pertanyaan harus punya jawaban yang tidak "
        "bergantung pada satu alat atau versi.\n"
        f"Jangan mengulang pertanyaan yang sudah ada:\n{avoid_txt}"
    )


def problems(c: dict, role: str) -> list[str]:
    """Pelanggaran aturan isi satu kandidat; kosong berarti lolos."""
    out = []
    q = str(c.get("pertanyaan", "")).strip()
    if not (15 <= len(q) <= 220) or not q.endswith("?"):
        out.append("pertanyaan harus 15..220 karakter dan berakhir tanda tanya")
    a = str(c.get("jawabanModel", "")).strip()
    if not 40 <= len(a) <= 700:
        out.append("jawabanModel harus 40..700 karakter")
    pk = c.get("poinKunci")
    pw = c.get("poinKeliru")
    if not isinstance(pk, list) or not 3 <= len(pk) <= 5:
        out.append("poinKunci harus 3..5")
        pk = []
    if not isinstance(pw, list) or len(pw) != 2:
        out.append("poinKeliru harus tepat 2")
        pw = []
    for s in [*pk, *pw]:
        if not isinstance(s, str) or not 10 <= len(s.strip()) <= 160:
            out.append("pernyataan harus 10..160 karakter")
    stmts = [norm(s) for s in [*pk, *pw] if isinstance(s, str)]
    if len(set(stmts)) != len(stmts):
        out.append("pernyataan kembar")
    src = c.get("sumber")
    if src is not None and src not in SOURCES[role]:
        out.append("sumber di luar daftar putih")
    blob = " ".join(str(x) for x in [q, a, *pk, *pw])
    if YEAR.search(blob) or VERSION.search(blob):
        out.append("memuat tahun atau angka versi")
    if re.search(r'["\\]', blob):
        out.append("tanda kutip atau garis miring terbalik")
    return out


class QuotaExhausted(Exception):
    pass


def call(runner: Runner, prompt: str, system: str) -> str:
    try:
        return runner(prompt, system)
    except RuntimeError as e:
        raise QuotaExhausted(str(e)) from e


def generate(runner: Runner, per_combo: int = PER_COMBO, path: Path = CANDIDATES) -> None:
    want = int(per_combo * OVERSHOOT + 0.999)
    rows = read_jsonl(path)
    for role, level, topics in combos():
        mine = [r for r in rows if r["role"] == role and r["level"] == level]
        per_topic = -(-want // len(topics))
        for slug, desc in topics:
            have = [r for r in mine if r["topik"] == slug]
            tries = 0
            while len(have) < per_topic and tries < 3:
                tries += 1
                n = min(MAX_BATCH, per_topic - len(have) + 1)
                reply = call(
                    runner,
                    build_gen_prompt(role, level, slug, desc, n, [r["pertanyaan"] for r in have]),
                    SYSTEM_GEN,
                )
                seen = {norm(r["pertanyaan"]) for r in rows}
                fresh = []
                try:
                    parsed = extract_json(reply)
                except ValueError:
                    continue
                for c in parsed if isinstance(parsed, list) else []:
                    if not isinstance(c, dict) or problems(c, role):
                        continue
                    if norm(c["pertanyaan"]) in seen:
                        continue
                    seen.add(norm(c["pertanyaan"]))
                    fresh.append({
                        "id": item_id(role, level, len(mine) + len(fresh) + 1),
                        "role": role, "level": level, "topik": slug,
                        "pertanyaan": c["pertanyaan"].strip(),
                        "jawabanModel": c["jawabanModel"].strip(),
                        "poinKunci": [s.strip() for s in c["poinKunci"]],
                        "poinKeliru": [s.strip() for s in c["poinKeliru"]],
                        "sumber": c.get("sumber"),
                    })
                    if len(have) + len(fresh) >= per_topic:
                        break
                append_jsonl(path, fresh)
                rows += fresh
                mine += fresh
                have += fresh
                print(f"{role} {level} {slug}: {len(have)}/{per_topic}", file=sys.stderr)


def shuffled_statements(c: dict) -> list[tuple[str, bool]]:
    """Pernyataan untuk penguji, diacak deterministik menurut id. True = poin asli."""
    items = [(s, True) for s in c["poinKunci"]] + [(s, False) for s in c["poinKeliru"]]
    random.Random(c["id"]).shuffle(items)
    return items


def build_verify_prompt(batch: list[dict]) -> str:
    parts = ["Nilai setiap pernyataan di bawah. Untuk tiap kartu jawab dengan objek "
             "{\"id\": ..., \"nilai\": [\"benar\" atau \"salah\" untuk tiap pernyataan, berurutan], "
             "\"masalah\": null atau \"ambigu\" atau \"fakta-keliru\" atau \"spesifik-versi\"}.\n"]
    for c in batch:
        parts.append(f"Kartu {c['id']}\nPertanyaan: {c['pertanyaan']}")
        for i, (s, _) in enumerate(shuffled_statements(c), 1):
            parts.append(f"{i}. {s}")
        parts.append("")
    return "\n".join(parts)


def judge(c: dict, verdict: dict) -> tuple[bool, str]:
    """Apakah penilaian penguji sepakat dengan poin asli dan pernyataan keliru."""
    stmts = shuffled_statements(c)
    nilai = verdict.get("nilai")
    if not isinstance(nilai, list) or len(nilai) != len(stmts):
        return False, "jumlah nilai tidak cocok"
    if verdict.get("masalah") not in (None, "null", ""):
        return False, f"masalah: {verdict.get('masalah')}"
    for (s, original), v in zip(stmts, nilai):
        want = "benar" if original else "salah"
        if str(v).strip().lower() != want:
            return False, f"pernyataan {'asli' if original else 'keliru'} dinilai {v}"
    return True, "sepakat"


def verify(runner: Runner, cand_path: Path = CANDIDATES, ok_path: Path = VERIFIED,
           drop_path: Path = DROPPED) -> None:
    done = {r["id"] for r in read_jsonl(ok_path)} | {r["id"] for r in read_jsonl(drop_path)}
    todo = [c for c in read_jsonl(cand_path) if c["id"] not in done]
    for i in range(0, len(todo), VERIFY_BATCH):
        batch = todo[i:i + VERIFY_BATCH]
        reply = call(runner, build_verify_prompt(batch), SYSTEM_VERIFY)
        try:
            parsed = extract_json(reply)
        except ValueError:
            parsed = []
        by_id = {v.get("id"): v for v in parsed if isinstance(v, dict)}
        ok, bad = [], []
        for c in batch:
            v = by_id.get(c["id"])
            if v is None:
                continue  # tidak dijawab: dicoba lagi pada putaran berikutnya
            agree, why = judge(c, v)
            (ok if agree else bad).append({**c, "verifikasi": why})
        append_jsonl(ok_path, ok)
        append_jsonl(drop_path, bad)
        print(f"verifikasi {i + len(batch)}/{len(todo)}: lolos {len(ok)}, gugur {len(bad)}",
              file=sys.stderr)


def read_flags(path: Path = FLAGS_PATH) -> set[str]:
    if not path.exists():
        return set()
    return {ln.split("#")[0].strip() for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.split("#")[0].strip()}


def pick(rows: list[dict], n: int) -> list[dict]:
    """n butir bergiliran antar topik, urut id di dalam topik."""
    by_topic: dict[str, list[dict]] = {}
    for r in sorted(rows, key=lambda r: r["id"]):
        by_topic.setdefault(r["topik"], []).append(r)
    out: list[dict] = []
    while len(out) < n and any(by_topic.values()):
        for lst in by_topic.values():
            if lst and len(out) < n:
                out.append(lst.pop(0))
    return sorted(out, key=lambda r: r["id"])


def to_bank_item(r: dict) -> dict:
    return {
        "id": r["id"], "role": r["role"], "level": r["level"], "topik": r["topik"],
        "pertanyaan": r["pertanyaan"], "jawabanModel": r["jawabanModel"],
        "poinKunci": r["poinKunci"], "sumber": r.get("sumber"),
        # Tidak ada butir yang diperiksa terhadap teks rujukan aslinya.
        "needsVerification": True,
    }


def build_bank(verified: list[dict], flags: set[str], today: str,
               per_combo: int = PER_COMBO) -> tuple[dict, dict]:
    items, report = [], {}
    for role, level, _ in combos():
        pool = [r for r in verified if r["role"] == role and r["level"] == level
                and r["id"] not in flags]
        chosen = pick(pool, per_combo)
        items += [to_bank_item(r) for r in chosen]
        per_topic: dict[str, int] = {}
        for r in chosen:
            per_topic[r["topik"]] = per_topic.get(r["topik"], 0) + 1
        report[f"{role}/{level}"] = {"butir": len(chosen), "target": per_combo,
                                     "kurang": max(0, per_combo - len(chosen)),
                                     "topik": per_topic}
    bank = {"versi": 1, "dibuat": today, "butir": items}
    return bank, report


def validate(bank: dict) -> list[str]:
    """Pelanggaran skema bank; sama dengan aturan KnowledgeBank.parse di app."""
    issues, seen_ids, seen_q = [], set(), set()
    pat = re.compile(r"^KB-(QA|MOB|BA|UM)-([DML])-(\d{3,})$")
    roles = {"QA": "qa", "MOB": "mobile", "BA": "ba", "UM": "umum"}
    levels = {"D": "dasar", "M": "menengah", "L": "lanjut"}
    for b in bank.get("butir", []):
        m = pat.match(b.get("id", ""))
        if not m or roles[m.group(1)] != b.get("role") or levels[m.group(2)] != b.get("level"):
            issues.append(f"{b.get('id')}: id tidak cocok dengan role dan level")
        if b["id"] in seen_ids:
            issues.append(f"{b['id']}: id kembar")
        seen_ids.add(b["id"])
        if norm(b["pertanyaan"]) in seen_q:
            issues.append(f"{b['id']}: pertanyaan kembar")
        seen_q.add(norm(b["pertanyaan"]))
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", b.get("topik", "")):
            issues.append(f"{b['id']}: topik bukan slug")
        if not 2 <= len(b.get("poinKunci", [])) <= 8:
            issues.append(f"{b['id']}: poinKunci harus 2..8")
        if b.get("sumber") is None and b.get("needsVerification") is not True:
            issues.append(f"{b['id']}: tanpa sumber wajib needsVerification true")
    return issues


def write_sample(bank: dict, path: Path = SAMPLE_PATH) -> int:
    items = bank["butir"]
    k = max(1, round(len(items) * 0.1))
    step = max(1, len(items) // k)
    chosen = items[::step][:k]
    lines = [
        "# Sampel bank pengetahuan role (T26)",
        "",
        f"Dibuat {bank['dibuat']} dari `assets/knowledge_bank.json`: {len(chosen)} dari "
        f"{len(items)} butir (sekitar 10%), tersebar di semua role dan level.",
        "",
        "Periksa tiap butir: apakah pertanyaan jelas, jawaban model dan poin kunci benar dan "
        "tidak bergantung pada alat tertentu, dan rujukan masuk akal. Butir yang meragukan: "
        "tulis id-nya satu per baris di `docs/eval/knowledge_flags.txt`, lalu jalankan "
        "`python tool/pregenerate/gen_knowledge.py bundle`. Butir bertanda dibuang dari bank dan "
        "diganti kandidat lolos lain.",
        "",
        "Semua butir bertanda perlu verifikasi: dua pass dilakukan oleh model yang sama, dan "
        "rujukan belum dicocokkan dengan teks aslinya.",
        "",
    ]
    for b in chosen:
        lines += [
            f"## {b['id']} ({b['topik']})",
            "",
            f"**Pertanyaan:** {b['pertanyaan']}",
            "",
            f"**Jawaban model:** {b['jawabanModel']}",
            "",
            "**Poin kunci:**",
            *[f"- {p}" for p in b["poinKunci"]],
            "",
            f"**Rujukan:** {b['sumber'] or 'tidak ada'}",
            "",
        ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return len(chosen)


def bundle(today: str | None = None, per_combo: int = PER_COMBO, bank_path: Path = BANK_PATH,
           sample_path: Path = SAMPLE_PATH, ok_path: Path = VERIFIED,
           check_only: bool = False) -> dict:
    today = today or datetime.date.today().isoformat()
    bank, report = build_bank(read_jsonl(ok_path), read_flags(), today, per_combo)
    issues = validate(bank)
    if issues:
        raise SystemExit("bank tidak sah:\n" + "\n".join(issues[:20]))
    if not check_only:
        bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8", newline="\n")
        report["sampel"] = write_sample(bank, sample_path)
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    report["total"] = len(bank["butir"])
    report["perluVerifikasi"] = sum(1 for b in bank["butir"] if b["needsVerification"])
    return report


def main(argv: list[str] | None = None, runner: Runner | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("step", choices=["generate", "verify", "bundle", "all"])
    ap.add_argument("--per-combo", type=int, default=PER_COMBO)
    ap.add_argument("--model", default=None)
    args = ap.parse_args(argv)
    runner = runner or claude_runner(model=args.model)
    try:
        if args.step in ("generate", "all"):
            generate(runner, args.per_combo)
        if args.step in ("verify", "all"):
            verify(runner)
    except QuotaExhausted as e:
        print(f"\nBerhenti: {e}\nYang sudah jadi tersimpan di {OUT_DIR}.\n"
              "Lanjutkan nanti dengan perintah yang sama:\n"
              f"  python tool/pregenerate/gen_knowledge.py {args.step}", file=sys.stderr)
        return 3
    if args.step in ("bundle", "all"):
        rep = bundle(per_combo=args.per_combo)
        print(json.dumps(rep, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
