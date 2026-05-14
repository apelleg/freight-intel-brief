"""SQLite-backed store for eval runs."""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

DB_PATH_DEFAULT = Path(__file__).resolve().parent / "store.sqlite"
SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"

WEIGHTS = {
    "factuality": 0.30,
    "novelty": 0.20,
    "source_diversity": 0.15,
    "signal_density": 0.20,
    "coherence": 0.15,
}


def composite(scores: dict) -> float:
    total = sum(WEIGHTS[k] * scores[k] for k in WEIGHTS)
    return round(total, 2)


@contextmanager
def connect(db_path: Path | None = None):
    p = db_path or DB_PATH_DEFAULT
    conn = sqlite3.connect(p)
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        conn.executescript(SCHEMA_PATH.read_text())
        yield conn
        conn.commit()
    finally:
        conn.close()


def upsert_run(
    *,
    card_date: str,
    prompt_version: str,
    judge_model: str,
    scores: dict,
    raw: str,
    db_path: Path | None = None,
) -> float:
    comp = composite(scores)
    ran_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with connect(db_path) as conn:
        conn.execute(
            """
            INSERT INTO eval_runs (
                card_date, prompt_version, judge_model, ran_at,
                factuality, novelty, source_diversity, signal_density, coherence,
                composite, notes, judge_raw
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(card_date, prompt_version, judge_model) DO UPDATE SET
                ran_at = excluded.ran_at,
                factuality = excluded.factuality,
                novelty = excluded.novelty,
                source_diversity = excluded.source_diversity,
                signal_density = excluded.signal_density,
                coherence = excluded.coherence,
                composite = excluded.composite,
                notes = excluded.notes,
                judge_raw = excluded.judge_raw
            """,
            (
                card_date,
                prompt_version,
                judge_model,
                ran_at,
                scores["factuality"],
                scores["novelty"],
                scores["source_diversity"],
                scores["signal_density"],
                scores["coherence"],
                comp,
                scores.get("notes", ""),
                raw,
            ),
        )
    return comp


def fetch_runs(
    *,
    since: str | None = None,
    until: str | None = None,
    prompt_version: str | None = None,
    judge_model: str | None = None,
    db_path: Path | None = None,
) -> list[dict]:
    where: list[str] = []
    args: list = []
    if since:
        where.append("card_date >= ?")
        args.append(since)
    if until:
        where.append("card_date <= ?")
        args.append(until)
    if prompt_version:
        where.append("prompt_version = ?")
        args.append(prompt_version)
    if judge_model:
        where.append("judge_model = ?")
        args.append(judge_model)
    sql = "SELECT * FROM eval_runs"
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY card_date ASC"
    with connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = [dict(r) for r in conn.execute(sql, args).fetchall()]
    return rows
