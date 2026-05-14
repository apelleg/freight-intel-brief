#!/bin/bash
# Tests for the new utility scripts (eval-summary, eval-watch, eval-compare,
# plugin-validate, scaffold-plugin). Non-blocking: no webhooks, no Claude calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

if [[ -t 1 ]]; then
  B='\033[1m' D='\033[2m' R='\033[0m'
  GRN='\033[32m' RED='\033[31m' CYN='\033[36m' YLW='\033[33m' MAG='\033[35m'
else
  B='' D='' R='' GRN='' RED='' CYN='' YLW='' MAG=''
fi

pass() { PASS=$((PASS + 1)); echo -e "  ${GRN}PASS${R}  $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${R}  $1"; }
section() { echo ""; echo -e "  ${CYN}${B}$1${R}"; }
assert_contains() {
  if echo "$1" | grep -qF -- "$2"; then pass "$3"; else fail "$3 ${D}(missing '$2')${R}"; fi
}
assert_not_contains() {
  if echo "$1" | grep -qF -- "$2"; then fail "$3 ${D}(unexpected '$2')${R}"; else pass "$3"; fi
}
assert_exit() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then pass "$label"; else fail "$label ${D}(exit $actual, expected $expected)${R}"; fi
}

NEW_SCRIPTS=(eval-summary eval-watch eval-compare plugin-validate scaffold-plugin)

echo ""
echo -e "  ${MAG}${B}================================================${R}"
echo -e "  ${MAG}${B}  utility scripts tests (eval + plugin tooling)${R}"
echo -e "  ${MAG}${B}================================================${R}"

# -- Existence (sh + ps1 pairs) ---------------------------------------------
section "Script existence (sh + ps1 pairs)"
for name in "${NEW_SCRIPTS[@]}"; do
  for ext in sh ps1; do
    f="scripts/$name.$ext"
    [ -f "$SCRIPT_DIR/$f" ] && pass "$f exists" || fail "$f exists"
  done
done

# -- Bash syntax -----------------------------------------------------------
section "Bash syntax"
for name in "${NEW_SCRIPTS[@]}"; do
  if bash -n "$SCRIPT_DIR/scripts/$name.sh" 2>/dev/null; then
    pass "scripts/$name.sh valid bash syntax"
  else
    fail "scripts/$name.sh valid bash syntax"
  fi
done

# -- Strict mode (set -euo pipefail) ---------------------------------------
section "Strict mode header"
for name in "${NEW_SCRIPTS[@]}"; do
  HEADER="$(head -5 "$SCRIPT_DIR/scripts/$name.sh")"
  assert_contains "$HEADER" "set -euo pipefail" "scripts/$name.sh uses set -euo pipefail"
done

# -- PowerShell strict mode header ---------------------------------------
section "PowerShell strict mode header"
# Whole-file check; Set-StrictMode lives below `param(...)` in these scripts
# because the PS7 parser requires param to be the first executable statement.
for name in "${NEW_SCRIPTS[@]}"; do
  BODY="$(cat "$SCRIPT_DIR/scripts/$name.ps1")"
  assert_contains "$BODY" "Set-StrictMode" "scripts/$name.ps1 uses Set-StrictMode"
done

# -- --help exits 0 with usage ---------------------------------------------
section "--help flag"
for name in "${NEW_SCRIPTS[@]}"; do
  OUT="$(bash "$SCRIPT_DIR/scripts/$name.sh" --help 2>&1 || true)"
  RC=$?
  # help text should mention "Usage:"
  assert_contains "$OUT" "Usage:" "scripts/$name.sh --help shows Usage"
done

# -- Missing args fail cleanly ---------------------------------------------
section "Argument validation"
OUT="$(bash "$SCRIPT_DIR/scripts/scaffold-plugin.sh" 2>&1)"; RC=$?
assert_exit "$RC" "2" "scaffold-plugin.sh without args exits 2"
assert_contains "$OUT" "--name" "scaffold-plugin.sh error mentions --name"

OUT="$(bash "$SCRIPT_DIR/scripts/scaffold-plugin.sh" --name InvalidCase --description test 2>&1)"; RC=$?
assert_exit "$RC" "2" "scaffold-plugin.sh rejects non-kebab name"
assert_contains "$OUT" "kebab-case" "scaffold-plugin.sh error mentions kebab-case"

OUT="$(bash "$SCRIPT_DIR/scripts/eval-compare.sh" 2>&1)"; RC=$?
assert_exit "$RC" "2" "eval-compare.sh without args exits 2"
assert_contains "$OUT" "--a" "eval-compare.sh error mentions --a"

# -- scaffold-plugin --dry-run -----------------------------------
section "scaffold-plugin dry-run"
OUT="$(bash "$SCRIPT_DIR/scripts/scaffold-plugin.sh" --name test-scaffold-dry --description "dry-run test" --with-agent reviewer --dry-run 2>&1)"
RC=$?
assert_exit "$RC" "0" "scaffold-plugin --dry-run exits 0"
assert_contains "$OUT" "claude-plugins/test-scaffold-dry/.claude-plugin/plugin.json" "dry-run lists claude plugin path"
assert_contains "$OUT" "plugins/test-scaffold-dry-codex/.codex-plugin/plugin.json" "dry-run lists codex plugin path"
assert_contains "$OUT" "gemini-extensions/test-scaffold-dry/gemini-extension.json" "dry-run lists gemini extension path"
assert_contains "$OUT" "agents/reviewer.md" "dry-run includes --with-agent reviewer.md"
assert_contains "$OUT" "no files written" "dry-run reports it did not write"
# Real check: nothing was actually written
[ ! -d "$SCRIPT_DIR/claude-plugins/test-scaffold-dry" ] && pass "dry-run did not create claude dir" || fail "dry-run did not create claude dir"
[ ! -d "$SCRIPT_DIR/plugins/test-scaffold-dry-codex" ] && pass "dry-run did not create codex dir" || fail "dry-run did not create codex dir"
[ ! -d "$SCRIPT_DIR/gemini-extensions/test-scaffold-dry" ] && pass "dry-run did not create gemini dir" || fail "dry-run did not create gemini dir"

# -- scaffold-plugin actually creates valid files ---------------------------
section "scaffold-plugin real write"
SCAFFOLD_NAME="test-utility-scaffold-$$"
OUT="$(cd "$SCRIPT_DIR" && bash scripts/scaffold-plugin.sh --name "$SCAFFOLD_NAME" --description "scaffold integration test" --with-agent reviewer 2>&1)"
RC=$?
assert_exit "$RC" "0" "scaffold-plugin real run exits 0"

CLAUDE_DIR="$SCRIPT_DIR/claude-plugins/$SCAFFOLD_NAME"
CODEX_DIR="$SCRIPT_DIR/plugins/${SCAFFOLD_NAME}-codex"
GEMINI_DIR="$SCRIPT_DIR/gemini-extensions/$SCAFFOLD_NAME"

[ -f "$CLAUDE_DIR/.claude-plugin/plugin.json" ] && pass "scaffold created claude plugin.json" || fail "scaffold created claude plugin.json"
[ -f "$CODEX_DIR/.codex-plugin/plugin.json" ] && pass "scaffold created codex plugin.json" || fail "scaffold created codex plugin.json"
[ -f "$GEMINI_DIR/gemini-extension.json" ] && pass "scaffold created gemini extension.json" || fail "scaffold created gemini extension.json"
[ -f "$GEMINI_DIR/GEMINI.md" ] && pass "scaffold created GEMINI.md" || fail "scaffold created GEMINI.md"
[ -f "$CLAUDE_DIR/skills/default-skill/SKILL.md" ] && pass "scaffold created SKILL.md" || fail "scaffold created SKILL.md"
[ -f "$CLAUDE_DIR/agents/reviewer.md" ] && pass "scaffold created agent file" || fail "scaffold created agent file"

# Validate the scaffolded JSON parses
if python3 -c "import json; json.load(open('$CLAUDE_DIR/.claude-plugin/plugin.json'))" 2>/dev/null; then
  pass "scaffolded claude plugin.json is valid JSON"
else
  fail "scaffolded claude plugin.json is valid JSON"
fi
if python3 -c "import json; json.load(open('$CODEX_DIR/.codex-plugin/plugin.json'))" 2>/dev/null; then
  pass "scaffolded codex plugin.json is valid JSON"
else
  fail "scaffolded codex plugin.json is valid JSON"
fi
if python3 -c "import json; json.load(open('$GEMINI_DIR/gemini-extension.json'))" 2>/dev/null; then
  pass "scaffolded gemini extension is valid JSON"
else
  fail "scaffolded gemini extension is valid JSON"
fi

# Refuses to overwrite existing scaffolds
OUT="$(cd "$SCRIPT_DIR" && bash scripts/scaffold-plugin.sh --name "$SCAFFOLD_NAME" --description "duplicate" 2>&1)"; RC=$?
assert_exit "$RC" "1" "scaffold-plugin refuses to overwrite existing dir"
assert_contains "$OUT" "already exists" "scaffold-plugin overwrite error mentions 'already exists'"

# Cleanup the scaffolded plugin
rm -rf "$CLAUDE_DIR" "$CODEX_DIR" "$GEMINI_DIR"

# -- plugin-validate runs against current repo -----------------------------
section "plugin-validate against current repo"
OUT="$(cd "$SCRIPT_DIR" && bash scripts/plugin-validate.sh 2>&1)"; RC=$?
assert_exit "$RC" "0" "plugin-validate exits 0 on current repo"
assert_contains "$OUT" "ai-news-briefing" "plugin-validate reports ai-news-briefing plugin"
assert_contains "$OUT" "0 errors" "plugin-validate reports 0 errors"

# JSON mode produces valid JSON
OUT="$(cd "$SCRIPT_DIR" && bash scripts/plugin-validate.sh --json 2>&1)"; RC=$?
assert_exit "$RC" "0" "plugin-validate --json exits 0"
if echo "$OUT" | python3 -c "import json, sys; d = json.load(sys.stdin); sys.exit(0 if d.get('ok') is True else 1)" 2>/dev/null; then
  pass "plugin-validate --json emits parseable JSON with ok:true"
else
  fail "plugin-validate --json emits parseable JSON with ok:true"
fi

# -- eval-summary against a temp DB ----------------------------------------
section "eval-summary against temp DB"
if command -v sqlite3 >/dev/null 2>&1; then
  TMP_DIR="$(mktemp -d -t test-eval-summary.XXXXXX)"
  TMP_DB="$TMP_DIR/store.sqlite"
  sqlite3 "$TMP_DB" < "$SCRIPT_DIR/eval/schema.sql"
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-01','v1','test-judge','2026-04-01T00:00:00Z',4,4,4,5,4,4.2,'good','raw');"
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-02','v1','test-judge','2026-04-02T00:00:00Z',2,3,3,3,3,2.7,'bad','raw');"
  # Symlink temp DB into eval/store.sqlite would clobber real store. Instead copy script
  # behavior by overriding DB path: the script computes DB from SCRIPT_DIR, so we copy
  # the script-callable layout into a fake project root.
  FAKE_ROOT="$TMP_DIR/proj"
  mkdir -p "$FAKE_ROOT/scripts" "$FAKE_ROOT/eval"
  cp "$SCRIPT_DIR/scripts/eval-summary.sh" "$FAKE_ROOT/scripts/"
  cp "$SCRIPT_DIR/eval/drift.py" "$SCRIPT_DIR/eval/store.py" "$SCRIPT_DIR/eval/schema.sql" "$FAKE_ROOT/eval/"
  cp "$TMP_DB" "$FAKE_ROOT/eval/store.sqlite"
  OUT="$(bash "$FAKE_ROOT/scripts/eval-summary.sh" --judge test-judge 2>&1)"; RC=$?
  assert_exit "$RC" "0" "eval-summary against seeded DB exits 0"
  assert_contains "$OUT" "test-judge" "eval-summary shows judge name"
  assert_contains "$OUT" "rows matched:          2" "eval-summary shows row count"
  assert_contains "$OUT" "2026-04-02" "eval-summary lists the bad card"
  assert_contains "$OUT" "below 3.0" "eval-summary flags card below gate"
  # --judges mode
  OUT="$(bash "$FAKE_ROOT/scripts/eval-summary.sh" --judges 2>&1)"; RC=$?
  assert_exit "$RC" "0" "eval-summary --judges exits 0"
  assert_contains "$OUT" "test-judge" "eval-summary --judges lists test-judge"
  rm -rf "$TMP_DIR"
else
  echo -e "  ${YLW}SKIP${R}  eval-summary tests (sqlite3 not on PATH)"
fi

# -- eval-compare against temp DB ------------------------------------------
section "eval-compare against temp DB"
if command -v sqlite3 >/dev/null 2>&1; then
  TMP_DIR="$(mktemp -d -t test-eval-compare.XXXXXX)"
  FAKE_ROOT="$TMP_DIR/proj"
  mkdir -p "$FAKE_ROOT/scripts" "$FAKE_ROOT/eval"
  cp "$SCRIPT_DIR/scripts/eval-compare.sh" "$FAKE_ROOT/scripts/"
  cp "$SCRIPT_DIR/eval/schema.sql" "$FAKE_ROOT/eval/"
  TMP_DB="$FAKE_ROOT/eval/store.sqlite"
  sqlite3 "$TMP_DB" < "$SCRIPT_DIR/eval/schema.sql"
  # Two judges, two overlapping dates
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-01','v1','judge-a','t',4,4,4,5,4,4.2,'a1','r');"
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-02','v1','judge-a','t',3,3,3,3,3,3.0,'a2','r');"
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-01','v1','judge-b','t',4,4,4,5,4,4.2,'b1','r');"
  sqlite3 "$TMP_DB" "INSERT INTO eval_runs VALUES ('2026-04-02','v1','judge-b','t',1,1,1,1,1,1.0,'b2','r');"
  OUT="$(bash "$FAKE_ROOT/scripts/eval-compare.sh" --a judge-a --b judge-b --threshold 1.0 2>&1)"; RC=$?
  assert_exit "$RC" "3" "eval-compare flags large delta and exits 3"
  assert_contains "$OUT" "2026-04-02" "eval-compare lists overlapping date"
  assert_contains "$OUT" "FLAGGED" "eval-compare flags row above threshold"
  # Same judge compared with itself = no deltas
  OUT="$(bash "$FAKE_ROOT/scripts/eval-compare.sh" --a judge-a --b judge-a --threshold 0.1 2>&1)"; RC=$?
  assert_exit "$RC" "0" "eval-compare A=B exits 0"
  assert_contains "$OUT" "within" "eval-compare A=B reports within tolerance"
  rm -rf "$TMP_DIR"
else
  echo -e "  ${YLW}SKIP${R}  eval-compare tests (sqlite3 not on PATH)"
fi

# -- Makefile targets exist ------------------------------------------------
section "Makefile targets"
for tgt in eval-summary eval-watch eval-compare plugin-validate scaffold-plugin; do
  if grep -qE "^${tgt}:" "$SCRIPT_DIR/Makefile"; then
    pass "Makefile has ${tgt} target"
  else
    fail "Makefile has ${tgt} target"
  fi
done

# -- Summary ---------------------------------------------------------------
echo ""
echo -e "  ${B}================================================${R}"
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "  ${GRN}${B}ALL PASSED  $PASS tests${R}"
else
  echo -e "  ${RED}${B}$FAIL of $((PASS + FAIL)) failed${R}"
fi
echo -e "  ${B}================================================${R}"

exit "$FAIL"
