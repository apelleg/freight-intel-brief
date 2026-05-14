# Briefing Quality Eval Harness

LLM-as-judge scoring for daily AI News Briefing cards. Tracks composite quality
over time, runs a regression guard against a golden set, and surfaces drift
before it ships to readers.

## What it scores

Five axes, integer 1–5 each (rubric in [`rubric.md`](rubric.md)):

| Axis             | Weight |
| ---------------- | -----: |
| factuality       |   0.30 |
| novelty          |   0.20 |
| source_diversity |   0.15 |
| signal_density   |   0.20 |
| coherence        |   0.15 |

`composite = round(0.30·F + 0.20·N + 0.15·D + 0.20·S + 0.15·C, 2)`

## Quick start

```bash
# Score today (stub judge, no API)
make eval D=2026-03-18

# Score with the real Claude judge (uses claude CLI like the rest of the project)
make eval D=2026-03-18 JUDGE=claude

# Backfill every card in example-cards/
make eval-backfill

# Weekly Markdown report
make eval-report D=2026-03-18 W=7

# Drift check, exit 3 on alert (use in cron)
make eval-drift D=2026-03-18 ALERT_EXIT=1

# Regression: re-score the golden cards, fail on > 0.5 drop
make eval-regression JUDGE=claude

# Run unit tests
make eval-test
```

## How the judge is wired

The harness shells out to whatever AI CLI you already use, matching the
existing `briefing.sh` pattern. Backends:

- `stub` — deterministic heuristic, used by tests and CI smoke runs.
- `claude` — `claude -p --model $EVAL_JUDGE_MODEL` (default `claude-haiku-4-5-20251001`).
- `codex` — `codex exec -`.
- `gemini` — `gemini -p <prompt>`.

The judge prompt is in [`judge_prompt.md`](judge_prompt.md). Its version
(`PROMPT_VERSION` in `judge.py`) is part of the primary key, so bumping the
prompt does **not** silently overwrite old scores.

## Storage

SQLite at `eval/store.sqlite` (git-ignored). Schema in `schema.sql`.
Primary key: `(card_date, prompt_version, judge_model)` — re-runs of the same
combination overwrite; switching judge or prompt version appends a new row.

## Golden set

`eval/golden/*.json` — each file pins a `card_date` + `baseline_composite`.
`make eval-regression` re-scores them and exits 2 if any drops more than
0.5 composite points. Bump the baselines when re-scoring under a new judge:

```json
{
  "card_date": "2026-03-18",
  "baseline_composite": 4.2,
  "baseline_judge": "claude-haiku-4-5-20251001",
  "baseline_prompt_version": "v1"
}
```

## Drift detection

`drift.py` compares the trailing-7d median composite to the trailing-30d
median, scaled by MAD (robust to outliers). Alerts when

  z = (short_med − long_med) / max(long_mad, 0.05) < −1.5

for 2 consecutive days. Tune `--short-window`, `--long-window`,
`--z-thresh`, `--streak`.

## Publish gate (optional)

To block a briefing publish on a quality fail, run scoring with `--gate` before
the publish step:

```bash
python3 eval/runner.py score --date "$DATE" --judge claude --gate --gate-threshold 3.0 \
  || { echo "Briefing failed eval gate, not publishing." >&2; exit 1; }
```

Exit codes: 0 = pass, 2 = gate fail, 1 = harness error.

## Cost

Judge runs use Claude Haiku by default (~$0.002/card). Daily + weekly golden
replay (~25 calls/wk) ≈ $0.05/wk. Backfill caps at `--max-calls 50` (bump
flag to override).

## File map

| File          | Role                                                   |
| ------------- | ------------------------------------------------------ |
| `rubric.md`   | Human-readable axis definitions, weights, thresholds.  |
| `judge_prompt.md` | Exact prompt sent to the judge. Versioned.         |
| `extract.py`  | Adaptive-card JSON → flat text + headlines + URLs.     |
| `judge.py`    | Backends (stub/claude/codex/gemini) + JSON parser.     |
| `store.py`    | SQLite upsert + fetch.                                 |
| `runner.py`   | CLI: `score`, `backfill`, `regression`, `show`.        |
| `drift.py`    | Rolling-window drift detector.                         |
| `report.py`   | Weekly Markdown report.                                |
| `schema.sql`  | DB schema.                                             |
| `golden/`     | Pinned baseline composites per card.                   |
| `tests/`      | `python -m unittest discover -s eval/tests`.           |
