"""Weekly Markdown report of eval scores.

    python eval/report.py --as-of 2026-03-18 --window 7

Prints Markdown to stdout. Pipe into Notion/Teams/Slack via the project's
existing publish scripts, or commit it under ``logs/eval-reports/``.
"""

from __future__ import annotations

import argparse
import statistics
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from store import fetch_runs  # noqa: E402

AXES = ("factuality", "novelty", "source_diversity", "signal_density", "coherence")


def build(as_of: str, window: int = 7) -> str:
    y, m, d = (int(x) for x in as_of.split("-"))
    end = date(y, m, d)
    start = end - timedelta(days=window - 1)
    rows = fetch_runs(since=start.isoformat(), until=end.isoformat())

    # Latest run per date.
    by_date: dict[str, dict] = {}
    for r in rows:
        d = r["card_date"]
        if d not in by_date or r["ran_at"] > by_date[d]["ran_at"]:
            by_date[d] = r

    lines: list[str] = []
    lines.append(f"# Briefing Eval Report — {start.isoformat()} → {end.isoformat()}")
    lines.append("")
    if not by_date:
        lines.append("_No eval data in window._")
        return "\n".join(lines)

    composites = [r["composite"] for r in by_date.values()]
    lines.append(f"**Coverage:** {len(by_date)}/{window} days")
    lines.append(f"**Composite (median):** {statistics.median(composites):.2f}")
    lines.append(f"**Composite (min/max):** {min(composites):.2f} / {max(composites):.2f}")
    lines.append("")

    lines.append("## Axis medians")
    lines.append("")
    lines.append("| axis | median |")
    lines.append("| --- | ---: |")
    for axis in AXES:
        med = statistics.median(r[axis] for r in by_date.values())
        lines.append(f"| {axis} | {med:.1f} |")
    lines.append("")

    lines.append("## Per-day detail")
    lines.append("")
    cols = ["date", "composite", *AXES, "judge", "notes"]
    lines.append("| " + " | ".join(cols) + " |")
    lines.append("|" + "|".join(["---"] * len(cols)) + "|")
    for d in sorted(by_date):
        r = by_date[d]
        notes = (r.get("notes") or "").replace("|", "\\|").replace("\n", " ")
        lines.append(
            "| "
            + " | ".join(
                [
                    d,
                    f"{r['composite']:.2f}",
                    *[str(r[a]) for a in AXES],
                    r["judge_model"],
                    notes[:80],
                ]
            )
            + " |"
        )
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--as-of", required=True, help="YYYY-MM-DD")
    p.add_argument("--window", type=int, default=7)
    p.add_argument("--out", help="Write to file (otherwise stdout)")
    args = p.parse_args(argv)
    md = build(args.as_of, args.window)
    if args.out:
        Path(args.out).write_text(md)
        print(f"wrote {args.out}")
    else:
        print(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
