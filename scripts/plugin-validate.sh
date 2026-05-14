#!/bin/bash
set -euo pipefail

# plugin-validate.sh — Lint every plugin/extension manifest, marketplace entry,
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

# Delegate the heavy lifting to inline Python — same checks I'd write in awk would be
# painful, and python3 is already a project dep (eval harness, scripts/teams-to-slack.py).
python3 - "$STRICT" "$JSON_OUT" <<'PY'
import sys, os, re, json, glob

STRICT = sys.argv[1] == "1"
JSON_OUT = sys.argv[2] == "1"

errors, warnings = [], []

def ok(label):
    if not JSON_OUT:
        print(f"  \033[32mOK  \033[0m {label}")

def err(label, why):
    errors.append({"label": label, "reason": why})
    if not JSON_OUT:
        print(f"  \033[31mFAIL\033[0m {label}: {why}")

def warn(label, why):
    warnings.append({"label": label, "reason": why})
    if not JSON_OUT:
        print(f"  \033[33mWARN\033[0m {label}: {why}")

def section(title):
    if not JSON_OUT:
        print(f"\n  \033[1m{title}\033[0m\n  " + "=" * len(title))

# ---- JSON manifests -----------------------------------------------------
section("JSON manifests")
manifests = [
    (".claude-plugin/marketplace.json",                            "marketplace"),
    ("claude-plugins/ai-news-briefing/.claude-plugin/plugin.json", "claude plugin"),
    ("claude-plugins/ai-news-briefing/hooks/hooks.json",           "claude hooks"),
    ("claude-plugins/ai-news-briefing/.mcp.json",                  "claude mcp"),
    ("plugins/ai-news-briefing-codex/.codex-plugin/plugin.json",   "codex plugin"),
    ("plugins/ai-news-briefing-codex/.mcp.json",                   "codex mcp"),
    ("gemini-extensions/ai-news-briefing/gemini-extension.json",   "gemini extension"),
]
for path, label in manifests:
    if not os.path.exists(path):
        err(f"{label} ({path})", "file missing"); continue
    try:
        json.load(open(path))
        ok(f"{label}: {path}")
    except Exception as e:
        err(f"{label} ({path})", f"invalid JSON: {e}")

# ---- Marketplace schema -------------------------------------------------
section("Marketplace schema")
try:
    mp = json.load(open(".claude-plugin/marketplace.json"))
    for k in ("name", "owner", "plugins"):
        if k not in mp:
            err("marketplace", f"missing required field: {k}")
    name = mp.get("name", "")
    if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
        err("marketplace.name", f"not kebab-case: {name!r}")
    if "owner" in mp and "name" not in mp["owner"]:
        err("marketplace.owner", "missing .name (required)")
    seen = set()
    for p in mp.get("plugins", []):
        n = p.get("name", "<missing>")
        if n in seen:
            err(f"plugin '{n}'", "duplicate plugin name in marketplace")
        seen.add(n)
        if "source" not in p:
            err(f"plugin '{n}'", "missing 'source' field")
            continue
        src = p["source"]
        if isinstance(src, str):
            if not src.startswith("./"):
                err(f"plugin '{n}'", f"source must start with ./: {src!r}")
            path = src.lstrip("./")
            if not os.path.isdir(path):
                err(f"plugin '{n}'", f"source dir does not exist: {path}")
            else:
                manifest = os.path.join(path, ".claude-plugin", "plugin.json")
                if not os.path.isfile(manifest):
                    err(f"plugin '{n}'", f"no plugin.json at {manifest}")
                else:
                    try:
                        pj = json.load(open(manifest))
                        if pj.get("name") != n:
                            warn(f"plugin '{n}'", f"plugin.json name={pj.get('name')!r} differs from marketplace name")
                    except Exception as e:
                        err(f"plugin '{n}'", f"plugin.json invalid: {e}")
    if not errors:
        ok(f"marketplace ({len(mp.get('plugins', []))} plugins, all resolve)")
except FileNotFoundError:
    err("marketplace", "file missing")

# ---- Plugin manifests (every claude-plugins/*) --------------------------
section("Plugin manifests (claude-plugins/*)")
for mf in sorted(glob.glob("claude-plugins/*/.claude-plugin/plugin.json")):
    try:
        p = json.load(open(mf))
        name = p.get("name", "")
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
            err(mf, f"name not kebab-case: {name!r}")
        if not p.get("description"):
            warn(mf, "missing description")
        if not p.get("version"):
            warn(mf, "missing version (will fall back to git SHA)")
        ok(f"{name} ({mf})")
    except Exception as e:
        err(mf, f"invalid JSON: {e}")

# ---- SKILL.md frontmatter -----------------------------------------------
section("SKILL.md frontmatter")
skill_count = 0
for root in ("claude-plugins/ai-news-briefing",
             "plugins/ai-news-briefing-codex",
             "gemini-extensions/ai-news-briefing"):
    for skill in sorted(glob.glob(f"{root}/skills/*/SKILL.md")):
        skill_count += 1
        c = open(skill).read()
        m = re.match(r"^---\n(.*?)\n---\n", c, re.DOTALL)
        if not m:
            err(skill, "no YAML frontmatter")
            continue
        fm = m.group(1)
        if "description:" not in fm:
            err(skill, "missing 'description'")
        # Skill name must be kebab-case (its parent directory)
        dirname = os.path.basename(os.path.dirname(skill))
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", dirname):
            err(skill, f"directory name not kebab-case: {dirname}")
ok(f"{skill_count} SKILL.md files checked")

# ---- Agent frontmatter --------------------------------------------------
section("Agent frontmatter")
agent_count = 0
for root in ("claude-plugins/ai-news-briefing",
             "plugins/ai-news-briefing-codex",
             "gemini-extensions/ai-news-briefing"):
    for agent in sorted(glob.glob(f"{root}/agents/*.md")):
        agent_count += 1
        c = open(agent).read()
        m = re.match(r"^---\n(.*?)\n---\n", c, re.DOTALL)
        if not m:
            err(agent, "no YAML frontmatter")
            continue
        fm = m.group(1)
        if "name:" not in fm:
            err(agent, "missing 'name'")
        if "description:" not in fm:
            err(agent, "missing 'description'")
ok(f"{agent_count} agent files checked")

# ---- Hook schema --------------------------------------------------------
section("hooks.json")
try:
    h = json.load(open("claude-plugins/ai-news-briefing/hooks/hooks.json"))
    valid_events = {"PreToolUse", "PostToolUse", "UserPromptSubmit",
                    "SessionStart", "SessionEnd", "Notification", "Stop"}
    valid_types = {"command", "http", "mcp_tool", "prompt", "agent"}
    for event, entries in h.get("hooks", {}).items():
        if event not in valid_events:
            warn("hooks", f"unknown event {event!r}")
        for entry in entries:
            for hk in entry.get("hooks", []):
                t = hk.get("type")
                if t not in valid_types:
                    err("hooks", f"event {event}: bad hook type {t!r}")
                if t == "command" and not hk.get("command"):
                    err("hooks", f"event {event}: command hook missing 'command'")
    ok("hooks schema valid")
except FileNotFoundError:
    warn("hooks", "no hooks.json (optional)")

# ---- Cross-platform parity ---------------------------------------------
section("Cross-platform parity (claude / codex / gemini)")
plats = {
    "claude": "claude-plugins/ai-news-briefing",
    "codex":  "plugins/ai-news-briefing-codex",
    "gemini": "gemini-extensions/ai-news-briefing",
}
for kind in ("skills", "agents"):
    sets = {}
    for k, p in plats.items():
        if kind == "skills":
            sets[k] = {d for d in os.listdir(f"{p}/{kind}")
                       if os.path.isfile(f"{p}/{kind}/{d}/SKILL.md")} if os.path.isdir(f"{p}/{kind}") else set()
        else:
            sets[k] = {os.path.basename(a) for a in glob.glob(f"{p}/{kind}/*.md")}
    ref = sets["claude"]
    for other in ("codex", "gemini"):
        diff = ref ^ sets[other]
        if diff:
            err(f"parity:{kind}", f"claude vs {other} differ: {sorted(diff)}")
    ok(f"{kind}: {len(ref)} entries match across all 3 platforms")

# ---- Summary ------------------------------------------------------------
if JSON_OUT:
    print(json.dumps({"errors": errors, "warnings": warnings,
                      "ok": len(errors) == 0}, indent=2))
else:
    print()
    print(f"  \033[1mSummary\033[0m: \033[31m{len(errors)} errors\033[0m, \033[33m{len(warnings)} warnings\033[0m")

if errors or (STRICT and warnings):
    sys.exit(1)
PY
