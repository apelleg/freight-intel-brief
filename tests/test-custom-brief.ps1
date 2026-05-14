#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for the custom topic deep-research feature. Mirrors test-custom-brief.sh.
    Verifies args, template substitution, prompt structure, skill, and Obsidian integration.
    Non-blocking: no Claude / Notion / webhook calls.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$cbPs1   = Join-Path $RepoRoot "custom-brief.ps1"
$prompt  = Join-Path $RepoRoot "prompt-custom-brief.md"
$skill   = Join-Path $RepoRoot "commands/custom-brief.md"

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    custom-brief.ps1 tests" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "File existence"
Assert-FileExists $cbPs1   "custom-brief.ps1 exists"
Assert-FileExists $prompt  "prompt-custom-brief.md exists"
Assert-FileExists $skill   "commands/custom-brief.md exists"
Assert-FileExists (Join-Path $RepoRoot "custom-brief.sh") "custom-brief.sh exists (parity)"

Section "PowerShell syntax"
Assert-ParsesPS $cbPs1 "custom-brief.ps1 parses"

Section "Help flag"
$cbContent = Get-Content $cbPs1 -Raw
Assert-Contains $cbContent "Topic"      "custom-brief.ps1 has -Topic parameter"
Assert-Contains $cbContent "Notion"     "custom-brief.ps1 has -Notion switch"
Assert-Contains $cbContent "Teams"      "custom-brief.ps1 has -Teams switch"
Assert-Contains $cbContent "Slack"      "custom-brief.ps1 has -Slack switch"
Assert-Contains $cbContent "Obsidian"   "custom-brief.ps1 has -Obsidian switch"
Assert-Contains $cbContent "Cli"        "custom-brief.ps1 has -Cli parameter"

Section "Prompt template structure"
$pc = Get-Content $prompt -Raw
foreach ($placeholder in @("{{TOPIC}}", "{{DATE}}", "{{PUBLISH_NOTION}}",
                            "{{PUBLISH_TEAMS}}", "{{PUBLISH_SLACK}}",
                            "{{PUBLISH_OBSIDIAN}}")) {
    Assert-Contains $pc $placeholder "prompt-custom-brief.md contains $placeholder"
}
Assert-Contains $pc "Phase 1" "prompt has Phase 1"
Assert-Contains $pc "Phase 2" "prompt has Phase 2"
Assert-Contains $pc "Phase 3" "prompt has Phase 3"
Assert-Contains $pc "Agent 1" "prompt has Agent 1"
Assert-Contains $pc "Agent 5" "prompt has Agent 5"

Section "Skill file"
$sk = Get-Content $skill -Raw
Assert-Contains $sk "---"           "skill has YAML frontmatter"
Assert-Contains $sk "description:"  "skill frontmatter has description"
Assert-Contains $sk "Notion"        "skill mentions Notion"

Section "Obsidian integration"
Assert-Contains $cbContent "Obsidian"      "custom-brief.ps1 references Obsidian"
Assert-Contains $cbContent "wikilink"      "custom-brief.ps1 mentions wikilink"
Assert-Contains $pc        "[["            "prompt template uses [[ for wikilinks"

exit (Test-Summary "custom-brief")
