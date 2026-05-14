#!/bin/bash
set -euo pipefail

# eval-compare.sh — Side-by-side comparison of two judges (or two prompt versions)
# across the same card_dates. Useful for:
#   - validating a new judge model before re-baselining (e.g. Haiku vs Sonnet)
#   - bumping PROMPT_VERSION and proving the new prompt didn't shift scores
#   - sanity-checking the stub backend against the real Claude judge
#
# Usage:
#   bash scripts/eval-compare.sh --a claude-haiku-4-5-20251001 --b stub-v1
#   bash scripts/eval-compare.sh --a claude-haiku-4-5-20251001 --b gemini-cli
#   bash scripts/eval-compare.sh --a-prompt v1 --b-prompt v2 --judge claude-haiku-4-5-20251001
#   bash scripts/eval-compare.sh ... --threshold 0.5   # flag deltas above this

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="${SCRIPT_DIR}/eval/store.sqlite"

A_JUDGE=""
B_JUDGE=""
A_PROMPT=""
B_PROMPT=""
SHARED_JUDGE=""
THRESHOLD="0.5"

while [ $# -gt 0 ]; do
  case "$1" in
    --a)         A_JUDGE="$2"; shift 2 ;;
    --b)         B_JUDGE="$2"; shift 2 ;;
    --a-prompt)  A_PROMPT="$2"; shift 2 ;;
    --b-prompt)  B_PROMPT="$2"; shift 2 ;;
    --judge)     SHARED_JUDGE="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    -h|--help)
      sed -n '4,15p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$DB" ]; then
  echo "No eval store at $DB. Run a backfill first." >&2
  exit 1
fi

# Resolve A vs B: either two judges (default) or two prompts under one judge
if [ -n "$A_PROMPT" ] || [ -n "$B_PROMPT" ]; then
  if [ -z "$A_PROMPT" ] || [ -z "$B_PROMPT" ] || [ -z "$SHARED_JUDGE" ]; then
    echo "When comparing prompt versions, pass --a-prompt, --b-prompt, and --judge." >&2
    exit 2
  fi
  A_WHERE="judge_model = '$SHARED_JUDGE' AND prompt_version = '$A_PROMPT'"
  B_WHERE="judge_model = '$SHARED_JUDGE' AND prompt_version = '$B_PROMPT'"
  A_LABEL="$SHARED_JUDGE/$A_PROMPT"
  B_LABEL="$SHARED_JUDGE/$B_PROMPT"
else
  if [ -z "$A_JUDGE" ] || [ -z "$B_JUDGE" ]; then
    echo "Pass --a and --b (judge_model) or --a-prompt/--b-prompt/--judge." >&2
    bash "$0" --help
    exit 2
  fi
  A_WHERE="judge_model = '$A_JUDGE'"
  B_WHERE="judge_model = '$B_JUDGE'"
  A_LABEL="$A_JUDGE"
  B_LABEL="$B_JUDGE"
fi

green() { printf "\033[32m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }
yellow(){ printf "\033[33m%s\033[0m" "$1"; }
dim()   { printf "\033[90m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

echo ""
bold "  Eval comparison"; echo ""
echo "  ==============="
printf "  A: %s\n" "$A_LABEL"
printf "  B: %s\n" "$B_LABEL"
printf "  flag threshold: |A − B| > %s\n" "$THRESHOLD"
echo ""

# Build a joined view of (card_date, a_composite, b_composite, delta) and stream it.
sqlite3 -separator '|' "$DB" "
  SELECT
    a.card_date,
    printf('%.2f', a.composite),
    printf('%.2f', b.composite),
    printf('%+.2f', a.composite - b.composite)
  FROM (SELECT * FROM eval_runs WHERE $A_WHERE) a
  JOIN (SELECT * FROM eval_runs WHERE $B_WHERE) b ON a.card_date = b.card_date
  ORDER BY a.card_date;
" > /tmp/eval-compare.$$ || { rm -f /tmp/eval-compare.$$; exit 1; }

if [ ! -s /tmp/eval-compare.$$ ]; then
  yellow "  no overlapping card_dates between A and B"; echo ""
  rm -f /tmp/eval-compare.$$
  exit 1
fi

# Header + body
printf "  %-12s %-10s %-10s %-10s %s\n" "date" "A" "B" "Δ (A−B)" "flag"
printf "  %-12s %-10s %-10s %-10s %s\n" "----" "------" "------" "------" "----"

FLAGGED=0
ROWS=0
SUM_A=0
SUM_B=0
SUM_ABS_DELTA=0

while IFS='|' read -r D A B DELTA; do
  ROWS=$((ROWS + 1))
  # awk handles floats portably (BSD/GNU agnostic).
  ABS_DELTA="$(awk -v d="$DELTA" 'BEGIN { print (d<0)? -d : d }')"
  OVER="$(awk -v a="$ABS_DELTA" -v t="$THRESHOLD" 'BEGIN { print (a > t) ? 1 : 0 }')"
  if [ "$OVER" = "1" ]; then
    FLAGGED=$((FLAGGED + 1))
    LABEL="$(red "FLAGGED")"
  else
    LABEL="$(dim "ok")"
  fi
  printf "  %-12s %-10s %-10s %-10s %s\n" "$D" "$A" "$B" "$DELTA" "$LABEL"
  SUM_A="$(awk -v s="$SUM_A" -v x="$A" 'BEGIN { print s + x }')"
  SUM_B="$(awk -v s="$SUM_B" -v x="$B" 'BEGIN { print s + x }')"
  SUM_ABS_DELTA="$(awk -v s="$SUM_ABS_DELTA" -v x="$ABS_DELTA" 'BEGIN { print s + x }')"
done < /tmp/eval-compare.$$
rm -f /tmp/eval-compare.$$

MEAN_A="$(awk -v s="$SUM_A" -v n="$ROWS" 'BEGIN { printf "%.2f", s/n }')"
MEAN_B="$(awk -v s="$SUM_B" -v n="$ROWS" 'BEGIN { printf "%.2f", s/n }')"
MAE="$(awk -v s="$SUM_ABS_DELTA" -v n="$ROWS" 'BEGIN { printf "%.2f", s/n }')"

echo ""
bold "  Summary"; echo ""
echo "  -------"
printf "  rows compared: %s\n" "$ROWS"
printf "  mean A:        %s\n" "$MEAN_A"
printf "  mean B:        %s\n" "$MEAN_B"
printf "  MAE |A − B|:   %s\n" "$MAE"
printf "  flagged:       %s\n" "$FLAGGED"
echo ""

if [ "$FLAGGED" -gt 0 ]; then
  yellow "  $FLAGGED card(s) exceed threshold $THRESHOLD — investigate the judge prompt or model behavior"; echo ""
  exit 3
fi

green "  All deltas within ±$THRESHOLD — A and B agree within tolerance"; echo ""
