#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for the daily-briefing pipeline. Mirrors test-daily-brief.sh.
    Verifies prompt steps, topics, changelog URLs, entry script structure, dedup file.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$briefPs1 = Join-Path $RepoRoot "briefing.ps1"
$briefSh  = Join-Path $RepoRoot "briefing.sh"
$prompt   = Join-Path $RepoRoot "prompt.md"
$skill    = Join-Path $RepoRoot "commands/ai-news-briefing.md"
$dedup    = Join-Path $RepoRoot "logs/covered-stories.txt"

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    daily-brief tests" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "File existence"
Assert-FileExists $briefPs1 "briefing.ps1 exists"
Assert-FileExists $briefSh  "briefing.sh exists"
Assert-FileExists $prompt   "prompt.md exists"
Assert-FileExists $skill    "commands/ai-news-briefing.md exists"
Assert-FileExists (Join-Path $RepoRoot "install-task.ps1") "install-task.ps1 exists"

Section "PowerShell syntax"
Assert-ParsesPS $briefPs1 "briefing.ps1 parses"
Assert-ParsesPS (Join-Path $RepoRoot "install-task.ps1") "install-task.ps1 parses"

Section "Prompt structure (steps + topics)"
$pc = Get-Content $prompt -Raw
foreach ($step in @("Step 0", "Step 1", "Step 2", "Step 3", "Step 4", "Step 5", "Step 6")) {
    Assert-Contains $pc $step "prompt.md has $step"
}
Assert-Contains $pc "data_source_id" "prompt mentions data_source_id"
Assert-Contains $pc "covered-stories.txt" "prompt references dedup file"
Assert-Contains $pc "notion-create-pages" "prompt invokes Notion MCP create"

Section "Topic coverage"
foreach ($topic in @("Claude", "OpenAI", "Coding", "Agentic", "Industry",
                     "Open Source", "Startup", "Policy", "Dev Tools")) {
    Assert-Contains $pc $topic "prompt covers '$topic' topic area"
}

Section "Changelog URLs"
foreach ($url in @("code.claude.com/docs", "support.claude.com",
                   "developers.openai.com/codex/changelog",
                   "help.openai.com", "gemini.google", "github.blog/changelog",
                   "cursor.com/changelog", "sdk.vercel.ai/changelog")) {
    Assert-Contains $pc $url "prompt includes changelog URL: $url"
}

Section "Skill frontmatter"
$sk = Get-Content $skill -Raw
Assert-Contains $sk "---" "skill has frontmatter"
Assert-Contains $sk "description:" "skill frontmatter has description"

Section "Entry script structure (briefing.ps1)"
$bp = Get-Content $briefPs1 -Raw
Assert-Contains $bp "prompt.md"           "briefing.ps1 reads prompt.md"
Assert-Contains $bp "claude"              "briefing.ps1 invokes Claude CLI"
Assert-Contains $bp "CLAUDECODE"          "briefing.ps1 clears CLAUDECODE for nested-session"
Assert-Contains $bp "notify-teams"        "briefing.ps1 calls notify-teams"
Assert-Contains $bp "notify-slack"        "briefing.ps1 calls notify-slack"

Section "Dedup file"
Assert-FileExists $dedup "logs/covered-stories.txt exists"
if (Test-Path $dedup) {
    $lines = Get-Content $dedup
    Assert-True ($lines.Count -gt 0) "covered-stories.txt has entries"
    $headerRegex = "^\d{4}-\d{2}-\d{2} \| .+$"
    $bad = $lines | Where-Object { $_ -notmatch $headerRegex -and $_.Trim() -ne "" }
    Assert-True ($bad.Count -eq 0) "covered-stories.txt entries match 'YYYY-MM-DD | headline'"
}

Section "Obsidian integration in prompt"
Assert-Contains $pc "obsidian.md"      "prompt writes obsidian.md"
Assert-Contains $pc "[["               "prompt uses [[wikilinks]]"
Assert-Contains $pc "YAML frontmatter" "prompt mentions YAML frontmatter"

exit (Test-Summary "daily-brief")
