"""Seed eval/golden/ from the current contents of eval/store.sqlite.

After backfilling against a real judge (e.g. ``make eval-backfill JUDGE=claude``),
run this to lift every persisted score into a pinned baseline. The regression
gate (``make eval-regression``) will then fail when any card's composite drops
more than ``--regression-drop`` points below the seeded baseline.

Usage:
    python3 eval/seed_golden.py                                 # use latest run per date
    python3 eval/seed_golden.py --judge claude-haiku-4-5-20251001
    python3 eval/seed_golden.py --since 2026-03-01 --until 2026-03-18
    python3 eval/seed_golden.py --dry-run

The script is idempotent. Existing golden files for the same date are
overwritten so the on-disk baseline always matches the most recent intentional
re-baseline.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from store import fetch_runs  # noqa: E402

GOLDEN_DIR = Path(__file__).resolve().parent / "golden"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Seed eval/golden/ from store.sqlite")
    p.add_argument("--judge", help="Only seed from this judge_model")
    p.add_argument("--prompt-version", help="Only seed from this prompt_version")
    p.add_argument("--since", help="YYYY-MM-DD lower bound on card_date")
    p.add_argument("--until", help="YYYY-MM-DD upper bound on card_date")
    p.add_argument("--dry-run", action="store_true", help="Print what would change without writing")
    p.add_argument("--clean", action="store_true",
                   help="Delete existing golden files before writing (full rebase)")
    args = p.parse_args(argv)

    rows = fetch_runs(
        since=args.since,
        until=args.until,
        prompt_version=args.prompt_version,
        judge_model=args.judge,
    )
    if not rows:
        print("No matching rows in eval_runs. Run `make eval-backfill JUDGE=claude` first.",
              file=sys.stderr)
        return 1

    # Latest ran_at per (card_date) wins.
    latest: dict[str, dict] = {}
    for r in rows:
        d = r["card_date"]
        if d not in latest or r["ran_at"] > latest[d]["ran_at"]:
            latest[d] = r

    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    if args.clean and not args.dry_run:
        for f in GOLDEN_DIR.glob("*.json"):
            f.unlink()
        print(f"cleaned {GOLDEN_DIR}")

    written = 0
    for d in sorted(latest):
        r = latest[d]
        spec = {
            "card_date": r["card_date"],
            "baseline_composite": r["composite"],
            "baseline_judge": r["judge_model"],
            "baseline_prompt_version": r["prompt_version"],
            "baseline_ran_at": r["ran_at"],
            "baseline_axes": {
                "factuality": r["factuality"],
                "novelty": r["novelty"],
                "source_diversity": r["source_diversity"],
                "signal_density": r["signal_density"],
                "coherence": r["coherence"],
            },
            "notes": (r.get("notes") or "").strip(),
        }
        out = GOLDEN_DIR / f"{d}.json"
        if args.dry_run:
            print(f"  would write {out} composite={r['composite']} judge={r['judge_model']}")
        else:
            out.write_text(json.dumps(spec, indent=2) + "\n")
            print(f"  wrote {out} composite={r['composite']} judge={r['judge_model']}")
            written += 1
    if args.dry_run:
        print(f"dry-run: {len(latest)} cards would be written")
    else:
        print(f"seeded {written} golden cards into {GOLDEN_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
