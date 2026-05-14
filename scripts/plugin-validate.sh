#!/bin/bash
set -euo pipefail

# plugin-validate.sh -- Lint every plugin/extension manifest, marketplace entry,
# SKILL.md frontmatter, and agent file. Non-zero exit on any error. Warnings are
# informational and never fail.
#
# Usage:
#   bash scripts/plugin-validate.sh              # check all 3 platforms + marketplace
#   bash scripts/plugin-validate.sh --strict     # also fail on warnings
#   bash scripts/plugin-validate.sh --json       # emit machine-readable report

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

STRICT=0
JSON_OUT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --json)   JSON_OUT=1; shift ;;
    -h|--help)
      sed -n '4,10p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 required" >&2; exit 1
fi

# Both this script and plugin-validate.ps1 delegate to the same python file
# so the checks stay in lockstep; previously the .sh and .ps1 each held a
# copy of the validator and they drifted, making Windows-only failures
# extremely painful to debug.
exec python3 "$(dirname "$0")/_plugin_validate.py" "$STRICT" "$JSON_OUT"
