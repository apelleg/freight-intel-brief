#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# eval-summary.ps1 -- At-a-glance summary of eval/store.sqlite contents.
#
# Usage:
#   .\scripts\eval-summary.ps1
#   .\scripts\eval-summary.ps1 -Judge stub-v1
#   .\scripts\eval-summary.ps1 -Since 2026-03-01 -Until 2026-03-18
#   .\scripts\eval-summary.ps1 -ListJudges

param(
    [string]$Judge = "",
    [string]$Since = "",
    [string]$Until = "",
    [switch]$ListJudges
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Db = Join-Path $ScriptDir "eval/store.sqlite"

if (-not (Test-Path $Db)) {
    Write-Host "ERROR: no eval store at $Db" -ForegroundColor Red
    Write-Host "Run: make eval D=YYYY-MM-DD JUDGE=claude   (or make eval-backfill JUDGE=claude)"
    exit 1
}

# Require sqlite3 -- sqlite3 ships with Windows 10+ but verify
if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: sqlite3 not on PATH. Install from https://sqlite.org/download.html" -ForegroundColor Red
    exit 1
}

function Invoke-SqliteQuery {
    param([string]$Sql, [string]$Separator = "`t")
    return & sqlite3 -separator $Separator $Db $Sql
}

if ($ListJudges) {
    Write-Host ""
    Write-Host "  Judges and prompt versions in store:" -ForegroundColor White
    Write-Host "  ====================================="
    $rows = Invoke-SqliteQuery "SELECT judge_model, prompt_version, COUNT(*), MIN(card_date), MAX(card_date) FROM eval_runs GROUP BY judge_model, prompt_version ORDER BY 3 DESC;"
    Write-Host ("  {0,-36} {1,-6} {2,-6} {3,-12} {4,-12}" -f "judge_model", "ver", "rows", "from", "to")
    foreach ($r in $rows) {
        $parts = $r -split "`t"
        Write-Host ("  {0,-36} {1,-6} {2,-6} {3,-12} {4,-12}" -f $parts[0], $parts[1], $parts[2], $parts[3], $parts[4])
    }
    Write-Host ""
    exit 0
}

if (-not $Judge) {
    $Judge = (Invoke-SqliteQuery "SELECT judge_model FROM eval_runs WHERE judge_model LIKE 'claude%' OR judge_model LIKE 'gemini%' OR judge_model LIKE 'codex%' ORDER BY ran_at DESC LIMIT 1;" | Select-Object -First 1)
    if (-not $Judge) {
        $Judge = (Invoke-SqliteQuery "SELECT judge_model FROM eval_runs GROUP BY judge_model ORDER BY COUNT(*) DESC LIMIT 1;" | Select-Object -First 1)
    }
}
if (-not $Judge) {
    Write-Host "ERROR: store has no rows" -ForegroundColor Red
    exit 1
}

$Where = "WHERE judge_model = '$Judge'"
if ($Since) { $Where += " AND card_date >= '$Since'" }
if ($Until) { $Where += " AND card_date <= '$Until'" }

$RowCount = (Invoke-SqliteQuery "SELECT COUNT(*) FROM eval_runs $Where;" | Select-Object -First 1)
if ($RowCount -eq "0") {
    Write-Host "no rows match: judge=$Judge since=$Since until=$Until" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  Eval store summary" -ForegroundColor White
Write-Host "  =================="
Write-Host ("  {0,-22} {1}" -f "judge:", $Judge)
$range = "$(if ($Since) {$Since} else {'(start)'}) -> $(if ($Until) {$Until} else {'(end)'})"
Write-Host ("  {0,-22} {1}" -f "date range:", $range)
Write-Host ("  {0,-22} {1}" -f "rows matched:", $RowCount)
Write-Host ""

Write-Host "  Composite distribution" -ForegroundColor White
Write-Host "  ----------------------"
$stats = (Invoke-SqliteQuery "SELECT printf('%.2f', MIN(composite)), printf('%.2f', MAX(composite)), printf('%.2f', AVG(composite)) FROM eval_runs $Where;" "|" | Select-Object -First 1)
$parts = $stats -split '\|'
Write-Host ("  min={0,-6} max={1,-6} mean={2,-6}" -f $parts[0], $parts[1], $parts[2])
$median = (Invoke-SqliteQuery "SELECT printf('%.2f', composite) FROM eval_runs $Where ORDER BY composite LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM eval_runs $Where);" | Select-Object -First 1)
Write-Host "  median=$median"
Write-Host ""

Write-Host "  Axis medians" -ForegroundColor White
Write-Host "  ------------"
foreach ($ax in @("factuality", "novelty", "source_diversity", "signal_density", "coherence")) {
    $v = (Invoke-SqliteQuery "SELECT printf('%.1f', $ax) FROM eval_runs $Where ORDER BY $ax LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM eval_runs $Where);" | Select-Object -First 1)
    Write-Host ("  {0,-20} {1}" -f $ax, $v)
}
Write-Host ""

$gateFails = [int](Invoke-SqliteQuery "SELECT COUNT(*) FROM eval_runs $Where AND composite < 3.0;" | Select-Object -First 1)
if ($gateFails -eq 0) {
    Write-Host ("  {0,-22} " -f "publish gate (3.0):") -NoNewline
    Write-Host "all cards pass" -ForegroundColor Green
} else {
    Write-Host ("  {0,-22} " -f "publish gate (3.0):") -NoNewline
    Write-Host "$gateFails card(s) below 3.0" -ForegroundColor Yellow
    $failing = Invoke-SqliteQuery "SELECT card_date, printf('%.2f', composite) FROM eval_runs $Where AND composite < 3.0 ORDER BY card_date;" "|"
    foreach ($f in $failing) {
        $p = $f -split '\|'
        Write-Host ("    {0,-12} composite={1}" -f $p[0], $p[1])
    }
}
Write-Host ""

Write-Host "  Recent runs" -ForegroundColor White
Write-Host "  -----------"
$recent = Invoke-SqliteQuery "SELECT card_date, printf('%.2f', composite), factuality, novelty, source_diversity, signal_density, coherence FROM eval_runs $Where ORDER BY card_date DESC LIMIT 10;" "|"
Write-Host ("  {0,-12} {1,-9} {2} {3} {4} {5} {6}" -f "date", "composite", "F", "N", "D", "S", "C")
foreach ($r in $recent) {
    $p = $r -split '\|'
    Write-Host ("  {0,-12} {1,-9} {2} {3} {4} {5} {6}" -f $p[0], $p[1], $p[2], $p[3], $p[4], $p[5], $p[6])
}
Write-Host ""

# Drift (delegate to drift.py if python3 available)
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    Write-Host "  Drift status" -ForegroundColor White
    Write-Host "  ------------"
    $lastDate = (Invoke-SqliteQuery "SELECT MAX(card_date) FROM eval_runs $Where;" | Select-Object -First 1)
    $driftJson = & python3 (Join-Path $ScriptDir "eval/drift.py") --as-of $lastDate 2>$null
    if ($LASTEXITCODE -eq 0 -and $driftJson) {
        $d = ($driftJson -join "`n") | ConvertFrom-Json
        $color = switch ($d.status) {
            "ok" { "Green" }
            "alert" { "Red" }
            default { "Yellow" }
        }
        Write-Host ("  as of {0}: " -f $d.as_of) -NoNewline
        Write-Host $d.status -ForegroundColor $color -NoNewline
        Write-Host ("  z={0}  short_med={1}  long_med={2}" -f $d.z, $d.short_median, $d.long_median)
    }
    Write-Host ""
}

Write-Host "  Tip: .\scripts\eval-summary.ps1 -ListJudges       # list every (judge, prompt_version) combo" -ForegroundColor DarkGray
Write-Host "       make eval-dashboard OPEN=1                   # interactive HTML view" -ForegroundColor DarkGray
Write-Host ""
