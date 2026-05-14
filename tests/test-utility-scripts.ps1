#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for the new utility scripts (eval-summary, eval-watch, eval-compare,
    plugin-validate, scaffold-plugin). Mirrors test-utility-scripts.sh.
    Uses temp SQLite DBs and scaffolds + cleans up a throwaway plugin.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$NewScripts = @("eval-summary", "eval-watch", "eval-compare", "plugin-validate", "scaffold-plugin")

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    utility scripts tests (eval + plugin tooling)" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "Existence (sh + ps1 pairs)"
foreach ($name in $NewScripts) {
    foreach ($ext in @("sh", "ps1")) {
        $p = Join-Path $RepoRoot "scripts/$name.$ext"
        Assert-FileExists $p "scripts/$name.$ext exists"
    }
}

Section "PowerShell syntax"
foreach ($name in $NewScripts) {
    Assert-ParsesPS (Join-Path $RepoRoot "scripts/$name.ps1") "scripts/$name.ps1 parses"
}

Section "Strict-mode header"
foreach ($name in $NewScripts) {
    $head = (Get-Content (Join-Path $RepoRoot "scripts/$name.ps1") -TotalCount 5) -join "`n"
    Assert-Contains $head "Set-StrictMode" "scripts/$name.ps1 uses Set-StrictMode"
}

Section "Typed parameters"
$scaffold = Get-Content (Join-Path $RepoRoot "scripts/scaffold-plugin.ps1") -Raw
Assert-Contains $scaffold 'Mandatory=$true' "scaffold-plugin.ps1 declares mandatory params"
Assert-Contains $scaffold '[string]$Name'   "scaffold-plugin.ps1 has -Name parameter"
Assert-Contains $scaffold '[string]$Description' "scaffold-plugin.ps1 has -Description parameter"
Assert-Contains $scaffold 'kebab-case'       "scaffold-plugin.ps1 validates kebab-case"

$compare = Get-Content (Join-Path $RepoRoot "scripts/eval-compare.ps1") -Raw
Assert-Contains $compare '[double]$Threshold' "eval-compare.ps1 has [double] -Threshold"
Assert-Contains $compare 'FLAGGED'            "eval-compare.ps1 emits FLAGGED"

$watch = Get-Content (Join-Path $RepoRoot "scripts/eval-watch.ps1") -Raw
Assert-Contains $watch '[int]$Interval' "eval-watch.ps1 has [int] -Interval"
Assert-Contains $watch 'NoDb'           "eval-watch.ps1 has -NoDb switch"

$summary = Get-Content (Join-Path $RepoRoot "scripts/eval-summary.ps1") -Raw
Assert-Contains $summary 'ListJudges' "eval-summary.ps1 has -ListJudges switch"
Assert-Contains $summary 'sqlite3'    "eval-summary.ps1 invokes sqlite3"

$validate = Get-Content (Join-Path $RepoRoot "scripts/plugin-validate.ps1") -Raw
Assert-Contains $validate 'python3' "plugin-validate.ps1 delegates to python3"
Assert-Contains $validate '-Strict' "plugin-validate.ps1 has -Strict switch"
Assert-Contains $validate '-Json'   "plugin-validate.ps1 has -Json switch"

Section "scaffold-plugin -DryRun"
$tmpName = "test-ps-scaffold-" + [guid]::NewGuid().ToString('N').Substring(0, 8)
try {
    $output = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/scaffold-plugin.ps1") `
        -Name $tmpName -Description "ps dry-run test" -WithAgent reviewer -DryRun 2>&1 | Out-String
    $rc = $LASTEXITCODE
    Assert-True ($rc -eq 0) "scaffold-plugin.ps1 -DryRun exits 0"
    Assert-Contains $output "claude-plugins/$tmpName"      "dry-run lists claude path"
    Assert-Contains $output "plugins/$tmpName-codex"       "dry-run lists codex path"
    Assert-Contains $output "gemini-extensions/$tmpName"   "dry-run lists gemini path"
    Assert-Contains $output "agents/reviewer.md"           "dry-run includes agent file"
    Assert-Contains $output "no files written"             "dry-run reports no writes"
    Assert-False (Test-Path (Join-Path $RepoRoot "claude-plugins/$tmpName")) "dry-run did not write claude dir"
    Assert-False (Test-Path (Join-Path $RepoRoot "plugins/$tmpName-codex"))  "dry-run did not write codex dir"
    Assert-False (Test-Path (Join-Path $RepoRoot "gemini-extensions/$tmpName")) "dry-run did not write gemini dir"
} catch {
    Test-Fail "scaffold-plugin.ps1 -DryRun raised: $_"
}

Section "scaffold-plugin real write"
$realName = "test-ps-real-" + [guid]::NewGuid().ToString('N').Substring(0, 8)
$cDir = Join-Path $RepoRoot "claude-plugins/$realName"
$xDir = Join-Path $RepoRoot "plugins/$realName-codex"
$gDir = Join-Path $RepoRoot "gemini-extensions/$realName"
try {
    $output = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/scaffold-plugin.ps1") `
        -Name $realName -Description "ps real test" 2>&1 | Out-String
    $rc = $LASTEXITCODE
    Assert-True ($rc -eq 0) "scaffold-plugin.ps1 real run exits 0"
    Assert-FileExists (Join-Path $cDir ".claude-plugin/plugin.json") "real run created claude plugin.json"
    Assert-FileExists (Join-Path $xDir ".codex-plugin/plugin.json")  "real run created codex plugin.json"
    Assert-FileExists (Join-Path $gDir "gemini-extension.json")      "real run created gemini extension.json"
    Assert-FileExists (Join-Path $gDir "GEMINI.md")                  "real run created GEMINI.md"

    # JSON validity
    try {
        Get-Content (Join-Path $cDir ".claude-plugin/plugin.json") -Raw | ConvertFrom-Json | Out-Null
        Test-Pass "scaffolded claude plugin.json is valid JSON"
    } catch { Test-Fail "scaffolded claude plugin.json is valid JSON" }
    try {
        Get-Content (Join-Path $xDir ".codex-plugin/plugin.json") -Raw | ConvertFrom-Json | Out-Null
        Test-Pass "scaffolded codex plugin.json is valid JSON"
    } catch { Test-Fail "scaffolded codex plugin.json is valid JSON" }

    # Refuses to overwrite
    $overwrite = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/scaffold-plugin.ps1") `
        -Name $realName -Description "duplicate" 2>&1 | Out-String
    $orc = $LASTEXITCODE
    Assert-True ($orc -ne 0) "scaffold-plugin refuses overwrite"
    Assert-Contains $overwrite "already exists" "overwrite error mentions 'already exists'"
} finally {
    Remove-Item $cDir, $xDir, $gDir -Recurse -Force -ErrorAction SilentlyContinue
}

Section "plugin-validate.ps1 against current repo"
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    try {
        $pv = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/plugin-validate.ps1") 2>&1 | Out-String
        $pvRc = $LASTEXITCODE
        Assert-True ($pvRc -eq 0) "plugin-validate.ps1 exits 0"
        Assert-Contains $pv "ai-news-briefing" "plugin-validate.ps1 mentions ai-news-briefing"
        Assert-Contains $pv "0 errors"         "plugin-validate.ps1 reports 0 errors"

        # JSON mode
        $pvJson = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/plugin-validate.ps1") -Json 2>&1 | Out-String
        $obj = $pvJson | ConvertFrom-Json
        Assert-True ($obj.ok -eq $true) "plugin-validate.ps1 -Json reports ok:true"
    } catch {
        Test-Fail "plugin-validate.ps1 raised: $_"
    }
} else {
    Write-Host "  SKIP  plugin-validate.ps1 functional smoke (python3 not on PATH)" -ForegroundColor Yellow
}

Section "Makefile routes to ps1"
$mk = Get-Content (Join-Path $RepoRoot "Makefile") -Raw
foreach ($name in $NewScripts) {
    Assert-Contains $mk "$name.ps1" "Makefile routes $name to .ps1 on Windows"
}

Section "README coverage"
$readme = Get-Content (Join-Path $RepoRoot "README.md") -Raw
foreach ($name in $NewScripts) {
    Assert-Contains $readme $name "README.md mentions $name"
}

exit (Test-Summary "utility-scripts")
