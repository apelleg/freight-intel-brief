#!/bin/bash
set -euo pipefail

# scaffold-plugin.sh — Bootstrap a new plugin across all three platforms in one shot.
# Creates plugin.json, SKILL.md, and (optionally) GEMINI.md / agents/ scaffolding for
# claude-plugins/, plugins/<name>-codex/, and gemini-extensions/<name>/, then prints
# the marketplace.json snippet to paste in.
#
# Usage:
#   bash scripts/scaffold-plugin.sh --name my-plugin --description "what it does"
#   bash scripts/scaffold-plugin.sh --name my-plugin --description "..." --skill default-skill
#   bash scripts/scaffold-plugin.sh --name my-plugin --description "..." --with-agent reviewer
#   bash scripts/scaffold-plugin.sh --name my-plugin --description "..." --dry-run

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

NAME=""
DESC=""
SKILL=""
AGENT=""
DRY_RUN=0
AUTHOR_NAME="Son Nguyen"
AUTHOR_URL="https://github.com/hoangsonww"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)         NAME="$2"; shift 2 ;;
    --description)  DESC="$2"; shift 2 ;;
    --skill)        SKILL="$2"; shift 2 ;;
    --with-agent)   AGENT="$2"; shift 2 ;;
    --author)       AUTHOR_NAME="$2"; shift 2 ;;
    --author-url)   AUTHOR_URL="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '4,12p' "$0" | sed 's/^# *//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$DESC" ]; then
  echo "ERROR: --name and --description are required." >&2
  echo "Run: bash scripts/scaffold-plugin.sh --help" >&2
  exit 2
fi

if ! printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "ERROR: --name must be kebab-case (lowercase letters, digits, hyphens). Got: $NAME" >&2
  exit 2
fi

[ -z "$SKILL" ] && SKILL="default-skill"
if ! printf '%s' "$SKILL" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "ERROR: --skill must be kebab-case. Got: $SKILL" >&2
  exit 2
fi

CLAUDE_DIR="claude-plugins/$NAME"
CODEX_DIR="plugins/${NAME}-codex"
GEMINI_DIR="gemini-extensions/$NAME"

for d in "$CLAUDE_DIR" "$CODEX_DIR" "$GEMINI_DIR"; do
  if [ -e "$d" ]; then
    echo "ERROR: $d already exists. Refusing to overwrite." >&2
    exit 1
  fi
done

if [ "$DRY_RUN" = "1" ]; then
  echo "Would create:"
  echo "  $CLAUDE_DIR/.claude-plugin/plugin.json"
  echo "  $CLAUDE_DIR/skills/$SKILL/SKILL.md"
  echo "  $CODEX_DIR/.codex-plugin/plugin.json"
  echo "  $CODEX_DIR/skills/$SKILL/SKILL.md"
  echo "  $GEMINI_DIR/gemini-extension.json"
  echo "  $GEMINI_DIR/GEMINI.md"
  echo "  $GEMINI_DIR/skills/$SKILL/SKILL.md"
  [ -n "$AGENT" ] && {
    echo "  $CLAUDE_DIR/agents/$AGENT.md"
    echo "  $CODEX_DIR/agents/$AGENT.md"
    echo "  $GEMINI_DIR/agents/$AGENT.md"
  }
  echo "(dry-run; no files written)"
  exit 0
fi

# ---- Shared skill body -------------------------------------------------
write_skill_md() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
description: $DESC
---

# ${SKILL}

TODO: replace this body with the actual agent instructions.

Suggested structure:
1. State the user's goal in one sentence.
2. List the tools/MCP servers this skill uses.
3. Outline the steps the agent should take.
4. Specify the output format.
EOF
}

# ---- Optional agent body -----------------------------------------------
write_agent_md() {
  local path="$1"
  local agent_name="$2"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
name: $agent_name
description: TODO — describe when this agent activates and what it does. Be specific so the model knows the trigger.
---

You are the $agent_name agent. TODO: replace with the agent's persona, goals, and constraints.
EOF
}

# ---- Claude Code plugin ------------------------------------------------
mkdir -p "$CLAUDE_DIR/.claude-plugin" "$CLAUDE_DIR/skills/$SKILL"
cat > "$CLAUDE_DIR/.claude-plugin/plugin.json" <<EOF
{
  "name": "$NAME",
  "description": "$DESC",
  "version": "0.1.0",
  "author": {
    "name": "$AUTHOR_NAME",
    "url": "$AUTHOR_URL"
  },
  "homepage": "https://github.com/hoangsonww/AI-News-Briefing",
  "repository": {
    "type": "git",
    "url": "https://github.com/hoangsonww/AI-News-Briefing.git"
  },
  "license": "MIT",
  "keywords": [],
  "categories": []
}
EOF
write_skill_md "$CLAUDE_DIR/skills/$SKILL/SKILL.md"

# ---- Codex plugin ------------------------------------------------------
mkdir -p "$CODEX_DIR/.codex-plugin" "$CODEX_DIR/skills/$SKILL"
cat > "$CODEX_DIR/.codex-plugin/plugin.json" <<EOF
{
  "name": "${NAME}-codex",
  "version": "0.1.0",
  "description": "$DESC",
  "author": {
    "name": "$AUTHOR_NAME"
  },
  "skills": "./skills/",
  "agents": "./agents/",
  "interface": {
    "displayName": "$NAME",
    "shortDescription": "$DESC",
    "longDescription": "$DESC",
    "developerName": "$AUTHOR_NAME",
    "category": "Productivity",
    "capabilities": ["Read", "Write"]
  }
}
EOF
write_skill_md "$CODEX_DIR/skills/$SKILL/SKILL.md"

# ---- Gemini extension --------------------------------------------------
mkdir -p "$GEMINI_DIR/skills/$SKILL"
cat > "$GEMINI_DIR/gemini-extension.json" <<EOF
{
  "name": "$NAME",
  "version": "0.1.0",
  "description": "$DESC",
  "author": {
    "name": "$AUTHOR_NAME"
  },
  "license": "MIT",
  "contextFileName": "GEMINI.md"
}
EOF
cat > "$GEMINI_DIR/GEMINI.md" <<EOF
# $NAME

You are the $NAME agent. TODO: replace with the system instructions Gemini should load on every session.

## Available skills

- $SKILL — TODO describe.
EOF
write_skill_md "$GEMINI_DIR/skills/$SKILL/SKILL.md"

# ---- Optional agent ---------------------------------------------------
if [ -n "$AGENT" ]; then
  if ! printf '%s' "$AGENT" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "WARN: --with-agent name should be kebab-case. Got: $AGENT" >&2
  fi
  write_agent_md "$CLAUDE_DIR/agents/$AGENT.md" "$AGENT"
  write_agent_md "$CODEX_DIR/agents/$AGENT.md"  "$AGENT"
  write_agent_md "$GEMINI_DIR/agents/$AGENT.md" "$AGENT"
fi

echo ""
echo "Scaffolded $NAME across 3 platforms:"
echo "  $CLAUDE_DIR/"
echo "  $CODEX_DIR/"
echo "  $GEMINI_DIR/"
echo ""
echo "Next steps:"
echo "  1. Edit skills/$SKILL/SKILL.md in each platform dir."
[ -n "$AGENT" ] && echo "  1b. Edit agents/$AGENT.md (3 copies)."
echo "  2. Paste this into .claude-plugin/marketplace.json:"
cat <<JSON

    {
      "name": "$NAME",
      "source": "./$CLAUDE_DIR",
      "description": "$DESC",
      "category": "research",
      "tags": []
    },

JSON
echo "  3. Run: bash scripts/plugin-validate.sh"
echo ""
