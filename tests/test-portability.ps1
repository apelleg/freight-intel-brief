#Requires -Version 5.1
<#
.SYNOPSIS
    Windows portability tests. Mirrors test-portability.sh but checks the PowerShell
    side: every ps1 parses, uses Set-StrictMode, avoids POSIX-only constructs, and
    the Makefile correctly routes to ps1 variants on Windows.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    portability tests (PowerShell side)" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "Every .ps1 parses"
$ps1Files = Get-ChildItem (Join-Path $RepoRoot "scripts") -Filter "*.ps1"
$ps1Files += Get-Item (Join-Path $RepoRoot "briefing.ps1") -ErrorAction SilentlyContinue
$ps1Files += Get-Item (Join-Path $RepoRoot "custom-brief.ps1") -ErrorAction SilentlyContinue
$ps1Files += Get-Item (Join-Path $RepoRoot "install-task.ps1") -ErrorAction SilentlyContinue
$ps1Files = $ps1Files | Where-Object { $_ -ne $null }
foreach ($f in $ps1Files) {
    Assert-ParsesPS $f.FullName "$($f.Name) parses without errors"
}

Section "Strict mode + ErrorActionPreference"
foreach ($f in $ps1Files) {
    # Whole-file check -- Set-StrictMode lives below `param(...)` in newer
    # scripts because PS7 requires param to be the first executable statement.
    $body = Get-Content $f.FullName -Raw
    Assert-Contains $body "Set-StrictMode" "$($f.Name) declares Set-StrictMode"
}

Section "Requires header on entry-point ps1"
$entryScripts = @("briefing.ps1", "custom-brief.ps1", "install-task.ps1")
foreach ($name in $entryScripts) {
    $path = Join-Path $RepoRoot $name
    if (Test-Path $path) {
        $head = (Get-Content $path -TotalCount 3) -join "`n"
        Assert-Contains $head "#Requires" "$name has #Requires header"
    }
}

Section "No POSIX-only constructs in ps1"
# Common offenders that don't work in pure PowerShell
foreach ($f in $ps1Files) {
    $body = Get-Content $f.FullName -Raw
    # Detect bash-style if-then (a syntax error in PS would be caught by parser, but
    # we also reject obvious POSIX idioms in case someone copy-pastes from sh).
    Assert-NotContains $body "fi`n"   "$($f.Name) has no bare 'fi' newline (bash leak)"
    Assert-NotContains $body "esac`n" "$($f.Name) has no bare 'esac' newline (bash leak)"
}

Section "Makefile routes correctly to ps1 on Windows"
$mk = Get-Content (Join-Path $RepoRoot "Makefile") -Raw
foreach ($pattern in @(
    'PLATFORM',
    'eval-summary.ps1',
    'eval-watch.ps1',
    'eval-compare.ps1',
    'plugin-validate.ps1',
    'scaffold-plugin.ps1',
    'notify-teams.ps1',
    'notify-slack.ps1',
    'briefing.ps1'
)) {
    Assert-Contains $mk $pattern "Makefile references $pattern (Windows routing)"
}

Section "PowerShell version detection"
Assert-True ($PSVersionTable.PSVersion.Major -ge 5) "running on PowerShell 5.1+"

Section "Output encoding sanity"
# Ensure the test runner outputs plain ASCII status markers; no UTF-8 BOM oddities.
$selfPath = (Get-ChildItem $RepoRoot/tests -Filter "test-*.ps1" | Select-Object -First 1).FullName
$selfHead = [System.IO.File]::ReadAllBytes($selfPath)[0..2]
Assert-False (($selfHead[0] -eq 0xEF -and $selfHead[1] -eq 0xBB -and $selfHead[2] -eq 0xBF)) "tests/*.ps1 do not have UTF-8 BOM (cross-shell safety)"

exit (Test-Summary "portability")
