#!/bin/bash
set -euo pipefail

# eval-watch.sh — Live tail of eval-judge logs + newly written eval rows.
# Useful while a long backfill is in flight, or to keep an eye on the auto-eval hook.
#
# Usage:
#   bash scripts/eval-watch.sh                 # follow today's eval-judge log + DB inserts
#   bash scripts/eval-watch.sh --date 2026-03-18
#   bash scripts/eval-watch.sh --interval 5    # poll the DB every 5 seconds (default 2)
#   bash scripts/eval-watch.sh --no-db         # tail only the log file, skip DB polling

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB="${SCRIPT_DIR}/eval/store.sqlite"
DATE="$(date +%Y-%m-%d)"
INTERVAL=2
WITH_DB=1

while [ $# -gt 0 ]; do
  case "$1" in
    --date)     DATE="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --no-db)    WITH_DB=0; shift ;;
    -h|--help)
      sed -n '4,11p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

LOG="${SCRIPT_DIR}/logs/eval-judge-${DATE}.log"
mkdir -p "${SCRIPT_DIR}/logs"
touch "$LOG"

green() { printf "\033[32m%s\033[0m" "$1"; }
yellow(){ printf "\033[33m%s\033[0m" "$1"; }
dim()   { printf "\033[90m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

echo ""
bold "  eval-watch — $(date +%H:%M:%S)"; echo ""
echo "  ============================"
printf "  log:      %s\n" "$LOG"
printf "  store:    %s\n" "$DB"
printf "  interval: %ss\n" "$INTERVAL"
printf "  ctrl-c:   exit\n"
echo ""

# Use a temp file to remember the last row count we saw
STATE_FILE="$(mktemp -t eval-watch.XXXXXX)"
trap 'rm -f "$STATE_FILE"' EXIT INT TERM

if [ "$WITH_DB" -eq 1 ] && [ -f "$DB" ]; then
  sqlite3 "$DB" "SELECT COUNT(*) FROM eval_runs;" > "$STATE_FILE" 2>/dev/null || echo 0 > "$STATE_FILE"
  (
    while true; do
      sleep "$INTERVAL"
      [ -f "$DB" ] || continue
      NEW="$(sqlite3 "$DB" "SELECT COUNT(*) FROM eval_runs;" 2>/dev/null || echo 0)"
      PREV="$(cat "$STATE_FILE")"
      if [ "$NEW" != "$PREV" ]; then
        DIFF=$((NEW - PREV))
        sqlite3 -separator '|' "$DB" "
          SELECT card_date, judge_model, printf('%.2f', composite), ran_at
          FROM eval_runs ORDER BY ran_at DESC LIMIT $DIFF;
        " | awk -F'|' -v g="$(green '+')" '{
            printf "  %s row  date=%-12s judge=%-30s composite=%s  ran_at=%s\n", g, $1, $2, $3, $4
          }'
        echo "$NEW" > "$STATE_FILE"
      fi
    done
  ) &
  POLLER=$!
  trap 'kill $POLLER 2>/dev/null; rm -f "$STATE_FILE"' EXIT INT TERM
fi

dim "  Following $LOG ..."; echo ""
tail -F "$LOG"
