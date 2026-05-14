#Requires -Version 5.1
# Shared helpers dot-sourced by every test-*.ps1 suite.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$script:Pass = 0
$script:Fail = 0

function Test-Pass { param([string]$Name); $script:Pass++; Write-Host "  PASS  $Name" -ForegroundColor Green }
function Test-Fail { param([string]$Name); $script:Fail++; Write-Host "  FAIL  $Name" -ForegroundColor Red }

function Assert-True {
    param([bool]$Cond, [string]$Name)
    if ($Cond) { Test-Pass $Name } else { Test-Fail $Name }
}
function Assert-False {
    param([bool]$Cond, [string]$Name)
    if (-not $Cond) { Test-Pass $Name } else { Test-Fail $Name }
}
function Assert-Contains {
    param([string]$Text, [string]$Pattern, [string]$Name)
    if ($Text -match [regex]::Escape($Pattern)) { Test-Pass $Name } else { Test-Fail "$Name (missing '$Pattern')" }
}
function Assert-NotContains {
    param([string]$Text, [string]$Pattern, [string]$Name)
    if ($Text -notmatch [regex]::Escape($Pattern)) { Test-Pass $Name } else { Test-Fail "$Name (unexpected '$Pattern')" }
}
function Assert-Match {
    param([string]$Text, [string]$Regex, [string]$Name)
    if ($Text -match $Regex) { Test-Pass $Name } else { Test-Fail "$Name (regex /$Regex/ did not match)" }
}
function Assert-FileExists {
    param([string]$Path, [string]$Name)
    if (Test-Path $Path) { Test-Pass $Name } else { Test-Fail "$Name (missing: $Path)" }
}
function Assert-ParsesPS {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) { Test-Fail "$Name (missing)"; return }
    $errors = $null
    [void][System.Management.Automation.PSParser]::Tokenize((Get-Content $Path -Raw), [ref]$errors)
    if ($errors.Count -eq 0) { Test-Pass $Name } else { Test-Fail "$Name ($($errors.Count) parse error(s))" }
}

function Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
}

function Test-Summary {
    param([string]$SuiteName)
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor DarkGray
    if ($script:Fail -eq 0) {
        Write-Host "  $SuiteName : ALL PASSED ($script:Pass tests)" -ForegroundColor Green
    } else {
        Write-Host "  $SuiteName : $script:Fail of $($script:Pass + $script:Fail) failed" -ForegroundColor Red
    }
    Write-Host "  ================================================" -ForegroundColor DarkGray
    Write-Host ""
    return $script:Fail
}

# Repo root = parent of tests/
$global:RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
