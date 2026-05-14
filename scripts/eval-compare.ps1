#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# eval-compare.ps1 — Side-by-side comparison of two judges (or two prompt versions).
#
# Usage:
#   .\scripts\eval-compare.ps1 -A claude-haiku-4-5-20251001 -B stub-v1
#   .\scripts\eval-compare.ps1 -A claude-haiku-4-5-20251001 -B gemini-cli -Threshold 0.5
#   .\scripts\eval-compare.ps1 -APrompt v1 -BPrompt v2 -Judge claude-haiku-4-5-20251001

param(
    [string]$A = "",
    [string]$B = "",
    [string]$APrompt = "",
    [string]$BPrompt = "",
    [string]$Judge = "",
    [double]$Threshold = 0.5
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Db = Join-Path $ScriptDir "eval/store.sqlite"

if (-not (Test-Path $Db)) {
    Write-Host "No eval store at $Db. Run a backfill first." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: sqlite3 not on PATH." -ForegroundColor Red
    exit 1
}

if ($APrompt -or $BPrompt) {
    if (-not $APrompt -or -not $BPrompt -or -not $Judge) {
        Write-Host "When comparing prompt versions, pass -APrompt, -BPrompt, and -Judge." -ForegroundColor Red
        exit 2
    }
    $aWhere = "judge_model = '$Judge' AND prompt_version = '$APrompt'"
    $bWhere = "judge_model = '$Judge' AND prompt_version = '$BPrompt'"
    $aLabel = "$Judge/$APrompt"
    $bLabel = "$Judge/$BPrompt"
} else {
    if (-not $A -or -not $B) {
        Write-Host "Pass -A and -B (judge_model) or -APrompt/-BPrompt/-Judge." -ForegroundColor Red
        exit 2
    }
    $aWhere = "judge_model = '$A'"
    $bWhere = "judge_model = '$B'"
    $aLabel = $A
    $bLabel = $B
}

Write-Host ""
Write-Host "  Eval comparison" -ForegroundColor White
Write-Host "  ==============="
Write-Host ("  A: {0}" -f $aLabel)
Write-Host ("  B: {0}" -f $bLabel)
Write-Host ("  flag threshold: |A - B| > {0}" -f $Threshold)
Write-Host ""

$sql = @"
SELECT
    a.card_date,
    printf('%.2f', a.composite),
    printf('%.2f', b.composite),
    printf('%+.2f', a.composite - b.composite)
FROM (SELECT * FROM eval_runs WHERE $aWhere) a
JOIN (SELECT * FROM eval_runs WHERE $bWhere) b ON a.card_date = b.card_date
ORDER BY a.card_date;
"@

$rows = & sqlite3 -separator "|" $Db $sql
if (-not $rows) {
    Write-Host "  no overlapping card_dates between A and B" -ForegroundColor Yellow
    exit 1
}

Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10} {4}" -f "date", "A", "B", "Delta", "flag")
Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10} {4}" -f "----", "------", "------", "------", "----")

$flagged = 0
$count = 0
$sumA = 0.0
$sumB = 0.0
$sumAbs = 0.0

foreach ($line in $rows) {
    $p = $line -split '\|'
    if ($p.Length -lt 4) { continue }
    $count++
    $delta = [double]$p[3]
    $absDelta = [Math]::Abs($delta)
    $sumA += [double]$p[1]
    $sumB += [double]$p[2]
    $sumAbs += $absDelta
    if ($absDelta -gt $Threshold) {
        $flagged++
        Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10} " -f $p[0], $p[1], $p[2], $p[3]) -NoNewline
        Write-Host "FLAGGED" -ForegroundColor Red
    } else {
        Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10} " -f $p[0], $p[1], $p[2], $p[3]) -NoNewline
        Write-Host "ok" -ForegroundColor DarkGray
    }
}

$meanA = "{0:N2}" -f ($sumA / $count)
$meanB = "{0:N2}" -f ($sumB / $count)
$mae   = "{0:N2}" -f ($sumAbs / $count)

Write-Host ""
Write-Host "  Summary" -ForegroundColor White
Write-Host "  -------"
Write-Host ("  rows compared: {0}" -f $count)
Write-Host ("  mean A:        {0}" -f $meanA)
Write-Host ("  mean B:        {0}" -f $meanB)
Write-Host ("  MAE |A - B|:   {0}" -f $mae)
Write-Host ("  flagged:       {0}" -f $flagged)
Write-Host ""

if ($flagged -gt 0) {
    Write-Host "  $flagged card(s) exceed threshold $Threshold - investigate the judge prompt or model behavior" -ForegroundColor Yellow
    exit 3
}
Write-Host "  All deltas within +/-$Threshold - A and B agree within tolerance" -ForegroundColor Green
