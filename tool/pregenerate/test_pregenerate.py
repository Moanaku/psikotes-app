"""Tes skrip pre-generate dengan runner palsu (tanpa memanggil claude).

Jalankan: python -m unittest discover -s tool/pregenerate -p "test_*.py"
"""
from __future__ import annotations

import datetime
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bundle  # noqa: E402
import gen_verbal  # noqa: E402
import verify_verbal  # noqa: E402
from common import extract_json, read_jsonl  # noqa: E402
from schema import validate_bank, validate_item  # noqa: E402

WORDS = ["cepat", "besar", "mulai", "rajin", "tenang", "kuat", "jujur", "ramah", "bijak", "hemat",
         "tekun", "sabar", "lincah", "murah", "tajam", "ringan", "lebar", "tinggi", "dalam", "halus"]


def make_item(i: int, qtype: str = "VRB-SYN", diff: str = "easy", **over) -> dict:
    word = WORDS[i % len(WORDS)] + str(i)
    item = {
        "id": f"{qtype}-{i:04d}", "type": qtype, "difficulty": diff,
        "stem": f'Padanan kata "{word}" adalah ...',
        "options": [f"benar{i}", f"salah{i}a", f"salah{i}b", f"salah{i}c"],
        "correctIndex": 0, "explanation": "Alasan yang cukup panjang.",
        "kata": [word], "relasi": "", "needsReview": False,
    }
    item.update(over)
    return item


def fake_generator(n_extra_bad: int = 0):
    """Runner pembuat: kunci selalu di indeks 0 sebelum diacak; dapat menyelipkan butir rusak."""
    counter = {"n": 0}

    def runner(prompt: str, system: str) -> str:
        n = int(re.search(r"Buat (\d+) soal", prompt).group(1))
        out = []
        for _ in range(n):
            counter["n"] += 1
            k = counter["n"]
            out.append({"kata": [f"kata{k}"], "stem": f'Padanan kata "kata{k}" adalah ...',
                        "options": [f"benar{k}", f"x{k}", f"y{k}", f"z{k}"],
                        "correctIndex": 0, "explanation": "Penjelasan memadai untuk tes.",
                        "relasi": ""})
        for _ in range(n_extra_bad):
            out.append({"kata": ["dupe"], "stem": 'Padanan kata "dupe" adalah ...',
                        "options": ["a", "a", "b", "c"], "correctIndex": 0,
                        "explanation": "Opsi kembar harus ditolak."})
        return "```json\n" + json.dumps(out) + "\n```"

    return runner


def fake_answerer(truth: dict[str, int], wrong: set[str] = frozenset(), ambiguous: set[str] = frozenset(),
                  seen_prompts: list[str] | None = None):
    """Runner penjawab: tahu kunci dari `truth` HANYA untuk membalas; prompt tidak boleh memuat kunci."""
    stems = {}

    def runner(prompt: str, system: str) -> str:
        if seen_prompts is not None:
            seen_prompts.append(prompt)
        answers = []
        for m in re.finditer(r"\[(VRB-[A-Z]{3}-\d{4})\] .*?\n((?:  [A-H]\. .*\n?)+)", prompt):
            ref, opts_block = m.group(1), m.group(2)
            opts = [re.sub(r"^  [A-H]\. ", "", l) for l in opts_block.splitlines()]
            correct_text = f"benar{int(ref[-4:])}"
            idx = opts.index(correct_text)
            if ref in wrong:
                idx = (idx + 1) % len(opts)
            answers.append({"ref": ref, "jawaban": "ABCD"[idx], "ambigu": ref in ambiguous,
                            "alasan": "tes"})
        return json.dumps(answers)

    return runner


class ExtractJsonTest(unittest.TestCase):
    def test_fenced_and_plain(self):
        self.assertEqual(extract_json('teks ```json\n[{"a":1}]\n``` akhir'), [{"a": 1}])
        self.assertEqual(extract_json('Berikut:\n[{"a": 1}, {"a": 2}]'), [{"a": 1}, {"a": 2}])

    def test_no_json_raises(self):
        with self.assertRaises(ValueError):
            extract_json("tidak ada")


class SchemaTest(unittest.TestCase):
    def test_valid_candidate(self):
        self.assertEqual(validate_item(make_item(1), candidate=True), [])

    def test_rejects_duplicate_options_case_insensitive(self):
        errs = validate_item(make_item(1, options=["Aa", "aa ", "b", "c"]), candidate=True)
        self.assertTrue(any("kembar" in e for e in errs))

    def test_rejects_stem_word_as_option(self):
        item = make_item(1)
        item["options"][2] = item["kata"][0].upper()
        errs = validate_item(item, candidate=True)
        self.assertTrue(any("muncul sebagai opsi" in e for e in errs))

    def test_rejects_bad_key_and_option_count(self):
        self.assertTrue(validate_item(make_item(1, correctIndex=4), candidate=True))
        self.assertTrue(validate_item(make_item(1, correctIndex=True), candidate=True))
        self.assertTrue(validate_item(make_item(1, options=["a", "b", "c"]), candidate=True))

    def test_rejects_empty_explanation_and_missing_blank(self):
        self.assertTrue(validate_item(make_item(1, explanation=" "), candidate=True))
        self.assertTrue(validate_item(make_item(1, stem="Tanpa tempat jawaban"), candidate=True))

    def test_bank_rejects_needs_review_and_extra_keys(self):
        item = bundle.to_bank_item(make_item(1))
        bank = {"versi": 1, "dibuat": "2026-10-22", "soal": [item]}
        self.assertEqual(validate_bank(bank), [])
        bad = dict(item, needsReview=True, kata=["x"])
        errs = validate_bank({**bank, "soal": [bad]})
        self.assertTrue(any("needsReview" in e for e in errs))
        self.assertTrue(any("tidak dikenal" in e for e in errs))

    def test_bank_rejects_duplicate_id_and_stem(self):
        a = bundle.to_bank_item(make_item(1))
        errs = validate_bank({"versi": 1, "dibuat": "2026-10-22", "soal": [a, dict(a)]})
        self.assertTrue(any("id ganda" in e for e in errs))
        self.assertTrue(any("stem ganda" in e for e in errs))


    def test_bank_enforces_analogy_words_without_kata_column(self):
        item = bundle.to_bank_item(make_item(1, "VRB-ANA", stem="hujan : payung = panas : ..."))
        item["options"] = ["topi", "Payung", "x", "y"]  # opsi sama dengan kata B
        errs = validate_item(item)
        self.assertTrue(any("muncul sebagai opsi" in e for e in errs), errs)
        item["options"] = ["topi", "mantel", "x", "y"]
        self.assertEqual(validate_item(item), [])


class RunnerTest(unittest.TestCase):
    def test_cmd_shim_rejects_shell_metacharacters(self):
        import shutil
        from unittest import mock
        import common
        with mock.patch.object(shutil, "which", return_value="C:/x/claude.cmd"):
            with self.assertRaises(ValueError):
                common.claude_runner()("p", 'sistem "berkutip"')

    def test_missing_claude_is_clear_error(self):
        import shutil
        from unittest import mock
        import common
        with mock.patch.object(shutil, "which", return_value=None):
            with self.assertRaises(RuntimeError):
                common.claude_runner()("p", "s")


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.out = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def test_generate_balances_difficulty_and_keeps_key_after_shuffle(self):
        stats = gen_verbal.run(fake_generator(n_extra_bad=1), per_type=6, batch=3, out=self.out)
        cands = read_jsonl(self.out / "candidates.jsonl")
        self.assertEqual(len(cands), 12)
        self.assertGreater(stats["ditolak_bentuk"], 0)
        for t in ("VRB-SYN", "VRB-ANA"):
            for d in ("easy", "medium", "hard"):
                self.assertEqual(sum(1 for c in cands if c["type"] == t and c["difficulty"] == d), 2)
        for c in cands:
            self.assertTrue(c["options"][c["correctIndex"]].startswith("benar"))
        positions = {c["correctIndex"] for c in cands}
        self.assertGreater(len(positions), 1, "kunci harus tersebar setelah diacak")

    def test_generate_resumes_without_duplicate_ids(self):
        gen_verbal.run(fake_generator(), per_type=3, batch=3, out=self.out)
        gen_verbal.run(fake_generator(), per_type=6, batch=3, out=self.out)
        ids = [c["id"] for c in read_jsonl(self.out / "candidates.jsonl")]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ids), 12)

    def test_verify_drops_wrong_and_ambiguous_and_hides_key(self):
        gen_verbal.run(fake_generator(), per_type=6, batch=6, out=self.out)
        cands = read_jsonl(self.out / "candidates.jsonl")
        wrong, amb = {cands[0]["id"]}, {cands[1]["id"]}
        seen: list[str] = []
        # Penjawab palsu menebak "benarN" dari ID; samakan angka teks opsi dengan nomor ID.
        for c in cands:
            n = int(c["id"][-4:])
            c["options"] = [o.replace(o, f"benar{n}") if o.startswith("benar") else o for o in c["options"]]
        (self.out / "candidates.jsonl").write_text(
            "\n".join(json.dumps(c, ensure_ascii=False) for c in cands) + "\n", encoding="utf-8")
        verify_verbal.run(fake_answerer({}, wrong, amb, seen), self.out, batch=4)
        ok = {v["id"] for v in read_jsonl(self.out / "verified.jsonl")}
        dropped = {v["id"]: v["verify"]["alasan"] for v in read_jsonl(self.out / "dropped.jsonl")}
        self.assertEqual(set(dropped), wrong | amb)
        self.assertEqual(len(ok), 10)
        self.assertEqual(dropped[cands[0]["id"]], "jawaban berbeda dari kunci")
        self.assertEqual(dropped[cands[1]["id"]], "penjawab menandai ambigu")
        for p in seen:
            self.assertNotIn("correctIndex", p)
            self.assertNotIn("explanation", p)
        # Rerun tidak memeriksa ulang.
        before = len(seen)
        verify_verbal.run(fake_answerer({}, wrong, amb, seen), self.out, batch=4)
        self.assertEqual(len(seen), before)

    def test_verify_leaves_unanswered_for_retry_instead_of_dropping(self):
        gen_verbal.run(fake_generator(), per_type=6, batch=6, out=self.out)
        cands = read_jsonl(self.out / "candidates.jsonl")
        for c in cands:
            n = int(c["id"][-4:])
            c["options"] = [f"benar{n}" if o.startswith("benar") else o for o in c["options"]]
        (self.out / "candidates.jsonl").write_text(
            "\n".join(json.dumps(c, ensure_ascii=False) for c in cands) + "\n", encoding="utf-8")
        inner = fake_answerer({})

        def truncated(prompt: str, system: str) -> str:
            answers = json.loads(inner(prompt, system))
            return json.dumps(answers[:-2])  # dua jawaban terakhir hilang

        stats = verify_verbal.run(truncated, self.out, batch=6)
        self.assertEqual(stats["tidak_dijawab"], 4)
        self.assertEqual(len(read_jsonl(self.out / "dropped.jsonl")), 0)
        verify_verbal.run(inner, self.out, batch=6)
        self.assertEqual(len(read_jsonl(self.out / "verified.jsonl")), 12)

    def _write_verified(self, items):
        rows = [dict(i, verify={"agree": True, "alasan": "cocok", "penjawab": ""}) for i in items]
        (self.out / "verified.jsonl").write_text(
            "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n", encoding="utf-8")

    def _items(self, per_cell):
        items, n = [], 0
        for t in ("VRB-SYN", "VRB-ANA"):
            for d in ("easy", "medium", "hard"):
                for _ in range(per_cell):
                    n += 1
                    items.append(make_item(n, t, d))
        return items

    def test_bundle_selects_balanced_validates_and_writes_sample(self):
        self._write_verified(self._items(4))
        bank_p, sample_p = self.out / "bank.json", self.out / "sample.md"
        rc = bundle.build(self.out, bank_p, sample_p, per_type=6, sample_n=6,
                          flags_path=self.out / "none.txt", today=datetime.date(2026, 10, 22))
        self.assertEqual(rc, 0)
        bank = json.loads(bank_p.read_text(encoding="utf-8"))
        self.assertEqual(bank["jumlah"], {"VRB-SYN": 6, "VRB-ANA": 6})
        self.assertEqual(bank["dibuat"], "2026-10-22")
        self.assertEqual(validate_bank(bank), [])
        self.assertEqual(bundle.check(bank_p), 0)
        self.assertEqual(sample_p.read_text(encoding="utf-8").count("\n## "), 6)

    def test_bundle_drops_flagged_and_fills_replacement(self):
        items = self._items(4)
        self._write_verified(items)
        flagged = items[0]["id"]
        flags = self.out / "flags.txt"
        flags.write_text(f"# catatan\n{flagged}  # ragu\n", encoding="utf-8")
        rc = bundle.build(self.out, self.out / "bank.json", self.out / "s.md", per_type=6,
                          sample_n=6, flags_path=flags)
        self.assertEqual(rc, 0)
        bank = json.loads((self.out / "bank.json").read_text(encoding="utf-8"))
        self.assertNotIn(flagged, {i["id"] for i in bank["soal"]})
        self.assertEqual(bank["jumlah"]["VRB-SYN"], 6)
        self.assertEqual([r["id"] for r in read_jsonl(self.out / "needs_review.jsonl")], [flagged])

    def test_bundle_fails_on_shortfall_unless_partial(self):
        self._write_verified(self._items(1))
        args = (self.out, self.out / "bank.json", self.out / "s.md", 6, 4)
        self.assertEqual(bundle.build(*args, flags_path=self.out / "none.txt"), 1)
        self.assertFalse((self.out / "bank.json").exists())
        self.assertEqual(bundle.build(*args, flags_path=self.out / "none.txt", allow_partial=True), 0)

    def test_bundle_skips_duplicate_target_word(self):
        a, b = make_item(1), make_item(2)
        b["kata"] = a["kata"]
        b["stem"] = 'Lawan kata "x" adalah ...'
        self._write_verified([a, b])
        chosen, report = bundle.select(read_jsonl(self.out / "verified.jsonl"), set(), 6)
        self.assertEqual(len(chosen), 1)
        self.assertEqual(report["kembar_dibuang"], 1)


if __name__ == "__main__":
    unittest.main()
