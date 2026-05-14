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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot  = Split-Path -Parent $ScriptDir
Set-Location $RepoRoot

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

$strictArg = if ($Strict) { "1" } else { "0" }
$jsonArg   = if ($Json)   { "1" } else { "0" }

$validator = Join-Path $ScriptDir "_plugin_validate.py"
& $pyExe $validator $strictArg $jsonArg
exit $LASTEXITCODE
