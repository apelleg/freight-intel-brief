#!/bin/bash
set -euo pipefail

# eval-summary.sh — At-a-glance summary of eval/store.sqlite contents.
# Reports per-judge composite stats, drift status, gate fails, and recent runs.
#
# Usage:
#   bash scripts/eval-summary.sh                  # default: claude-haiku judge, last 30 days
#   bash scripts/eval-summary.sh --judge stub-v1
#   bash scripts/eval-summary.sh --since 2026-03-01 --until 2026-03-18
#   bash scripts/eval-summary.sh --judges          # list every judge in the store and exit

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="${SCRIPT_DIR}/eval/store.sqlite"

JUDGE=""
SINCE=""
UNTIL=""
LIST_JUDGES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --judge) JUDGE="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --judges) LIST_JUDGES=1; shift ;;
    -h|--help)
      sed -n '4,11p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

green()  { printf "\033[32m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
dim()    { printf "\033[90m%s\033[0m" "$1"; }
bold()   { printf "\033[1m%s\033[0m" "$1"; }

if [ ! -f "$DB" ]; then
  echo "$(red "ERROR"): no eval store at $DB"
  echo "Run: make eval D=YYYY-MM-DD JUDGE=claude   (or make eval-backfill JUDGE=claude)"
  exit 1
fi

if [ "$LIST_JUDGES" -eq 1 ]; then
  echo ""
  bold "  Judges and prompt versions in store:"; echo ""
  echo "  ====================================="
  sqlite3 -separator $'\t' "$DB" \
    "SELECT judge_model, prompt_version, COUNT(*), MIN(card_date), MAX(card_date)
     FROM eval_runs GROUP BY judge_model, prompt_version ORDER BY 3 DESC;" |
    awk -F'\t' 'BEGIN { printf "  %-36s %-6s %-6s %-12s %-12s\n", "judge_model", "ver", "rows", "from", "to" }
                { printf "  %-36s %-6s %-6s %-12s %-12s\n", $1, $2, $3, $4, $5 }'
  echo ""
  exit 0
fi

if [ -z "$JUDGE" ]; then
  # Auto-pick the most-recent real judge, fall back to whatever has the most rows.
  JUDGE="$(sqlite3 "$DB" "SELECT judge_model FROM eval_runs WHERE judge_model LIKE 'claude%' OR judge_model LIKE 'gemini%' OR judge_model LIKE 'codex%' ORDER BY ran_at DESC LIMIT 1;")"
  if [ -z "$JUDGE" ]; then
    JUDGE="$(sqlite3 "$DB" "SELECT judge_model FROM eval_runs GROUP BY judge_model ORDER BY COUNT(*) DESC LIMIT 1;")"
  fi
fi

if [ -z "$JUDGE" ]; then
  echo "$(red "ERROR"): store has no rows"
  exit 1
fi

WHERE="WHERE judge_model = '$JUDGE'"
[ -n "$SINCE" ] && WHERE="$WHERE AND card_date >= '$SINCE'"
[ -n "$UNTIL" ] && WHERE="$WHERE AND card_date <= '$UNTIL'"

ROW_COUNT="$(sqlite3 "$DB" "SELECT COUNT(*) FROM eval_runs $WHERE;")"
if [ "$ROW_COUNT" = "0" ]; then
  echo "$(yellow "no rows match"): judge=$JUDGE since=$SINCE until=$UNTIL"
  echo "Run: bash scripts/eval-summary.sh --judges    # to list available judges"
  exit 1
fi

echo ""
bold "  Eval store summary"; echo ""
echo "  =================="
printf "  %-22s %s\n" "judge:"        "$JUDGE"
printf "  %-22s %s\n" "date range:"   "${SINCE:-(start)} → ${UNTIL:-(end)}"
printf "  %-22s %s\n" "rows matched:" "$ROW_COUNT"
echo ""

bold "  Composite distribution"; echo ""
echo "  ----------------------"
sqlite3 "$DB" "
  SELECT
    printf('%.2f', MIN(composite)),
    printf('%.2f', MAX(composite)),
    printf('%.2f', AVG(composite))
  FROM eval_runs $WHERE;
" | awk -F'|' '{ printf "  min=%-6s max=%-6s mean=%-6s\n", $1, $2, $3 }'

# Median via offset query (sqlite has no PERCENTILE_CONT)
MEDIAN="$(sqlite3 "$DB" "
  SELECT printf('%.2f', composite) FROM eval_runs $WHERE
  ORDER BY composite LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM eval_runs $WHERE);
")"
printf "  median=%s\n" "$MEDIAN"
echo ""

bold "  Axis medians"; echo ""
echo "  ------------"
for AX in factuality novelty source_diversity signal_density coherence; do
  V="$(sqlite3 "$DB" "
    SELECT printf('%.1f', $AX) FROM eval_runs $WHERE
    ORDER BY $AX LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM eval_runs $WHERE);
  ")"
  printf "  %-20s %s\n" "$AX" "$V"
done
echo ""

# Gate fails (< 3.0) and regressions vs golden
GATE_FAILS="$(sqlite3 "$DB" "SELECT COUNT(*) FROM eval_runs $WHERE AND composite < 3.0;")"
if [ "$GATE_FAILS" = "0" ]; then
  printf "  %-22s %s\n" "publish gate (3.0):" "$(green "all cards pass")"
else
  printf "  %-22s %s\n" "publish gate (3.0):" "$(yellow "$GATE_FAILS card(s) below 3.0")"
  sqlite3 "$DB" "SELECT card_date, printf('%.2f', composite) FROM eval_runs $WHERE AND composite < 3.0 ORDER BY card_date;" |
    awk -F'|' '{ printf "    %-12s composite=%s\n", $1, $2 }'
fi
echo ""

# Recent runs (last 10)
bold "  Recent runs"; echo ""
echo "  -----------"
sqlite3 "$DB" "
  SELECT card_date, printf('%.2f', composite), factuality, novelty, source_diversity, signal_density, coherence
  FROM eval_runs $WHERE ORDER BY card_date DESC LIMIT 10;
" | awk -F'|' 'BEGIN { printf "  %-12s %-9s %s %s %s %s %s\n", "date", "composite", "F", "N", "D", "S", "C" }
               { printf "  %-12s %-9s %s %s %s %s %s\n", $1, $2, $3, $4, $5, $6, $7 }'
echo ""

# Drift status (delegates to drift.py)
if command -v python3 >/dev/null 2>&1; then
  bold "  Drift status"; echo ""
  echo "  ------------"
  LAST_DATE="$(sqlite3 "$DB" "SELECT MAX(card_date) FROM eval_runs $WHERE;")"
  python3 "$SCRIPT_DIR/eval/drift.py" --as-of "$LAST_DATE" 2>/dev/null |
    python3 -c "
import json, sys
try: d = json.load(sys.stdin)
except: print('  (drift unavailable)'); sys.exit()
status = d.get('status', 'unknown')
color = '\033[32m' if status == 'ok' else '\033[33m' if status == 'no_data' else '\033[31m'
print(f'  as of {d.get(\"as_of\")}: {color}{status}\033[0m  z={d.get(\"z\")}  short_med={d.get(\"short_median\")}  long_med={d.get(\"long_median\")}')
"
  echo ""
fi

dim "  Tip: bash scripts/eval-summary.sh --judges       # list every (judge, prompt_version) combo"; echo ""
dim "       make eval-dashboard OPEN=1                  # interactive HTML view"; echo ""
echo ""
