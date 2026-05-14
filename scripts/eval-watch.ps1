#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# eval-watch.ps1 — Live tail of eval-judge logs + newly written eval rows.
#
# Usage:
#   .\scripts\eval-watch.ps1
#   .\scripts\eval-watch.ps1 -Date 2026-03-18
#   .\scripts\eval-watch.ps1 -Interval 5
#   .\scripts\eval-watch.ps1 -NoDb

param(
    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
    [int]$Interval = 2,
    [switch]$NoDb
)

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Db = Join-Path $ScriptDir "eval/store.sqlite"
$LogDir = Join-Path $ScriptDir "logs"
$Log = Join-Path $LogDir "eval-judge-$Date.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
if (-not (Test-Path $Log)) { New-Item -ItemType File -Force -Path $Log | Out-Null }

Write-Host ""
Write-Host ("  eval-watch — {0}" -f (Get-Date -Format "HH:mm:ss")) -ForegroundColor White
Write-Host "  ============================"
Write-Host ("  log:      {0}" -f $Log)
Write-Host ("  store:    {0}" -f $Db)
Write-Host ("  interval: {0}s" -f $Interval)
Write-Host  "  ctrl-c:   exit"
Write-Host ""

# Background DB poller
$pollerJob = $null
if (-not $NoDb -and (Test-Path $Db) -and (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    $pollerJob = Start-Job -ScriptBlock {
        param($DbPath, $Sleep)
        $prev = & sqlite3 $DbPath "SELECT COUNT(*) FROM eval_runs;" 2>$null
        if (-not $prev) { $prev = "0" }
        while ($true) {
            Start-Sleep -Seconds $Sleep
            if (-not (Test-Path $DbPath)) { continue }
            $cur = & sqlite3 $DbPath "SELECT COUNT(*) FROM eval_runs;" 2>$null
            if (-not $cur) { continue }
            if ($cur -ne $prev) {
                $diff = [int]$cur - [int]$prev
                $rows = & sqlite3 -separator '|' $DbPath "SELECT card_date, judge_model, printf('%.2f', composite), ran_at FROM eval_runs ORDER BY ran_at DESC LIMIT $diff;"
                foreach ($r in $rows) {
                    $p = $r -split '\|'
                    Write-Output ("+ row  date={0,-12} judge={1,-30} composite={2}  ran_at={3}" -f $p[0], $p[1], $p[2], $p[3])
                }
                $prev = $cur
            }
        }
    } -ArgumentList $Db, $Interval

    Register-EngineEvent PowerShell.Exiting -Action { Stop-Job $using:pollerJob -ErrorAction SilentlyContinue } | Out-Null
}

Write-Host "  Following $Log ..." -ForegroundColor DarkGray
Write-Host ""

try {
    Get-Content -Path $Log -Wait -Tail 0 |
        ForEach-Object {
            Write-Output $_
            if ($pollerJob) {
                $news = Receive-Job $pollerJob -Keep:$false
                foreach ($n in $news) { Write-Host $n -ForegroundColor Green }
            }
        }
} finally {
    if ($pollerJob) { Stop-Job $pollerJob -ErrorAction SilentlyContinue; Remove-Job $pollerJob -Force -ErrorAction SilentlyContinue }
}
