"""Tes gen_personality.py dengan runner palsu (tanpa memanggil claude).

Jalankan: python -m unittest discover -s tool/pregenerate -p "test_*.py"
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_personality as gp  # noqa: E402
from common import read_jsonl  # noqa: E402

VERBS = ["mencatat", "memeriksa", "menyusun", "mengulang", "membagi", "menanyakan",
         "menjelaskan", "merapikan", "mencoba", "menyiapkan", "membaca", "menguji",
         "menandai", "membandingkan", "merencanakan", "mendengarkan", "mengatur", "menulis"]


def fake_runner(bad: list[str] | None = None):
    """Mengembalikan pernyataan unik per panggilan, ditambah [bad] sekali."""
    state = {"calls": 0, "bad": list(bad or [])}

    def run(prompt: str, system: str) -> str:
        state["calls"] += 1
        assert "Jawab HANYA" in system
        trait = prompt.split(".")[0].removeprefix("Sifat: ")
        n = int(prompt.split("Buat ")[1].split(" ")[0])
        out = state["bad"] + [
            f"Saya {VERBS[i % len(VERBS)]} catatan kerja {trait.lower()} nomor {state['calls']}{i}."
            for i in range(n)
        ]
        state["bad"] = []
        return json.dumps(out, ensure_ascii=False)

    run.state = state
    return run


class ProblemsTest(unittest.TestCase):
    def test_accepts_neutral_first_person(self):
        self.assertEqual(gp.problems("Saya memeriksa ulang laporan sebelum dikirim ke tim."), [])

    def test_rejects_clinical_negative_and_format(self):
        self.assertIn("istilah klinis", gp.problems("Saya mudah cemas saat tenggat dekat sekali."))
        self.assertIn("istilah klinis", gp.problems("Saya pernah ikut terapi untuk fokus bekerja."))
        self.assertTrue(gp.problems("Saya tidak suka bekerja sendirian di kantor."))
        self.assertTrue(gp.problems("Saya selalu memilih jawaban yang benar di rapat."))
        self.assertTrue(gp.problems("Aku memeriksa ulang laporan sebelum dikirim."))
        self.assertTrue(gp.problems("Saya teliti."))
        self.assertTrue(gp.problems("Saya memeriksa ulang laporan sebelum dikirim"))


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.raw = self.tmp / "out" / "personality.jsonl"

    def paths(self):
        return dict(raw_path=self.raw, pool_path=self.tmp / "pool.json",
                    sample_path=self.tmp / "sample.md", flags_path=self.tmp / "flags.txt",
                    today="2026-10-27")

    def test_generate_fills_each_trait_and_drops_bad_lines(self):
        runner = fake_runner(bad=["Saya sering merasa depresi saat bekerja lembur.", 42])
        gp.generate(runner, per_trait=12, raw_path=self.raw)
        rows = read_jsonl(self.raw)
        self.assertEqual(len(rows), 12 * len(gp.TRAITS))
        for trait in gp.TRAITS:
            mine = [r for r in rows if r["sifat"] == trait["id"]]
            self.assertEqual([r["id"] for r in mine],
                             [f"PER-{trait['kode']}-{i:03d}" for i in range(1, 13)])
        self.assertFalse(any("depresi" in r["teks"] for r in rows))
        # Dijalankan ulang tidak meminta lagi.
        calls = runner.state["calls"]
        gp.generate(runner, per_trait=12, raw_path=self.raw)
        self.assertEqual(runner.state["calls"], calls)

    def test_bundle_writes_valid_pool_sample_and_drops_flags(self):
        gp.generate(fake_runner(), per_trait=12, raw_path=self.raw)
        (self.tmp / "flags.txt").write_text("PER-KTR-002  # kurang netral\n", encoding="utf-8")
        pool = gp.bundle(**self.paths())
        self.assertEqual(gp.validate_pool(pool), [])
        ktr = next(t for t in pool["sifat"] if t["id"] == "keteraturan")
        self.assertEqual(len(ktr["pernyataan"]), 11)
        self.assertNotIn("PER-KTR-002", [p["id"] for p in ktr["pernyataan"]])
        saved = json.loads((self.tmp / "pool.json").read_text(encoding="utf-8"))
        self.assertEqual(saved, pool)
        sample = (self.tmp / "sample.md").read_text(encoding="utf-8")
        self.assertIn("personality_flags.txt", sample)
        self.assertEqual(sample.count("- `PER-"), 3 * len(gp.TRAITS))

    def test_bundle_refuses_too_few_statements(self):
        gp.generate(fake_runner(), per_trait=10, raw_path=self.raw)
        (self.tmp / "flags.txt").write_text("PER-BLJ-001\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            gp.bundle(**self.paths())

    def test_validate_pool_catches_duplicates(self):
        gp.generate(fake_runner(), per_trait=12, raw_path=self.raw)
        pool = gp.build_pool(read_jsonl(self.raw), set(), "2026-10-27")
        dup = pool["sifat"][0]["pernyataan"][0]
        pool["sifat"][1]["pernyataan"][0] = dict(dup)
        issues = gp.validate_pool(pool)
        self.assertTrue(any("ID kembar" in i for i in issues))
        self.assertTrue(any("teks kembar" in i for i in issues))


if __name__ == "__main__":
    unittest.main()
