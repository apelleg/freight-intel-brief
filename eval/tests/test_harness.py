"""Unit tests for the eval harness.

Uses the stub judge so tests do not require an AI CLI.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL_DIR = HERE.parent
sys.path.insert(0, str(EVAL_DIR))

import extract  # noqa: E402
import judge  # noqa: E402
import store  # noqa: E402
import drift  # noqa: E402
import report  # noqa: E402


class ExtractTests(unittest.TestCase):
    def test_load_card_pulls_headlines_and_urls(self):
        path = extract.find_card("2026-03-18")
        b = extract.load_card(path)
        self.assertEqual(b.card_date, "2026-03-18")
        self.assertGreater(len(b.headlines), 0)
        self.assertTrue(any(h.startswith("- ") for h in b.headlines))
        self.assertGreater(len(b.source_urls), 0)
        self.assertTrue(all(u.startswith("http") for u in b.source_urls))

    def test_prior_headlines_window(self):
        prior = extract.prior_headlines("2026-03-18", days=7)
        # We have continuous cards 2026-03-11..2026-03-17 → 7 days, many headlines.
        self.assertGreater(len(prior), 10)


class JudgeTests(unittest.TestCase):
    def test_stub_returns_valid_scores(self):
        path = extract.find_card("2026-03-18")
        b = extract.load_card(path)
        result = judge.judge(b.body_text, [], backend="stub")
        for axis in ("factuality", "novelty", "source_diversity",
                     "signal_density", "coherence"):
            self.assertIn(axis, result.scores)
            v = result.scores[axis]
            self.assertIsInstance(v, int)
            self.assertGreaterEqual(v, 1)
            self.assertLessEqual(v, 5)
        self.assertEqual(result.prompt_version, "v1")

    def test_parse_judge_response_rejects_garbage(self):
        with self.assertRaises(ValueError):
            judge.parse_judge_response("hello world, no JSON here")

    def test_parse_judge_response_rejects_out_of_range(self):
        bad = '```json\n{"factuality":7,"novelty":3,"source_diversity":3,"signal_density":3,"coherence":3}\n```'
        with self.assertRaises(ValueError):
            judge.parse_judge_response(bad)


class StoreTests(unittest.TestCase):
    def _tmp_db(self) -> Path:
        td = tempfile.mkdtemp(prefix="eval_test_")
        return Path(td) / "store.sqlite"

    def test_composite_matches_weighted_formula(self):
        scores = {
            "factuality": 5, "novelty": 4, "source_diversity": 3,
            "signal_density": 2, "coherence": 1,
        }
        # 0.30*5 + 0.20*4 + 0.15*3 + 0.20*2 + 0.15*1 = 1.5 + 0.8 + 0.45 + 0.4 + 0.15 = 3.30
        self.assertAlmostEqual(store.composite(scores), 3.30, places=2)

    def test_upsert_is_idempotent_on_key(self):
        db = self._tmp_db()
        scores = {"factuality": 4, "novelty": 4, "source_diversity": 4,
                  "signal_density": 4, "coherence": 4, "notes": "first"}
        store.upsert_run(card_date="2026-03-18", prompt_version="v1",
                         judge_model="stub-v1", scores=scores, raw="r1", db_path=db)
        scores["notes"] = "second"
        scores["factuality"] = 5
        store.upsert_run(card_date="2026-03-18", prompt_version="v1",
                         judge_model="stub-v1", scores=scores, raw="r2", db_path=db)
        rows = store.fetch_runs(db_path=db)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["notes"], "second")
        self.assertEqual(rows[0]["factuality"], 5)
        self.assertEqual(rows[0]["judge_raw"], "r2")


class DriftTests(unittest.TestCase):
    def setUp(self):
        td = tempfile.mkdtemp(prefix="eval_drift_")
        self.db = Path(td) / "store.sqlite"
        # Patch the module default so drift+store read the temp DB.
        store.DB_PATH_DEFAULT = self.db

    def _seed(self, day_to_composite: dict[str, float], model: str = "stub-v1") -> None:
        for day, comp in day_to_composite.items():
            scores = {
                "factuality": 3, "novelty": 3, "source_diversity": 3,
                "signal_density": 3, "coherence": 3, "notes": "",
            }
            # Force composite by overriding through direct sqlite update.
            store.upsert_run(card_date=day, prompt_version="v1",
                             judge_model=model, scores=scores, raw="seed",
                             db_path=self.db)
            import sqlite3
            with sqlite3.connect(self.db) as conn:
                conn.execute(
                    "UPDATE eval_runs SET composite = ? WHERE card_date = ? AND judge_model = ?",
                    (comp, day, model),
                )
                conn.commit()

    def test_no_alert_for_flat_history(self):
        from datetime import date, timedelta
        end = date(2026, 3, 18)
        seed = {(end - timedelta(days=i)).isoformat(): 4.2 for i in range(30)}
        self._seed(seed)
        result = drift.evaluate("2026-03-18")
        self.assertEqual(result["status"], "ok")

    def test_alert_fires_on_recent_drop(self):
        from datetime import date, timedelta
        end = date(2026, 3, 18)
        seed = {(end - timedelta(days=i)).isoformat(): 4.2 for i in range(8, 30)}
        # last 8 days bad
        for i in range(0, 8):
            seed[(end - timedelta(days=i)).isoformat()] = 1.0
        self._seed(seed)
        result = drift.evaluate("2026-03-18")
        self.assertEqual(result["status"], "alert")
        self.assertGreaterEqual(len(result["alerts"]), 2)


class ReportTests(unittest.TestCase):
    def setUp(self):
        td = tempfile.mkdtemp(prefix="eval_report_")
        self.db = Path(td) / "store.sqlite"
        store.DB_PATH_DEFAULT = self.db
        scores = {"factuality": 4, "novelty": 4, "source_diversity": 4,
                  "signal_density": 5, "coherence": 4, "notes": "ok"}
        store.upsert_run(card_date="2026-03-18", prompt_version="v1",
                         judge_model="stub-v1", scores=scores, raw="r",
                         db_path=self.db)

    def test_report_contains_headers_and_row(self):
        md = report.build("2026-03-18", window=7)
        self.assertIn("# Briefing Eval Report", md)
        self.assertIn("Composite (median)", md)
        self.assertIn("2026-03-18", md)


if __name__ == "__main__":
    unittest.main()
