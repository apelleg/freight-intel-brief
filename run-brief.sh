#!/bin/bash
# run-brief.sh — Run the Uber Freight daily intel brief via Claude Code CLI.
#
# Uses your Claude subscription (no API key needed).
# Reads prompt.md + topics.json + memory/seen.json, runs Claude, then updates memory.
#
# Usage:
#   ./run-brief.sh              # run today's brief
#   ./run-brief.sh --dry-run    # search + compile but skip Slack delivery
#   ./run-brief.sh --model sonnet  # override model (default: sonnet)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="sonnet"
DRY_RUN=false
DATE=$(date +%Y-%m-%d)
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/$DATE-brief.log"
MEMORY_FILE="$SCRIPT_DIR/memory/seen.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./run-brief.sh [OPTIONS]

Options:
  --dry-run        Search and compile brief but skip Slack delivery
  --model MODEL    Claude model to use (default: sonnet)
  --help           Show this help

Environment variables (optional):
  SLACK_WEBHOOK    Slack incoming webhook URL for delivery
  NOTION_TOKEN     Notion API token for archiving
  NOTION_DATABASE_ID  Notion database to archive briefs into
USAGE
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

CLAUDE="$(command -v claude)"
mkdir -p "$LOG_DIR" "$SCRIPT_DIR/memory"

echo "[$DATE $(date +%H:%M:%S)] Starting Freight Intel Brief (model=$MODEL, dry-run=$DRY_RUN)..." | tee -a "$LOG_FILE"

# Build the prompt — inject dry-run override at the top if needed
PROMPT=$(cat "$SCRIPT_DIR/prompt.md")

if $DRY_RUN; then
  PROMPT="DRY RUN MODE: Complete Steps 0, 1, and 2 normally (load memory, search, compile brief).
For Step 3 (Slack delivery): skip the POST — print the brief to stdout instead.
For Step 4 (Notion): skip entirely.
Still output the Step 5 memory block at the end.

---

$PROMPT"
fi

# Prevent nested Claude Code sessions
unset CLAUDECODE 2>/dev/null || true

# Run the brief
OUTPUT=$("$CLAUDE" -p \
  --model "$MODEL" \
  --dangerously-skip-permissions \
  "$PROMPT" 2>&1)

EXIT_CODE=$?
echo "$OUTPUT" | tee -a "$LOG_FILE"

if [ $EXIT_CODE -ne 0 ]; then
  echo "[$DATE $(date +%H:%M:%S)] Brief FAILED (exit $EXIT_CODE)" | tee -a "$LOG_FILE"
  exit $EXIT_CODE
fi

# Parse and commit memory update
MEMORY_BLOCK=$(echo "$OUTPUT" | sed -n '/<<<MEMORY_UPDATE_START>>>/,/<<<MEMORY_UPDATE_END>>>/p' | \
  grep -v '<<<MEMORY_UPDATE' || true)

if [ -n "$MEMORY_BLOCK" ]; then
  node "$SCRIPT_DIR/scripts/update-memory.js" "$MEMORY_FILE" "$MEMORY_BLOCK"
  echo "[$DATE $(date +%H:%M:%S)] Memory updated: $MEMORY_FILE" | tee -a "$LOG_FILE"
else
  echo "[$DATE $(date +%H:%M:%S)] Warning: no memory update block found in output" | tee -a "$LOG_FILE"
fi

echo "[$DATE $(date +%H:%M:%S)] Done. Log: $LOG_FILE" | tee -a "$LOG_FILE"
