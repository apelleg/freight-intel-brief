"""Export eval/store.sqlite + eval/golden/ to a static JSON file the
dashboard HTML can load offline.

Usage:
    python3 eval/export_dashboard.py
    python3 eval/export_dashboard.py --judge claude-haiku-4-5-20251001
    python3 eval/export_dashboard.py --open      # also open the dashboard in a browser

Output: eval/dashboard/data.js  (sets window.EVAL_DATA = {...})
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import webbrowser
from datetime import date, datetime, timezone, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from store import fetch_runs, WEIGHTS  # noqa: E402

HERE = Path(__file__).resolve().parent
DASHBOARD_DIR = HERE / "dashboard"
GOLDEN_DIR = HERE / "golden"
AXES = ("factuality", "novelty", "source_diversity", "signal_density", "coherence")


def _latest_per_date(rows: list[dict]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for r in rows:
        d = r["card_date"]
        if d not in out or r["ran_at"] > out[d]["ran_at"]:
            out[d] = r
    return out


def _drift(by_date: dict[str, dict]) -> dict:
    """Lightweight drift summary using median + MAD on last 30 days."""
    if not by_date:
        return {"status": "no_data"}
    dates = sorted(by_date)
    composites = [by_date[d]["composite"] for d in dates]
    end_date_str = dates[-1]
    y, m, d = (int(x) for x in end_date_str.split("-"))
    end = date(y, m, d)

    def window(days: int) -> list[float]:
        cutoff = end - timedelta(days=days - 1)
        return [
            by_date[k]["composite"]
            for k in dates
            if date(*[int(x) for x in k.split("-")]) >= cutoff
        ]

    short = window(7)
    long_ = window(30)
    if len(short) < 2 or len(long_) < 3:
        return {"status": "ok", "short_median": None, "long_median": None, "z": None}

    short_med = statistics.median(short)
    long_med = statistics.median(long_)
    long_mad = statistics.median(abs(x - long_med) for x in long_)
    scale = max(long_mad, 0.05)
    z = (short_med - long_med) / scale
    status = "alert" if z < -1.5 else "ok"
    return {
        "status": status,
        "short_median": round(short_med, 2),
        "long_median": round(long_med, 2),
        "long_mad": round(long_mad, 3),
        "z": round(z, 2),
    }


def _load_golden() -> dict[str, dict]:
    out = {}
    for p in sorted(GOLDEN_DIR.glob("*.json")):
        try:
            spec = json.loads(p.read_text())
            out[spec["card_date"]] = spec
        except Exception:
            pass
    return out


def build_payload(judge_filter: str | None) -> dict:
    rows = fetch_runs(judge_model=judge_filter)
    by_date = _latest_per_date(rows)
    golden = _load_golden()

    # Per-card payload sorted by date asc
    cards = []
    for d in sorted(by_date):
        r = by_date[d]
        g = golden.get(d)
        cards.append({
            "card_date": d,
            "ran_at": r["ran_at"],
            "judge_model": r["judge_model"],
            "prompt_version": r["prompt_version"],
            "composite": r["composite"],
            "axes": {a: r[a] for a in AXES},
            "notes": (r.get("notes") or "").strip(),
            "baseline_composite": g["baseline_composite"] if g else None,
            "baseline_judge": g["baseline_judge"] if g else None,
            "delta_vs_baseline": (
                round(r["composite"] - g["baseline_composite"], 2) if g else None
            ),
        })

    composites = [c["composite"] for c in cards]
    summary = {
        "card_count": len(cards),
        "composite_min": min(composites) if composites else None,
        "composite_max": max(composites) if composites else None,
        "composite_median": round(statistics.median(composites), 2) if composites else None,
        "composite_mean": round(statistics.mean(composites), 2) if composites else None,
        "axis_medians": {
            a: round(statistics.median(c["axes"][a] for c in cards), 2) if cards else None
            for a in AXES
        },
        "judges": sorted({c["judge_model"] for c in cards}),
        "prompt_versions": sorted({c["prompt_version"] for c in cards}),
        "golden_count": len(golden),
    }

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "weights": WEIGHTS,
        "axes": list(AXES),
        "summary": summary,
        "drift": _drift(by_date),
        "cards": cards,
    }
    return payload


def write_data_js(payload: dict, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    body = json.dumps(payload, indent=2, sort_keys=False)
    target.write_text(f"window.EVAL_DATA = {body};\n")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--judge", help="Only export rows from this judge_model")
    p.add_argument("--out", default=str(DASHBOARD_DIR / "data.js"))
    p.add_argument("--open", dest="open_browser", action="store_true",
                   help="Open the dashboard in the default browser after exporting")
    args = p.parse_args(argv)

    payload = build_payload(args.judge)
    out = Path(args.out)
    write_data_js(payload, out)
    print(f"wrote {out} ({len(payload['cards'])} cards, {payload['summary']['golden_count']} goldens)")

    html = DASHBOARD_DIR / "index.html"
    if args.open_browser and html.exists():
        webbrowser.open(html.as_uri())
        print(f"opened {html.as_uri()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
