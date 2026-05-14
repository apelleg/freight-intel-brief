#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for Obsidian publishing pipeline. Mirrors test-obsidian.sh.
    Verifies publish-obsidian script, wikilink extraction, vault simulation,
    topic stub creation. No real vault writes.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    Obsidian publishing tests" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "Script existence"
foreach ($f in @("scripts/publish-obsidian.ps1", "scripts/publish-obsidian.sh",
                 "scripts/test-obsidian.ps1",    "scripts/test-obsidian.sh")) {
    Assert-FileExists (Join-Path $RepoRoot $f) "$f exists"
}

Section "PowerShell syntax"
Assert-ParsesPS (Join-Path $RepoRoot "scripts/publish-obsidian.ps1") "publish-obsidian.ps1 parses"
Assert-ParsesPS (Join-Path $RepoRoot "scripts/test-obsidian.ps1")    "test-obsidian.ps1 parses"

Section "publish-obsidian structure"
$po = Get-Content (Join-Path $RepoRoot "scripts/publish-obsidian.ps1") -Raw
Assert-Contains $po "AI_BRIEFING_OBSIDIAN_VAULT" "publish-obsidian reads vault env var"
Assert-Contains $po "obsidian.md"                "publish-obsidian references obsidian.md"
Assert-Contains $po "Topics"                     "publish-obsidian creates Topics/ subdir"
Assert-Contains $po "AI-News-Briefings"          "publish-obsidian uses AI-News-Briefings/ subdir"
Assert-Contains $po "wikilink" -ErrorAction SilentlyContinue 2>$null
Assert-Match    $po "\[\[.+\]\]|wikilink"        "publish-obsidian extracts wikilinks"

Section "Vault simulation (temp dir, no real writes)"
$tmpVault = Join-Path ([System.IO.Path]::GetTempPath()) ("obsidian-vault-test-" + [guid]::NewGuid().ToString('N').Substring(0,8))
$tmpMd    = Join-Path ([System.IO.Path]::GetTempPath()) ("obsidian-md-test-" + [guid]::NewGuid().ToString('N').Substring(0,8) + ".md")
try {
    New-Item -ItemType Directory -Force -Path $tmpVault | Out-Null
    @"
---
type: briefing
date: 2026-03-18
topics: [Claude Code, OpenAI, Anthropic]
---
# AI Daily Briefing -- 2026-03-18

## [[Claude Code]] / [[Anthropic]]
- Sample bullet.

## [[OpenAI]]
- Another bullet.

> Related topics: [[Claude Code]] · [[Anthropic]] · [[OpenAI]]
"@ | Set-Content -Path $tmpMd -Encoding UTF8

    # Drive the publish-obsidian script. Skip if env var contention possible.
    $oldVault = $env:AI_BRIEFING_OBSIDIAN_VAULT
    $env:AI_BRIEFING_OBSIDIAN_VAULT = $tmpVault
    try {
        $output = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts/publish-obsidian.ps1") -ObsidianFile $tmpMd 2>&1 | Out-String
        $rc = $LASTEXITCODE
        Assert-True ($rc -eq 0) "publish-obsidian.ps1 succeeds against temp vault"
        Assert-True (Test-Path (Join-Path $tmpVault "AI-News-Briefings")) "AI-News-Briefings/ created in vault"
        Assert-True (Test-Path (Join-Path $tmpVault "Topics"))            "Topics/ stub directory created in vault"

        $stubFiles = Get-ChildItem (Join-Path $tmpVault "Topics") -Filter "*.md" -ErrorAction SilentlyContinue
        Assert-True ($stubFiles.Count -ge 3) "at least 3 topic stub pages created"

        $stubContent = Get-Content $stubFiles[0].FullName -Raw
        Assert-Contains $stubContent "type: topic" "topic stub has type: topic frontmatter"
    } finally {
        if ($null -eq $oldVault) { Remove-Item Env:AI_BRIEFING_OBSIDIAN_VAULT -ErrorAction SilentlyContinue }
        else { $env:AI_BRIEFING_OBSIDIAN_VAULT = $oldVault }
    }
} finally {
    Remove-Item $tmpVault -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpMd -Force -ErrorAction SilentlyContinue
}

Section "Prompt references Obsidian step"
$prompt = Get-Content (Join-Path $RepoRoot "prompt.md") -Raw
Assert-Contains $prompt "obsidian.md" "prompt.md writes obsidian.md"
Assert-Contains $prompt "[["          "prompt.md uses [[wikilinks]] format"

exit (Test-Summary "obsidian")
