"""Tes gen_knowledge.py dengan runner palsu (tanpa memanggil claude)."""
import json
import tempfile
import unittest
from pathlib import Path

import gen_knowledge as gk
from common import read_jsonl


def card(i: int, **over) -> dict:
    c = {
        "pertanyaan": f"Apa yang dimaksud dengan konsep nomor {i} dalam pengujian?",
        "jawabanModel": "Konsep ini menjelaskan cara memeriksa perilaku sistem secara terstruktur.",
        "poinKunci": [f"Poin kunci pertama nomor {i}", f"Poin kunci kedua nomor {i}",
                      f"Poin kunci ketiga nomor {i}"],
        "poinKeliru": [f"Pernyataan keliru pertama nomor {i}",
                       f"Pernyataan keliru kedua nomor {i}"],
        "sumber": None,
    }
    c.update(over)
    return c


class FakeGen:
    """Menjawab pass 1 dengan kartu bernomor naik; pass 2 menilai menurut `mode`."""

    def __init__(self, mode="agree", fail_after=None):
        self.n = 0
        self.calls = 0
        self.mode = mode
        self.fail_after = fail_after

    def __call__(self, prompt: str, system: str) -> str:
        self.calls += 1
        if self.fail_after is not None and self.calls > self.fail_after:
            raise RuntimeError("kuota habis")
        if "Nilai setiap pernyataan" in prompt:
            return self._verify(prompt)
        want = int(prompt.split("Buat ")[1].split(" kartu")[0])
        out = []
        for _ in range(want):
            self.n += 1
            out.append(card(self.n))
        return "```json\n" + json.dumps(out) + "\n```"

    def _verify(self, prompt: str) -> str:
        verdicts = []
        for block in prompt.split("Kartu ")[1:]:
            cid = block.split("\n")[0].strip()
            c = next(r for r in self.cands if r["id"] == cid)
            nilai = ["benar" if orig else "salah" for _, orig in gk.shuffled_statements(c)]
            masalah = None
            if self.mode == "salah-nilai" and cid.endswith("2"):
                nilai[0] = "salah" if nilai[0] == "benar" else "benar"
            if self.mode == "masalah" and cid.endswith("3"):
                masalah = "ambigu"
            verdicts.append({"id": cid, "nilai": nilai, "masalah": masalah})
        return json.dumps(verdicts)

    cands: list = []


class ProblemsTest(unittest.TestCase):
    def test_kartu_sah_lolos(self):
        self.assertEqual(gk.problems(card(1), "qa"), [])

    def test_pelanggaran(self):
        cases = [
            ({"pertanyaan": "Bukan pertanyaan"}, "tanda tanya"),
            ({"poinKunci": ["satu poin panjang cukup", "dua poin panjang cukup"]}, "poinKunci"),
            ({"poinKeliru": ["hanya satu pernyataan keliru"]}, "poinKeliru"),
            ({"sumber": "Blog Acak"}, "daftar putih"),
            ({"jawabanModel": "Berlaku sejak 2019 di semua alat yang ada saat ini."}, "tahun"),
            ({"jawabanModel": "Gunakan alat versi 3.2 untuk semua proyek pengujian."}, "versi"),
            ({"poinKunci": ["sama persis", "sama persis", "yang lain lagi"]}, "kembar"),
            ({"poinKunci": ["pendek", "sama persis cukup", "yang lain lagi ya"]}, "pernyataan"),
        ]
        for over, needle in cases:
            probs = gk.problems(card(1, **over), "qa")
            self.assertTrue(any(needle in p for p in probs), (over, probs))

    def test_sumber_putih_diterima(self):
        self.assertEqual(gk.problems(card(1, sumber="ISTQB Glossary"), "qa"), [])
        self.assertTrue(gk.problems(card(1, sumber="ISTQB Glossary"), "mobile"))


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.cand = self.dir / "c.jsonl"
        self.ok = self.dir / "v.jsonl"
        self.drop = self.dir / "d.jsonl"

    def tearDown(self):
        self.tmp.cleanup()

    def test_generate_membuat_id_berurutan_per_role_dan_level(self):
        gk.generate(FakeGen(), per_combo=4, path=self.cand)
        rows = read_jsonl(self.cand)
        for (role, level), topics in gk.PLAN.items():
            mine = [r for r in rows if r["role"] == role and r["level"] == level]
            self.assertGreaterEqual(len(mine), 4, (role, level))
            self.assertEqual([r["id"] for r in mine],
                             [gk.item_id(role, level, i + 1) for i in range(len(mine))])
            self.assertEqual({r["topik"] for r in mine}, {t for t, _ in topics})
        self.assertEqual(len({r["pertanyaan"] for r in rows}), len(rows))

    def test_generate_dapat_dilanjutkan_tanpa_mengulang(self):
        gen = FakeGen()
        gk.generate(gen, per_combo=3, path=self.cand)
        before = gen.calls
        gk.generate(gen, per_combo=3, path=self.cand)
        self.assertEqual(gen.calls, before)

    def test_kuota_habis_menyimpan_yang_sudah_jadi_lalu_lanjut(self):
        gen = FakeGen(fail_after=3)
        with self.assertRaises(gk.QuotaExhausted):
            gk.generate(gen, per_combo=3, path=self.cand)
        saved = len(read_jsonl(self.cand))
        self.assertGreater(saved, 0)
        gen2 = FakeGen()
        gen2.n = 1000
        gk.generate(gen2, per_combo=3, path=self.cand)
        rows = read_jsonl(self.cand)
        self.assertGreater(len(rows), saved)
        self.assertEqual(len({r["id"] for r in rows}), len(rows))

    def _candidates(self, per_combo=3):
        gen = FakeGen()
        gk.generate(gen, per_combo=per_combo, path=self.cand)
        FakeGen.cands = read_jsonl(self.cand)
        return gen

    def test_verify_pengujian_tidak_melihat_kunci(self):
        self._candidates()
        seen = []

        def spy(prompt, system):
            seen.append(prompt)
            return FakeGen()(prompt, system)

        FakeGen.cands = read_jsonl(self.cand)
        gk.verify(spy, self.cand, self.ok, self.drop)
        text = "\n".join(seen)
        for r in read_jsonl(self.cand)[:5]:
            self.assertNotIn(r["jawabanModel"], text)
        self.assertNotIn("poinKunci", text)
        self.assertNotIn("poinKeliru", text)

    def test_verify_sepakat_lolos_dan_beda_gugur(self):
        self._candidates()
        gk.verify(FakeGen(mode="salah-nilai"), self.cand, self.ok, self.drop)
        ok, bad = read_jsonl(self.ok), read_jsonl(self.drop)
        self.assertEqual(len(ok) + len(bad), len(read_jsonl(self.cand)))
        self.assertTrue(bad)
        self.assertTrue(all(r["id"].endswith("2") for r in bad))
        self.assertTrue(all("dinilai" in r["verifikasi"] for r in bad))

    def test_verify_masalah_menggugurkan(self):
        self._candidates()
        gk.verify(FakeGen(mode="masalah"), self.cand, self.ok, self.drop)
        bad = read_jsonl(self.drop)
        self.assertTrue(bad)
        self.assertTrue(all("masalah" in r["verifikasi"] for r in bad))

    def test_verify_tidak_mengulang_yang_sudah_dinilai(self):
        self._candidates()
        gk.verify(FakeGen(), self.cand, self.ok, self.drop)
        gen = FakeGen()
        gk.verify(gen, self.cand, self.ok, self.drop)
        self.assertEqual(gen.calls, 0)

    def test_urutan_acak_pernyataan_deterministik(self):
        c = {"id": "KB-QA-D-001", **card(1)}
        self.assertEqual(gk.shuffled_statements(c), gk.shuffled_statements(c))
        self.assertEqual(sum(1 for _, o in gk.shuffled_statements(c) if o), 3)

    def test_bundle_skema_sah_semua_perlu_verifikasi_dan_flag_dibuang(self):
        self._candidates(per_combo=6)
        gk.verify(FakeGen(), self.cand, self.ok, self.drop)
        verified = read_jsonl(self.ok)
        bank, report = gk.build_bank(verified, set(), "2026-10-27", per_combo=5)
        self.assertEqual(gk.validate(bank), [])
        self.assertEqual(len(bank["butir"]), 5 * len(gk.PLAN))
        self.assertTrue(all(b["needsVerification"] for b in bank["butir"]))
        self.assertTrue(all(b["sumber"] is None for b in bank["butir"]))
        first = bank["butir"][0]["id"]
        bank2, _ = gk.build_bank(verified, {first}, "2026-10-27", per_combo=5)
        self.assertNotIn(first, [b["id"] for b in bank2["butir"]])
        self.assertEqual(len(bank2["butir"]), 5 * len(gk.PLAN),
                         "diganti kandidat lolos lain")
        for key in report:
            self.assertEqual(report[key]["kurang"], 0)

    def test_bundle_melaporkan_kekurangan(self):
        bank, report = gk.build_bank([], set(), "2026-10-27", per_combo=5)
        self.assertEqual(bank["butir"], [])
        self.assertEqual(report["qa/dasar"]["kurang"], 5)

    def test_pick_bergiliran_antar_topik(self):
        rows = [{"id": f"KB-QA-D-{i:03d}", "topik": "a" if i < 5 else "b"} for i in range(1, 9)]
        picked = gk.pick(rows, 4)
        self.assertEqual({r["topik"] for r in picked}, {"a", "b"})

    def test_validasi_menolak_pelanggaran(self):
        good = {"id": "KB-QA-D-001", "role": "qa", "level": "dasar", "topik": "siklus-bug",
                "pertanyaan": "Apa?", "jawabanModel": "J", "poinKunci": ["a", "b"],
                "sumber": None, "needsVerification": True}
        bank = {"versi": 1, "dibuat": "x", "butir": [good]}
        self.assertEqual(gk.validate(bank), [])
        for over in ({"role": "ba"}, {"level": "lanjut"}, {"topik": "Siklus Bug"},
                     {"poinKunci": ["a"]}, {"needsVerification": False}):
            bad = {**good, **over}
            self.assertTrue(gk.validate({"butir": [bad]}), over)
        self.assertTrue(gk.validate({"butir": [good, good]}))

    def test_sampel_sepuluh_persen_tersebar(self):
        items = [{"id": f"KB-QA-D-{i:03d}", "role": "qa", "level": "dasar", "topik": "t",
                  "pertanyaan": f"P{i}?", "jawabanModel": "J", "poinKunci": ["a", "b"],
                  "sumber": None, "needsVerification": True} for i in range(1, 181)]
        path = self.dir / "sample.md"
        n = gk.write_sample({"dibuat": "2026-10-27", "butir": items}, path)
        self.assertEqual(n, 18)
        text = path.read_text(encoding="utf-8")
        self.assertIn("KB-QA-D-001", text)
        self.assertIn("perlu verifikasi", text)

    def test_main_kuota_habis_kode_3(self):
        code = gk.main(["generate", "--per-combo", "2"], runner=FakeGen(fail_after=0))
        self.assertEqual(code, 3)


if __name__ == "__main__":
    unittest.main()
