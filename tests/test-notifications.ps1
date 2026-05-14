#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for the Teams + Slack notification pipeline. Mirrors test-notifications.sh.
    Verifies card JSON validity, Adaptive Card structure, teams-to-slack converter,
    error paths. No webhooks called.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "_helpers.ps1")

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "    notifications tests (Teams + Slack)" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta

Section "Script existence"
foreach ($f in @("scripts/notify-teams.ps1", "scripts/notify-teams.sh",
                 "scripts/notify-slack.ps1", "scripts/notify-slack.sh",
                 "scripts/teams-to-slack.py")) {
    Assert-FileExists (Join-Path $RepoRoot $f) "$f exists"
}

Section "PowerShell syntax"
Assert-ParsesPS (Join-Path $RepoRoot "scripts/notify-teams.ps1") "notify-teams.ps1 parses"
Assert-ParsesPS (Join-Path $RepoRoot "scripts/notify-slack.ps1") "notify-slack.ps1 parses"

Section "Card JSON validity (example-cards/)"
$cardCount = 0
$cardBad = 0
foreach ($card in Get-ChildItem (Join-Path $RepoRoot "example-cards") -Filter "*-card.json") {
    $cardCount++
    try { Get-Content $card.FullName -Raw | ConvertFrom-Json | Out-Null }
    catch { $cardBad++; Test-Fail "card invalid: $($card.Name)" }
}
Assert-True ($cardCount -gt 0) "example-cards/ has cards"
Assert-True ($cardBad -eq 0)   "all example cards parse as JSON"

Section "Card structure (sample 2026-03-18)"
$samplePath = Join-Path $RepoRoot "example-cards/2026-03-18-card.json"
if (Test-Path $samplePath) {
    $sample = Get-Content $samplePath -Raw | ConvertFrom-Json
    Assert-True ($sample.type -eq "message")               "card top-level type = message"
    Assert-True ($sample.attachments.Count -ge 1)          "card has at least 1 attachment"
    $attach = $sample.attachments[0]
    Assert-True ($attach.contentType -match "adaptive")    "attachment contentType is adaptive card"
    Assert-True ($attach.content.type -eq "AdaptiveCard")  "content.type = AdaptiveCard"
    Assert-True ($attach.content.version -eq "1.4")        "content.version = 1.4"
    Assert-True ($attach.content.body.Count -gt 0)         "content.body has items"
    Assert-True ($attach.content.actions.Count -ge 1)      "content.actions has at least 1 action"
}

Section "Teams-to-Slack converter"
$conv = Join-Path $RepoRoot "scripts/teams-to-slack.py"
Assert-FileExists $conv "teams-to-slack.py exists"
$convContent = Get-Content $conv -Raw
Assert-Contains $convContent "blocks"          "converter emits 'blocks' (Slack Block Kit)"
Assert-Contains $convContent "section"         "converter has section block handler"
Assert-Contains $convContent "header"          "converter has header block handler"

if (Get-Command python3 -ErrorAction SilentlyContinue) {
    # Run the converter against a sample card and validate Block Kit output
    $tmp = New-TemporaryFile
    try {
        & python3 $conv $samplePath > $tmp.FullName 2>&1
        $rc = $LASTEXITCODE
        Assert-True ($rc -eq 0) "teams-to-slack.py exits 0 on valid card"
        if ($rc -eq 0) {
            $slack = Get-Content $tmp.FullName -Raw | ConvertFrom-Json
            Assert-True ($slack.blocks.Count -gt 0) "converter output has 'blocks' array"
        }
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
} else {
    Write-Host "  SKIP  teams-to-slack runtime test (python3 not on PATH)" -ForegroundColor Yellow
}

Section "Notify script error handling"
$nt = Get-Content (Join-Path $RepoRoot "scripts/notify-teams.ps1") -Raw
Assert-Contains $nt "AI_BRIEFING_TEAMS_WEBHOOK" "notify-teams.ps1 reads webhook env var"
Assert-Contains $nt "ConvertFrom-Json"          "notify-teams.ps1 validates JSON"
Assert-Contains $nt "Invoke-WebRequest"         "notify-teams.ps1 POSTs via Invoke-WebRequest"
Assert-Contains $nt "All"                       "notify-teams.ps1 supports -All flag"

$ns = Get-Content (Join-Path $RepoRoot "scripts/notify-slack.ps1") -Raw
Assert-Contains $ns "AI_BRIEFING_SLACK_WEBHOOK" "notify-slack.ps1 reads webhook env var"
Assert-Contains $ns "teams-to-slack"            "notify-slack.ps1 calls converter"
Assert-Contains $ns "Invoke-WebRequest"         "notify-slack.ps1 POSTs via Invoke-WebRequest"

Section "Card size limit"
$bigCards = Get-ChildItem (Join-Path $RepoRoot "example-cards") -Filter "*-card.json" |
    Where-Object { $_.Length -gt 28000 }
Assert-True ($bigCards.Count -eq 0) "no card exceeds Teams 28KB limit"

exit (Test-Summary "notifications")
