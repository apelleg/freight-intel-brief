#Requires -Version 5.1
<#
.SYNOPSIS
    Run every PowerShell test suite. Mirrors run-all.sh.
    Auto-discovers tests/test-*.ps1 and runs each in a child PowerShell process so
    state, exit codes, and output are isolated.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$TestsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$SuitesPass = 0
$SuitesFail = 0
$TotalFail = 0

Write-Host ""
Write-Host "   _____                                                                 _____ " -ForegroundColor DarkGray
Write-Host "  ( ___ )---------------------------------------------------------------( ___ )" -ForegroundColor DarkGray
Write-Host "   |   |                                                                 |   | " -ForegroundColor DarkGray
Write-Host "   |   |" -ForegroundColor DarkGray -NoNewline
Write-Host "       PowerShell Test Runner — AI News Briefing                       " -ForegroundColor Cyan -NoNewline
Write-Host "|   | " -ForegroundColor DarkGray
Write-Host "  (_____)---------------------------------------------------------------(_____)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Non-blocking test suite (no Claude, no webhooks, no Notion)" -ForegroundColor DarkGray
Write-Host ""

# Discover every test-*.ps1 (skip helpers + run-all itself + monolith)
$suites = Get-ChildItem $TestsDir -Filter "test-*.ps1" |
    Where-Object { $_.Name -ne "test-all.ps1" } |
    Sort-Object Name

foreach ($suite in $suites) {
    & powershell -ExecutionPolicy Bypass -File $suite.FullName
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        $SuitesPass++
    } else {
        $TotalFail += $rc
        $SuitesFail++
    }
}

$TotalSuites = $SuitesPass + $SuitesFail

Write-Host ""
Write-Host "  =====================================================" -ForegroundColor White
if ($TotalFail -eq 0) {
    Write-Host "  ALL $TotalSuites SUITES PASSED" -ForegroundColor Green
} else {
    Write-Host "  $SuitesFail of $TotalSuites suite(s) had failures ($TotalFail total failures)" -ForegroundColor Red
}
Write-Host "  =====================================================" -ForegroundColor White
Write-Host ""

exit $TotalFail
