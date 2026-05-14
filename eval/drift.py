"""Drift detection over rolling composite scores.

Heuristic: alert when the trailing-7d median is more than ``z_thresh``
standard deviations below the trailing-30d median, for ``streak`` consecutive
days. We use median + MAD-based scale to stay robust on small samples
(18-card backfill is not enough for clean stddev).

Run from the repo root:

    python eval/drift.py --as-of 2026-03-18
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from store import fetch_runs  # noqa: E402


def _median_and_mad(xs: list[float]) -> tuple[float, float]:
    if not xs:
        return 0.0, 0.0
    med = statistics.median(xs)
    mad = statistics.median(abs(x - med) for x in xs)
    return med, mad


def _date_range(end: date, days: int) -> list[str]:
    return [(end - timedelta(days=i)).isoformat() for i in range(days)]


def evaluate(as_of: str, *, short_window: int = 7, long_window: int = 30,
             z_thresh: float = 1.5, streak: int = 2) -> dict:
    y, m, d = (int(x) for x in as_of.split("-"))
    end = date(y, m, d)
    long_dates = set(_date_range(end, long_window))
    rows = fetch_runs(since=min(long_dates), until=max(long_dates) if long_dates else None)
    if not rows:
        return {"as_of": as_of, "status": "no_data", "alerts": []}

    # If multiple judge runs exist for a date, prefer the latest run.
    by_date: dict[str, float] = {}
    latest_at: dict[str, str] = {}
    for r in rows:
        d = r["card_date"]
        if d not in latest_at or r["ran_at"] > latest_at[d]:
            latest_at[d] = r["ran_at"]
            by_date[d] = r["composite"]

    alerts: list[dict] = []
    bad_days = 0
    for i in range(streak):
        check_day = (end - timedelta(days=i)).isoformat()
        short_xs = [
            by_date[d.isoformat()]
            for d in (end - timedelta(days=i + k) for k in range(short_window))
            if d.isoformat() in by_date
        ]
        long_xs = [
            by_date[d.isoformat()]
            for d in (end - timedelta(days=i + k) for k in range(long_window))
            if d.isoformat() in by_date
        ]
        if len(short_xs) < 3 or len(long_xs) < 7:
            continue
        short_med = statistics.median(short_xs)
        long_med, long_mad = _median_and_mad(long_xs)
        scale = max(long_mad, 0.05)  # avoid div-by-zero
        z = (short_med - long_med) / scale
        if z < -z_thresh:
            bad_days += 1
            alerts.append({
                "day": check_day,
                "short_median": round(short_med, 2),
                "long_median": round(long_med, 2),
                "z": round(z, 2),
            })

    status = "alert" if bad_days >= streak else "ok"
    return {
        "as_of": as_of,
        "status": status,
        "short_window": short_window,
        "long_window": long_window,
        "z_thresh": z_thresh,
        "streak_required": streak,
        "alerts": alerts,
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--as-of", required=True, help="YYYY-MM-DD")
    p.add_argument("--short-window", type=int, default=7)
    p.add_argument("--long-window", type=int, default=30)
    p.add_argument("--z-thresh", type=float, default=1.5)
    p.add_argument("--streak", type=int, default=2)
    p.add_argument("--exit-nonzero-on-alert", action="store_true")
    args = p.parse_args(argv)

    result = evaluate(
        args.as_of,
        short_window=args.short_window,
        long_window=args.long_window,
        z_thresh=args.z_thresh,
        streak=args.streak,
    )
    print(json.dumps(result, indent=2))
    if args.exit_nonzero_on_alert and result["status"] == "alert":
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
