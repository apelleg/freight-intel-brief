#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# plugin-validate.ps1 -- Lint every plugin/extension manifest, marketplace entry,
# SKILL.md frontmatter, and agent file. Non-zero exit on any error.
#
# Usage:
#   .\scripts\plugin-validate.ps1
#   .\scripts\plugin-validate.ps1 -Strict     # also fail on warnings
#   .\scripts\plugin-validate.ps1 -Json       # emit machine-readable report

param(
    [switch]$Strict,
    [switch]$Json
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
Set-Location $ScriptDir

# Windows GitHub runners ship `python` (not `python3`). Probe both.
$pyExe = $null
foreach ($candidate in @("python3", "python", "py")) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $pyExe = $candidate
        break
    }
}
if (-not $pyExe) {
    Write-Host "python3 / python / py required (also used by the eval harness)." -ForegroundColor Red
    exit 1
}

# Delegate to the same Python implementation the bash version uses for parity.
$strictArg = if ($Strict) { "1" } else { "0" }
$jsonArg   = if ($Json)   { "1" } else { "0" }

$py = @'
import sys, os, re, json, glob

STRICT = sys.argv[1] == "1"
JSON_OUT = sys.argv[2] == "1"
errors, warnings = [], []

def _open(p):
    return open(p, encoding="utf-8")

def ok(label):
    if not JSON_OUT: print(f"  OK   {label}")
def err(label, why):
    errors.append({"label": label, "reason": why})
    if not JSON_OUT: print(f"  FAIL {label}: {why}")
def warn(label, why):
    warnings.append({"label": label, "reason": why})
    if not JSON_OUT: print(f"  WARN {label}: {why}")
def section(t):
    if not JSON_OUT: print(f"\n  {t}\n  " + "=" * len(t))

section("JSON manifests")
for path, label in [
    (".claude-plugin/marketplace.json", "marketplace"),
    ("claude-plugins/ai-news-briefing/.claude-plugin/plugin.json", "claude plugin"),
    ("claude-plugins/ai-news-briefing/hooks/hooks.json", "claude hooks"),
    ("claude-plugins/ai-news-briefing/.mcp.json", "claude mcp"),
    ("plugins/ai-news-briefing-codex/.codex-plugin/plugin.json", "codex plugin"),
    ("plugins/ai-news-briefing-codex/.mcp.json", "codex mcp"),
    ("gemini-extensions/ai-news-briefing/gemini-extension.json", "gemini extension"),
]:
    if not os.path.exists(path):
        err(f"{label} ({path})", "file missing"); continue
    try: json.load(_open(path)); ok(f"{label}: {path}")
    except Exception as e: err(f"{label} ({path})", f"invalid JSON: {e}")

section("Marketplace schema")
try:
    mp = json.load(_open(".claude-plugin/marketplace.json"))
    for k in ("name", "owner", "plugins"):
        if k not in mp: err("marketplace", f"missing required field: {k}")
    name = mp.get("name", "")
    if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
        err("marketplace.name", f"not kebab-case: {name!r}")
    if "owner" in mp and "name" not in mp["owner"]:
        err("marketplace.owner", "missing .name")
    seen = set()
    for p in mp.get("plugins", []):
        n = p.get("name", "<missing>")
        if n in seen: err(f"plugin '{n}'", "duplicate name")
        seen.add(n)
        if "source" not in p: err(f"plugin '{n}'", "missing 'source'"); continue
        src = p["source"]
        if isinstance(src, str):
            if not src.startswith("./"): err(f"plugin '{n}'", f"source must start with ./: {src!r}")
            path = src.lstrip("./")
            if not os.path.isdir(path): err(f"plugin '{n}'", f"dir missing: {path}")
            else:
                m = os.path.join(path, ".claude-plugin", "plugin.json")
                if not os.path.isfile(m): err(f"plugin '{n}'", f"no plugin.json at {m}")
                else:
                    try:
                        pj = json.load(_open(m))
                        if pj.get("name") != n: warn(f"plugin '{n}'", f"plugin.json name={pj.get('name')!r} differs")
                    except Exception as e: err(f"plugin '{n}'", f"invalid JSON: {e}")
    if not errors: ok(f"marketplace ({len(mp.get('plugins', []))} plugins resolve)")
except FileNotFoundError: err("marketplace", "missing")

section("Plugin manifests")
for mf in sorted(glob.glob("claude-plugins/*/.claude-plugin/plugin.json")):
    try:
        p = json.load(_open(mf))
        name = p.get("name", "")
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", name):
            err(mf, f"name not kebab-case: {name!r}")
        if not p.get("description"): warn(mf, "missing description")
        if not p.get("version"): warn(mf, "missing version")
        ok(f"{name} ({mf})")
    except Exception as e: err(mf, f"invalid JSON: {e}")

section("SKILL.md frontmatter")
n_s = 0
for root in ("claude-plugins/ai-news-briefing", "plugins/ai-news-briefing-codex", "gemini-extensions/ai-news-briefing"):
    for skill in sorted(glob.glob(f"{root}/skills/*/SKILL.md")):
        n_s += 1
        c = _open(skill).read()
        m = re.match(r"^---\n(.*?)\n---\n", c, re.DOTALL)
        if not m: err(skill, "no frontmatter"); continue
        if "description:" not in m.group(1): err(skill, "missing description")
        d = os.path.basename(os.path.dirname(skill))
        if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", d): err(skill, f"dir not kebab-case: {d}")
ok(f"{n_s} SKILL.md files checked")

section("Agent frontmatter")
n_a = 0
for root in ("claude-plugins/ai-news-briefing", "plugins/ai-news-briefing-codex", "gemini-extensions/ai-news-briefing"):
    for agent in sorted(glob.glob(f"{root}/agents/*.md")):
        n_a += 1
        c = _open(agent).read()
        m = re.match(r"^---\n(.*?)\n---\n", c, re.DOTALL)
        if not m: err(agent, "no frontmatter"); continue
        fm = m.group(1)
        if "name:" not in fm: err(agent, "missing name")
        if "description:" not in fm: err(agent, "missing description")
ok(f"{n_a} agent files checked")

section("hooks.json")
try:
    h = json.load(_open("claude-plugins/ai-news-briefing/hooks/hooks.json"))
    valid_events = {"PreToolUse","PostToolUse","UserPromptSubmit","SessionStart","SessionEnd","Notification","Stop"}
    valid_types = {"command","http","mcp_tool","prompt","agent"}
    for event, entries in h.get("hooks", {}).items():
        if event not in valid_events: warn("hooks", f"unknown event {event!r}")
        for e in entries:
            for hk in e.get("hooks", []):
                if hk.get("type") not in valid_types: err("hooks", f"{event}: bad type {hk.get('type')!r}")
                if hk.get("type") == "command" and not hk.get("command"):
                    err("hooks", f"{event}: command hook missing 'command'")
    ok("hooks schema valid")
except FileNotFoundError: warn("hooks", "no hooks.json (optional)")

section("Cross-platform parity")
plats = {
    "claude": "claude-plugins/ai-news-briefing",
    "codex":  "plugins/ai-news-briefing-codex",
    "gemini": "gemini-extensions/ai-news-briefing",
}
for kind in ("skills","agents"):
    sets = {}
    for k, p in plats.items():
        if kind == "skills":
            sets[k] = {d for d in os.listdir(f"{p}/{kind}") if os.path.isfile(f"{p}/{kind}/{d}/SKILL.md")} if os.path.isdir(f"{p}/{kind}") else set()
        else:
            sets[k] = {os.path.basename(a) for a in glob.glob(f"{p}/{kind}/*.md")}
    ref = sets["claude"]
    for o in ("codex","gemini"):
        diff = ref ^ sets[o]
        if diff: err(f"parity:{kind}", f"claude vs {o}: {sorted(diff)}")
    ok(f"{kind}: {len(ref)} entries match across all 3 platforms")

if JSON_OUT:
    print(json.dumps({"errors": errors, "warnings": warnings, "ok": len(errors) == 0}, indent=2))
else:
    print(f"\n  Summary: {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors or (STRICT and warnings) else 0)
'@

$tmp = New-TemporaryFile
try {
    [System.IO.File]::WriteAllText($tmp.FullName, $py)
    & $pyExe $tmp.FullName $strictArg $jsonArg
    $rc = $LASTEXITCODE
} finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
exit $rc
