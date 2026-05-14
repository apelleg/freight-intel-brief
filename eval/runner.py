"""CLI entry point: judge a single briefing card and persist the score.

Examples
--------
    python eval/runner.py --date 2026-03-18 --judge stub
    python eval/runner.py --date 2026-03-18 --judge claude
    python eval/runner.py --backfill --judge stub
    python eval/runner.py --regression --judge claude
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow `python eval/runner.py` from repo root.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract import find_card, load_card, prior_headlines, CARD_DIR_DEFAULT  # noqa: E402
from judge import PROMPT_VERSION, judge  # noqa: E402
from store import composite, upsert_run, fetch_runs  # noqa: E402

GOLDEN_DIR = Path(__file__).resolve().parent / "golden"
MAX_JUDGE_CALLS_DEFAULT = 50


def _score_one(card_date: str, backend: str) -> dict:
    path = find_card(card_date)
    b = load_card(path)
    prior = prior_headlines(card_date)
    result = judge(b.body_text, prior, backend=backend)
    comp = upsert_run(
        card_date=card_date,
        prompt_version=result.prompt_version,
        judge_model=result.model,
        scores=result.scores,
        raw=result.raw,
    )
    return {
        "card_date": card_date,
        "judge_model": result.model,
        "prompt_version": result.prompt_version,
        "composite": comp,
        **{k: result.scores[k] for k in (
            "factuality", "novelty", "source_diversity", "signal_density", "coherence",
        )},
        "notes": result.scores.get("notes", ""),
    }


def cmd_score(args: argparse.Namespace) -> int:
    out = _score_one(args.date, args.judge)
    print(json.dumps(out, indent=2))
    if args.gate and out["composite"] < args.gate_threshold:
        print(f"GATE FAIL: composite {out['composite']} < {args.gate_threshold}", file=sys.stderr)
        return 2
    return 0


def cmd_backfill(args: argparse.Namespace) -> int:
    card_dir = CARD_DIR_DEFAULT
    cards = sorted(p.name[:10] for p in card_dir.glob("*-card.json"))
    if not cards:
        print(f"No cards found in {card_dir}", file=sys.stderr)
        return 1
    if len(cards) > args.max_calls:
        print(
            f"Refusing to judge {len(cards)} cards (--max-calls={args.max_calls}). "
            "Bump --max-calls if intentional.",
            file=sys.stderr,
        )
        return 1
    print(f"Backfilling {len(cards)} cards with backend={args.judge!r} ...")
    failures = 0
    for d in cards:
        try:
            r = _score_one(d, args.judge)
            print(f"  {d}: composite={r['composite']}")
        except Exception as e:  # keep going through the set
            failures += 1
            print(f"  {d}: ERROR {e}", file=sys.stderr)
    print(f"Done. {len(cards) - failures}/{len(cards)} succeeded.")
    return 0 if failures == 0 else 1


def cmd_regression(args: argparse.Namespace) -> int:
    """Re-judge each card in golden/ and compare to its baseline composite.

    Each golden card is a JSON file:
        {"card_date": "2026-03-04", "baseline_composite": 4.3}
    """
    golden_files = sorted(GOLDEN_DIR.glob("*.json"))
    if not golden_files:
        print(f"No golden cards in {GOLDEN_DIR}. Add some first.", file=sys.stderr)
        return 1
    threshold = args.regression_drop
    failures: list[str] = []
    for gf in golden_files:
        spec = json.loads(gf.read_text())
        d = spec["card_date"]
        baseline = float(spec["baseline_composite"])
        try:
            r = _score_one(d, args.judge)
        except Exception as e:
            failures.append(f"{d}: judge error {e}")
            continue
        delta = r["composite"] - baseline
        verdict = "OK"
        if delta < -threshold:
            verdict = "REGRESSED"
            failures.append(f"{d}: composite {r['composite']} (baseline {baseline}, Δ {delta:+.2f})")
        print(f"  {d}: composite={r['composite']} baseline={baseline} Δ={delta:+.2f} {verdict}")
    if failures:
        print(f"\nFAIL: {len(failures)} regression(s)", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 2
    print(f"\nOK: {len(golden_files)} golden cards within Δ ≤ {threshold:.2f}")
    return 0


def cmd_show(args: argparse.Namespace) -> int:
    rows = fetch_runs(since=args.since, until=args.until)
    if args.format == "json":
        print(json.dumps(rows, indent=2))
    else:
        if not rows:
            print("(no rows)")
            return 0
        cols = ("card_date", "judge_model", "composite",
                "factuality", "novelty", "source_diversity",
                "signal_density", "coherence")
        print("\t".join(cols))
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Briefing eval runner")
    sub = p.add_subparsers(dest="cmd", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--judge", default="stub", choices=["stub", "claude", "codex", "gemini"])

    sp = sub.add_parser("score", parents=[common], help="Score one briefing")
    sp.add_argument("--date", required=True, help="YYYY-MM-DD card date")
    sp.add_argument("--gate", action="store_true", help="Exit non-zero if below threshold")
    sp.add_argument("--gate-threshold", type=float, default=3.0)
    sp.set_defaults(func=cmd_score)

    bp = sub.add_parser("backfill", parents=[common], help="Score every card in example-cards/")
    bp.add_argument("--max-calls", type=int, default=MAX_JUDGE_CALLS_DEFAULT)
    bp.set_defaults(func=cmd_backfill)

    rp = sub.add_parser("regression", parents=[common], help="Re-judge golden set, fail on drift")
    rp.add_argument("--regression-drop", type=float, default=0.5,
                    help="Allowed composite drop vs. golden baseline")
    rp.set_defaults(func=cmd_regression)

    shp = sub.add_parser("show", help="Dump eval rows")
    shp.add_argument("--since")
    shp.add_argument("--until")
    shp.add_argument("--format", choices=["tsv", "json"], default="tsv")
    shp.set_defaults(func=cmd_show)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
