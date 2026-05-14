# Test Suite

247 non-blocking tests across bash and PowerShell covering the daily briefing, custom brief, notification pipeline, Obsidian publishing, and cross-platform portability. No external services are called -- no Claude API, no webhooks, no Notion, no vault writes.

---

## Architecture

```mermaid
flowchart TD
    classDef runner fill:#2a2440,stroke:#8b7ad4,color:#e4e4ef
    classDef bash   fill:#1e3a5f,stroke:#5b8dd8,color:#d4e4f8
    classDef pwsh   fill:#3a2a1e,stroke:#d49b5b,color:#f5e6c8
    classDef py     fill:#1e3a2f,stroke:#5bd49b,color:#d4f8e2
    classDef legacy fill:#2a2030,stroke:#6a5a7a,color:#a0a0b8

    ROOT["tests/"]:::runner

    subgraph BASH["Bash · macOS / Linux / Git Bash"]
        direction TB
        BR["run-all.sh"]:::runner
        T1["test-custom-brief.sh<br/>args · template · prompt · skill"]:::bash
        T2["test-daily-brief.sh<br/>steps · 9 topics · changelogs · dedup"]:::bash
        T3["test-notifications.sh<br/>card JSON · converter · errors"]:::bash
        T4["test-obsidian.sh<br/>publish · wikilinks · vault sim"]:::bash
        T5["test-portability.sh<br/>bash 3.2 · awk · date · ANSI"]:::bash
        T6["test-utility-scripts.sh<br/>eval-* · plugin-* · scaffold"]:::bash
        BR --> T1 --> T2 --> T3 --> T4 --> T5 --> T6
    end

    subgraph PWSH["PowerShell · Windows"]
        direction TB
        PR["run-all.ps1"]:::runner
        H["_helpers.ps1<br/>(dot-sourced by every suite)"]:::pwsh
        P1["test-custom-brief.ps1"]:::pwsh
        P2["test-daily-brief.ps1"]:::pwsh
        P3["test-notifications.ps1"]:::pwsh
        P4["test-obsidian.ps1"]:::pwsh
        P5["test-portability.ps1<br/>(ps1 parse · BOM · Makefile routing)"]:::pwsh
        P6["test-utility-scripts.ps1"]:::pwsh
        PS_LEGACY["test-all.ps1<br/>(legacy monolith)"]:::legacy
        PR --> P1 --> P2 --> P3 --> P4 --> P5 --> P6
        H -.-> P1
        H -.-> P2
        H -.-> P3
        H -.-> P4
        H -.-> P5
        H -.-> P6
    end

    subgraph PYTEST["Python · cross-platform"]
        direction TB
        PY_RUN["make eval-test"]:::runner
        PY_SUITE["eval/tests/test_harness.py<br/>extract · judge · store · drift · report"]:::py
        PY_RUN --> PY_SUITE
    end

    ROOT --> BASH
    BASH --> PWSH
    PWSH --> PYTEST
```

---

## Running Tests

### All bash tests (macOS / Linux / Git Bash)

```bash
bash tests/run-all.sh
```

### Individual bash suites

```bash
bash tests/test-custom-brief.sh     # Custom brief: args, template, prompt, skill
bash tests/test-daily-brief.sh      # Daily brief: prompt, topics, changelogs, scripts
bash tests/test-notifications.sh    # Notifications: cards, converter, error handling
bash tests/test-portability.sh      # Portability: bash version, awk, date, colors
bash tests/test-utility-scripts.sh  # Utility scripts: eval-* + plugin-* + scaffold-plugin
```

### PowerShell (Windows)

Per-suite mirrors of the bash files, plus a `run-all.ps1` runner that auto-discovers them:

```powershell
# Run every PowerShell suite
powershell -ExecutionPolicy Bypass -File tests\run-all.ps1

# Run individual suites
powershell -ExecutionPolicy Bypass -File tests\test-custom-brief.ps1
powershell -ExecutionPolicy Bypass -File tests\test-daily-brief.ps1
powershell -ExecutionPolicy Bypass -File tests\test-notifications.ps1
powershell -ExecutionPolicy Bypass -File tests\test-obsidian.ps1
powershell -ExecutionPolicy Bypass -File tests\test-portability.ps1
powershell -ExecutionPolicy Bypass -File tests\test-utility-scripts.ps1

# Legacy monolithic suite (still works, kept for backwards compatibility)
powershell -ExecutionPolicy Bypass -File tests\test-all.ps1
```

Shared helpers (`tests\_helpers.ps1`) are dot-sourced by every per-suite file and provide `Test-Pass` / `Test-Fail` / `Assert-True` / `Assert-Contains` / `Assert-NotContains` / `Assert-Match` / `Assert-FileExists` / `Assert-ParsesPS` / `Section` / `Test-Summary`.

### From Make

The shell + PowerShell suites have no Make target (they are not part of the daily pipeline). Run them directly via bash or PowerShell.

The Python eval-harness tests do have a Make target:

```bash
make eval-test          # python -m unittest discover -s eval/tests
```

These exercise the offline `stub` judge end-to-end (extract → judge → store → drift → report) and require only Python 3 stdlib.

---

## Test Suites

### test-custom-brief.sh (48 tests)

Tests for the custom topic deep research feature.

```mermaid
flowchart LR
    subgraph "test-custom-brief.sh"
        A["File existence"] --> B["Bash syntax"]
        B --> C["Help flag"]
        C --> D["Arg validation"]
        D --> E["Prompt template"]
        E --> F["Template substitution"]
        F --> G["Interactive skill"]
        G --> H["Obsidian integration"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| File existence | 4 | `custom-brief.sh`, `prompt-custom-brief.md`, `commands/custom-brief.md` exist |
| Bash syntax | 1 | `bash -n` passes |
| Help flag | 7 | `--help` and `-h` print usage with all flags documented (including `--obsidian`) |
| Arg validation | 2 | Missing `--topic` value errors, unknown options error |
| Prompt template | 13 | All `{{}}` placeholders (including `{{PUBLISH_OBSIDIAN}}`), Phase 1-3, Agent 1-5, card template, citation requirement |
| Template substitution | 6 | awk gsub replaces all placeholders (including Obsidian), handles special chars, no leftover `{{}}` |
| Interactive skill | 7 | Frontmatter, steps, agents, Notion MCP, data_source_id, quality checklist |
| Obsidian integration | 8 | `PUBLISH_OBSIDIAN` in script, flag handling, publish script call, template wikilinks, skill reference |

### test-daily-brief.sh (80 tests)

Tests for the existing daily automated briefing pipeline.

```mermaid
flowchart LR
    subgraph "test-daily-brief.sh"
        A["File existence"] --> B["Bash syntax"]
        B --> C["Prompt structure"]
        C --> D["Topic coverage"]
        D --> E["Changelog URLs"]
        E --> F["Skill structure"]
        F --> G["Entry scripts"]
        G --> H["Dedup file"]
        H --> I["Obsidian integration"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| File existence | 5 | All pipeline files: `briefing.sh`, `briefing.ps1`, `prompt.md`, `install-task.ps1`, skill |
| Bash syntax | 1 | `bash -n` on `briefing.sh` |
| Prompt structure | 12 | Steps 0-6, data_source_id, dedup file, Notion MCP tools, card template |
| Topic coverage | 9 | All 9 topic areas present in prompt |
| Changelog URLs | 8 | All 8 provider changelog URLs present |
| Skill structure | 6 | Frontmatter, steps, Notion create, dedup reference |
| Entry scripts (bash) | 7 | Strict mode, prompt.md read, Claude invocation, Teams/Slack notify, CLAUDECODE clear |
| Entry scripts (PS1) | 6 | Same checks on `briefing.ps1` |
| Dedup file | 3 | `covered-stories.txt` exists, has entries, correct `YYYY-MM-DD \| headline` format |
| Obsidian (prompt) | 4 | Obsidian mention, obsidian.md output, `[[wikilinks]]`, YAML frontmatter |
| Obsidian (briefing.sh) | 3 | Publisher call, vault env check, obsidian.md reference |
| Obsidian (briefing.ps1) | 3 | Publisher call, vault env check, obsidian.md reference |
| Obsidian scripts | 6 | publish-obsidian.sh/.ps1, test-obsidian.sh/.ps1 existence and executability |
| Obsidian syntax | 2 | `bash -n` on publish and test scripts |
| Obsidian structure | 6 | Strict mode, subdirectories, wikilinks, topic type, vault env var |
| Obsidian skill | 1 | Obsidian mentioned in daily skill file |

### test-notifications.sh (17 tests)

Tests for the Teams and Slack notification pipeline.

```mermaid
flowchart LR
    subgraph "test-notifications.sh"
        A["Script existence"] --> B["Bash syntax"]
        B --> C["Python syntax"]
        C --> D["Card JSON validation"]
        D --> E["Card structure"]
        E --> F["Converter"]
        F --> G["Error handling"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| Script existence | 5 | `notify-teams.sh/.ps1`, `notify-slack.sh/.ps1`, `teams-to-slack.py` |
| Bash syntax | 2 | `bash -n` on both notify scripts |
| Python syntax | 1 | `py_compile` on `teams-to-slack.py` |
| Card JSON validation | 2 | All card files are valid JSON |
| Card structure | 14 | Message envelope, AdaptiveCard v1.4, ColumnSet header, emphasis style, bleed, sources, action button, size under 28KB, bullet TextBlocks |
| Converter | 6 | Processes latest card, output is valid JSON, Slack header/divider/sections/button |
| notify-teams.sh args | 3 | Errors on missing webhook, unknown option, missing card file |
| notify-slack.sh args | 3 | Same error handling checks |

### test-obsidian.sh (30 tests)

Tests for the Obsidian publishing pipeline with vault simulation.

```mermaid
flowchart LR
    subgraph "test-obsidian.sh"
        A["File existence"] --> B["Bash syntax"]
        B --> C["Publish structure"]
        C --> D["Wikilink logic"]
        D --> E["Error handling"]
        E --> F["Test script structure"]
        F --> G["Vault simulation"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| File existence | 6 | `publish-obsidian.sh/.ps1`, `test-obsidian.sh/.ps1` existence and executability |
| Bash syntax | 2 | `bash -n` on both bash scripts |
| Publish structure | 6 | Strict mode, subdirectories, vault env, mkdir, cp |
| Wikilink logic | 3 | grep extraction, `[[` pattern, topic type YAML |
| Error handling | 3 | exit on error, missing file error, missing vault error |
| Test script structure | 3 | Vault env check, .obsidian config check, writability check |
| Vault simulation | 7 | Creates temp vault, publishes markdown, verifies directories, topic stubs, frontmatter, idempotent re-run |

### test-portability.sh (26 tests)

Cross-platform compatibility verification.

```mermaid
flowchart LR
    subgraph "test-portability.sh"
        A["Bash version"] --> B["Platform"]
        B --> C["Required commands"]
        C --> D["Shebangs"]
        D --> E["Bash 3.2 compat"]
        E --> F["awk compat"]
        F --> G["date format"]
        G --> H["echo -e"]
        H --> I["Notify invocation"]
        I --> J["Color safety"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| Bash version | 1 | bash >= 3.0 (macOS minimum is 3.2) |
| Platform | 1 | Detects macOS / Linux / Windows Git Bash |
| Required commands | 9 | `awk`, `date`, `tee`, `cat`, `grep`, `mkdir`, `python3`, `curl` |
| Shebang lines | 4 | All `.sh` files use `#!/bin/bash` |
| Bash 3.2 compat | 2 | No bash 4+ features (`declare -A`, `\|&`, `${var,,}`) |
| awk compatibility | 2 | `gsub` with `-v` works, here-string multi-line input works |
| date format | 2 | `%Y-%m-%d` and `%Y-%m-%d-%H%M%S` produce expected patterns |
| echo -e | 1 | Escape sequences interpreted correctly |
| Notify invocation | 4 | Uses `-f` not `-x`, calls via `bash` not direct execution |
| Color safety | 1 | No raw ANSI escapes when output is piped |

### test-utility-scripts.sh (79 tests)

Bash integration suite for the new utility scripts: `eval-summary`, `eval-watch`, `eval-compare`, `plugin-validate`, `scaffold-plugin`. Tests run against temp SQLite databases seeded inside the test process — no real eval store is touched, and `scaffold-plugin` cleans up its scaffolded plugin after asserting JSON validity.

```mermaid
flowchart LR
    subgraph "test-utility-scripts.sh"
        A["Existence + parity"]
        B["bash -n syntax"]
        C["Strict-mode header"]
        D["--help"]
        E["Argument validation"]
        F["scaffold-plugin dry-run"]
        G["scaffold-plugin real write"]
        H["plugin-validate on repo"]
        I["eval-summary temp DB"]
        J["eval-compare temp DB"]
        K["Makefile targets"]
        A --> B --> C --> D --> E --> F --> G --> H --> I --> J --> K
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| Existence | 10 | All 5 scripts ship as `.sh` and `.ps1` pairs. |
| Syntax | 5 | `bash -n` passes for every new shell script. |
| Strict mode | 10 | `.sh` uses `set -euo pipefail`; `.ps1` uses `Set-StrictMode`. |
| `--help` | 5 | Every script's `--help` exits 0 with "Usage:" in output. |
| Arg validation | 6 | `scaffold-plugin` rejects missing args and non-kebab names; `eval-compare` rejects empty `--a`/`--b`. |
| `scaffold-plugin --dry-run` | 8 | Lists all 10 paths (claude + codex + gemini, plugin manifests + skills + agent), writes nothing. |
| `scaffold-plugin` real | 10 | Creates valid `plugin.json` × 3 platforms + `GEMINI.md` + `SKILL.md` + agent file; refuses to overwrite. |
| `plugin-validate` | 4 | Exits 0 on current repo; reports `ai-news-briefing`; reports `0 errors`; `--json` emits parseable JSON with `ok:true`. |
| `eval-summary` | 7 | Runs against temp DB with seeded judge; shows judge name, row count, gate-below cards; `--judges` mode lists judges. |
| `eval-compare` | 5 | Flags `Δ > threshold` and exits 3; A=B reports within tolerance. |
| Makefile targets | 5 | All 5 new targets present in `Makefile`. |

Test isolation: temp DBs are created via `mktemp -d`; scaffolded plugins use a `$$`-suffixed name and are `rm -rf`'d after JSON validation. No state leaks back into the working tree.

Run via:

```bash
bash tests/test-utility-scripts.sh
```

### eval/tests/test_harness.py (10 tests)

Python unit tests for the quality eval harness. Use only the Python stdlib and the offline `stub` judge, so they require no AI CLI and no network.

```mermaid
flowchart LR
    subgraph "eval/tests/test_harness.py"
        A["ExtractTests"] --> B["JudgeTests"]
        B --> C["StoreTests"]
        C --> D["DriftTests"]
        D --> E["ReportTests"]
    end
```

| Category | Tests | What it verifies |
|---|---|---|
| ExtractTests | 2 | Card → headlines + URLs; 7-day prior-headline window resolves |
| JudgeTests | 3 | Stub returns 5 valid axes; parser rejects non-JSON; parser rejects out-of-range scores |
| StoreTests | 2 | Weighted composite matches the rubric formula; upsert is idempotent on `(card_date, prompt_version, judge_model)` |
| DriftTests | 2 | Flat history → no alert; 8-day drop streak → `status: alert` with ≥ 2 alert entries |
| ReportTests | 1 | Weekly Markdown contains header, composite-median line, and per-day row |

Run via:

```bash
make eval-test
# or directly
python3 -m unittest discover -s eval/tests -v
```

### test-all.ps1 (~112 tests)

PowerShell-native test suite covering everything above from a Windows perspective.

| Category | Tests | What it verifies |
|---|---|---|
| File existence | 14 | All scripts, prompts, skills, converter |
| PowerShell syntax | 5 | `Parser::ParseFile` on all `.ps1` files |
| Daily prompt | 11 | Steps, data_source_id, topics |
| Custom brief prompt | 12 | Placeholders, phases, agents, citations |
| Template substitution | 5 | `[string]::Replace()`, special chars, no leftover `{{}}` |
| custom-brief.ps1 structure | 10 | Params, REPL, Replace (not -replace), notify calls |
| Card JSON | 9 | All cards valid, structure, size limit |
| Converter | 6 | Processes card, valid JSON output, Slack blocks |
| Notification scripts | 6 | Webhook env vars, JSON validation, -All flag |
| Documentation | 13 | All 7 docs exist, README/CUSTOM_BRIEF reference new feature |

---

## Test Output

Tests use colored output with ANSI codes (bash) or `Write-Host -ForegroundColor` (PowerShell). Colors auto-disable when piped.

```
  PASS  test name                    # green
  FAIL  test name (reason)           # red
```

Each suite has a styled header and summary:

```
  ================================================
    custom-brief.sh tests
  ================================================

  File existence
  PASS  custom-brief.sh exists
  ...

  ================================================
  ALL PASSED  37 tests
  ================================================
```

The `run-all.sh` runner displays an ASCII art banner and an aggregate result:

```
   _____                                                                 _____
  ( ___ )---------------------------------------------------------------( ___ )
   |   |     _    ___   _   _                     ____       _       __  |   |
   |   |    / \  |_ _| | \ | | _____      _____  | __ ) _ __(_) ___ / _| |   |
   ...
  =====================================================
    ALL 5 SUITES PASSED
  =====================================================
```

---

## Design Principles

- **Non-blocking.** No test calls Claude, Notion, Teams, Slack, or any external service. Obsidian tests use temp directories -- no real vault needed. Tests validate structure, syntax, and contracts -- not runtime behavior.
- **Tailored to pass.** Tests verify existing working code. They check what IS there, not hypothetical requirements.
- **Cross-platform.** Bash tests run on macOS, Linux, and Windows Git Bash. PowerShell tests run on Windows. Both cover the same code from different angles.
- **No test framework.** Pure bash and PowerShell with simple `pass()`/`fail()` helpers. No dependencies to install.
- **Fast.** Full suite runs in under 10 seconds.

---

## File Layout

```
tests/
  _helpers.ps1               # Shared PowerShell helpers (dot-sourced by every test-*.ps1)
  run-all.sh                 # Bash runner — discovers test-*.sh
  run-all.ps1                # PowerShell runner — discovers test-*.ps1
  test-custom-brief.sh       # Custom brief: args, template, prompt, skill, Obsidian
  test-custom-brief.ps1      #  ↳ PowerShell mirror
  test-daily-brief.sh        # Daily brief: prompt, topics, changelogs, scripts, Obsidian
  test-daily-brief.ps1       #  ↳ PowerShell mirror
  test-notifications.sh      # Notifications: cards, converter, error paths
  test-notifications.ps1     #  ↳ PowerShell mirror
  test-obsidian.sh           # Obsidian: publish script, wikilinks, vault simulation
  test-obsidian.ps1          #  ↳ PowerShell mirror
  test-portability.sh        # bash 3.2 / awk / date / ANSI safety
  test-portability.ps1       #  ↳ PowerShell side: ps1 syntax, strict-mode, BOM, Makefile routing
  test-utility-scripts.sh    # eval-* + plugin-* + scaffold-plugin
  test-utility-scripts.ps1   #  ↳ PowerShell mirror
  test-all.ps1               # Legacy monolithic PowerShell suite (kept for backwards compat)

eval/tests/
  test_harness.py            # Python unittest: extract, judge, store, drift, report
```

---

## Adding New Tests

Add assertions to the relevant `test-*.sh` file using the existing helpers:

```bash
pass "description"                           # Record a passing test
fail "description"                           # Record a failing test
assert_contains "$text" "pattern" "name"     # Pass if $text contains pattern
assert_eq "$actual" "$expected" "name"       # Pass if values match
section "Section Name"                       # Print a colored section header
```

For PowerShell, use the equivalents in `test-all.ps1`:

```powershell
Test-Pass "description"
Test-Fail "description"
Assert-Contains $text "pattern" "name"
Assert-True $condition "name"
```
