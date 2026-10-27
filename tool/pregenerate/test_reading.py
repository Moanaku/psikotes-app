"""Tes gen_reading.py dengan runner palsu (tanpa memanggil claude)."""
import json
import tempfile
import unittest
from pathlib import Path

import gen_reading as gr
from common import read_jsonl

TEXT = " ".join(f"kata{i}" for i in range(80))


def passage(i: int) -> dict:
    return {
        "bacaan": f"Bacaan {i}. {TEXT}",
        "pernyataan": [
            {"teks": f"Pernyataan benar nomor {i} tentang proses itu.", "jawaban": "Benar",
             "alasan": "Tertulis jelas.", "kesulitan": gr.DIFFICULTIES[i % 3]},
            {"teks": f"Pernyataan salah nomor {i} tentang proses itu.", "jawaban": "Salah",
             "alasan": "Bertentangan dengan bacaan.", "kesulitan": gr.DIFFICULTIES[(i + 1) % 3]},
            {"teks": f"Pernyataan tak pasti nomor {i} tentang proses itu.",
             "jawaban": "Tidak dapat ditentukan", "alasan": "Tidak disebut.",
             "kesulitan": gr.DIFFICULTIES[(i + 2) % 3]},
        ],
    }


class Fake:
    def __init__(self, mode="agree", fail_after=None):
        self.n = 0
        self.calls = 0
        self.mode = mode
        self.fail_after = fail_after
        self.answers = {}

    def __call__(self, prompt, system):
        self.calls += 1
        if self.fail_after is not None and self.calls > self.fail_after:
            raise RuntimeError("kuota habis")
        if "Untuk tiap soal jawab" in prompt:
            out = []
            for block in prompt.split("Soal ")[1:]:
                qid = block.split("\n")[0].strip()
                ans = self.answers[qid]
                if self.mode == "beda" and qid.endswith("2"):
                    ans = "Benar" if ans != "Benar" else "Salah"
                out.append({"id": qid, "jawaban": ans})
            return json.dumps(out)
        want = int(prompt.split("Buat ")[1].split(" bacaan")[0])
        out = []
        for _ in range(want):
            self.n += 1
            out.append(passage(self.n))
        return json.dumps(out)


class ReadingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = Path(self.tmp.name)
        self.cand, self.ok, self.drop = d / "c.jsonl", d / "v.jsonl", d / "d.jsonl"
        self.dir = d

    def tearDown(self):
        self.tmp.cleanup()

    def _gen(self, n=8):
        fake = Fake()
        gr.generate(fake, passages=n, path=self.cand)
        for p in read_jsonl(self.cand):
            for q in gr.questions(p):
                fake.answers[q["qid"]] = q["jawaban"]
        return fake

    def test_problems(self):
        self.assertEqual(gr.problems(passage(1)), [])
        short = passage(1)
        short["bacaan"] = "terlalu pendek"
        self.assertTrue(any("kata" in p for p in gr.problems(short)))
        dup = passage(1)
        dup["pernyataan"][1]["jawaban"] = "Benar"
        self.assertTrue(any("masing-masing" in p for p in gr.problems(dup)))
        two = passage(1)
        two["pernyataan"].pop()
        self.assertTrue(gr.problems(two))

    def test_generate_lanjut_dan_tanpa_ulang(self):
        fake = self._gen(8)
        self.assertEqual(len(read_jsonl(self.cand)), 8)
        before = fake.calls
        gr.generate(fake, passages=8, path=self.cand)
        self.assertEqual(fake.calls, before)

    def test_kuota_habis_menyimpan_sebagian(self):
        with self.assertRaises(gr.QuotaExhausted):
            gr.generate(Fake(fail_after=1), passages=8, path=self.cand)
        self.assertEqual(len(read_jsonl(self.cand)), 4)

    def test_verify_pengujian_tidak_melihat_kunci_dan_beda_gugur(self):
        fake = self._gen(8)
        seen = []
        orig = fake.__call__

        def spy(prompt, system):
            seen.append(prompt)
            return orig(prompt, system)

        fake.mode = "beda"
        gr.verify(spy, self.cand, self.ok, self.drop)
        text = "\n".join(seen)
        self.assertNotIn("Tertulis jelas", text)
        self.assertNotIn("alasan", text)
        bad = read_jsonl(self.drop)
        self.assertTrue(bad)
        self.assertEqual(len(bad) + len(read_jsonl(self.ok)), 24)

    def test_bundle_seimbang_dan_flag_dibuang(self):
        fake = self._gen(16)
        gr.verify(fake, self.cand, self.ok, self.drop)
        verified = read_jsonl(self.ok)
        bank = gr.build_bank(verified, set(), "2026-10-27", target=30)
        self.assertEqual(gr.validate(bank), [])
        self.assertEqual(len(bank["soal"]), 30)
        for d in gr.DIFFICULTIES:
            self.assertEqual(sum(1 for s in bank["soal"] if s["difficulty"] == d), 10)
        keys = {s["options"][s["correctIndex"]] for s in bank["soal"]}
        self.assertEqual(keys, set(gr.LABELS))
        flag = bank["soal"][0]["passes"]["kandidat"]
        again = gr.build_bank(verified, {flag}, "2026-10-27", target=30)
        self.assertNotIn(flag, [s["passes"]["kandidat"] for s in again["soal"]])
        self.assertEqual(len(again["soal"]), 30)
        self.assertEqual(again["jumlah"], {"VRB-RC": 30})

    def test_stem_memuat_bacaan_dan_pernyataan(self):
        fake = self._gen(4)
        gr.verify(fake, self.cand, self.ok, self.drop)
        bank = gr.build_bank(read_jsonl(self.ok), set(), "2026-10-27", target=6)
        for s in bank["soal"]:
            self.assertIn("Pernyataan:", s["stem"])
            self.assertEqual(s["options"], gr.LABELS)
            self.assertFalse(s["needsReview"])

    def test_main_kuota_habis_kode_3(self):
        self.assertEqual(gr.main(["generate"], runner=Fake(fail_after=0)), 3)


if __name__ == "__main__":
    unittest.main()
