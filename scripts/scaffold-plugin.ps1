#Requires -Version 5.1

# scaffold-plugin.ps1 -- Bootstrap a new plugin across all three platforms.
#
# Usage:
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "what it does"
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -Skill default-skill
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -WithAgent reviewer
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -DryRun

# `param(...)` must come before any executable statement, see eval-summary.ps1.
param(
    [Parameter(Mandatory=$true)] [string]$Name,
    [Parameter(Mandatory=$true)] [string]$Description,
    [string]$Skill = "default-skill",
    [string]$WithAgent = "",
    [string]$Author = "Son Nguyen",
    [string]$AuthorUrl = "https://github.com/hoangsonww",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
Set-Location $ScriptDir

if ($Name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Host "ERROR: -Name must be kebab-case. Got: $Name" -ForegroundColor Red
    exit 2
}
if ($Skill -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Host "ERROR: -Skill must be kebab-case. Got: $Skill" -ForegroundColor Red
    exit 2
}

$ClaudeDir = "claude-plugins/$Name"
$CodexDir  = "plugins/$Name-codex"
$GeminiDir = "gemini-extensions/$Name"

foreach ($d in @($ClaudeDir, $CodexDir, $GeminiDir)) {
    if (Test-Path $d) {
        Write-Host "ERROR: $d already exists. Refusing to overwrite." -ForegroundColor Red
        exit 1
    }
}

if ($DryRun) {
    Write-Host "Would create:"
    @(
        "$ClaudeDir/.claude-plugin/plugin.json",
        "$ClaudeDir/skills/$Skill/SKILL.md",
        "$CodexDir/.codex-plugin/plugin.json",
        "$CodexDir/skills/$Skill/SKILL.md",
        "$GeminiDir/gemini-extension.json",
        "$GeminiDir/GEMINI.md",
        "$GeminiDir/skills/$Skill/SKILL.md"
    ) | ForEach-Object { Write-Host "  $_" }
    if ($WithAgent) {
        @("$ClaudeDir/agents/$WithAgent.md",
          "$CodexDir/agents/$WithAgent.md",
          "$GeminiDir/agents/$WithAgent.md") | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host "(dry-run; no files written)"
    exit 0
}

# Templates use {{PLACEHOLDERS}} -> .Replace() substitution rather than
# double-quoted here-strings with $var interpolation. The interpolating
# form parses fine in pwsh 7 but the Windows PowerShell 5.1 parser on
# the GitHub runner flags it as a parse error in CI; the literal form
# below is unambiguous and works in both.

$SkillTemplate = @'
---
description: {{DESCRIPTION}}
---

# {{SKILL}}

TODO: replace this body with the actual agent instructions.

Suggested structure:
1. State the user goal in one sentence.
2. List the tools/MCP servers this skill uses.
3. Outline the steps the agent should take.
4. Specify the output format.
'@

$AgentTemplate = @'
---
name: {{AGENT}}
description: TODO -- describe when this agent activates and what it does. Be specific so the model knows the trigger.
---

You are the {{AGENT}} agent. TODO: replace with the agent persona, goals, and constraints.
'@

$ClaudePluginJson = @'
{
  "name": "{{NAME}}",
  "description": "{{DESCRIPTION}}",
  "version": "0.1.0",
  "author": {
    "name": "{{AUTHOR}}",
    "url": "{{AUTHOR_URL}}"
  },
  "homepage": "https://github.com/hoangsonww/AI-News-Briefing",
  "repository": {
    "type": "git",
    "url": "https://github.com/hoangsonww/AI-News-Briefing.git"
  },
  "license": "MIT",
  "keywords": [],
  "categories": []
}
'@

$CodexPluginJson = @'
{
  "name": "{{NAME}}-codex",
  "version": "0.1.0",
  "description": "{{DESCRIPTION}}",
  "author": {
    "name": "{{AUTHOR}}"
  },
  "skills": "./skills/",
  "agents": "./agents/",
  "interface": {
    "displayName": "{{NAME}}",
    "shortDescription": "{{DESCRIPTION}}",
    "longDescription": "{{DESCRIPTION}}",
    "developerName": "{{AUTHOR}}",
    "category": "Productivity",
    "capabilities": ["Read", "Write"]
  }
}
'@

$GeminiExtensionJson = @'
{
  "name": "{{NAME}}",
  "version": "0.1.0",
  "description": "{{DESCRIPTION}}",
  "author": {
    "name": "{{AUTHOR}}"
  },
  "license": "MIT",
  "contextFileName": "GEMINI.md"
}
'@

$GeminiContextMd = @'
# {{NAME}}

You are the {{NAME}} agent. TODO: replace with the system instructions Gemini should load on every session.

## Available skills

- {{SKILL}} -- TODO describe.
'@

$MarketplaceSnippet = @'
    {
      "name": "{{NAME}}",
      "source": "./{{CLAUDE_DIR}}",
      "description": "{{DESCRIPTION}}",
      "category": "research",
      "tags": []
    },
'@

function Expand-Template {
    param([string]$Text)
    return $Text.
        Replace('{{NAME}}',        $Name).
        Replace('{{DESCRIPTION}}', $Description).
        Replace('{{SKILL}}',       $Skill).
        Replace('{{AUTHOR}}',      $Author).
        Replace('{{AUTHOR_URL}}',  $AuthorUrl).
        Replace('{{CLAUDE_DIR}}',  $ClaudeDir)
}

function Write-Skill {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Content -Path $Path -Value (Expand-Template $SkillTemplate) -Encoding UTF8
}

function Write-Agent {
    param([string]$Path, [string]$AgentName)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $body = $AgentTemplate.Replace('{{AGENT}}', $AgentName)
    Set-Content -Path $Path -Value $body -Encoding UTF8
}

# Claude
New-Item -ItemType Directory -Force -Path "$ClaudeDir/.claude-plugin" | Out-Null
Set-Content -Path "$ClaudeDir/.claude-plugin/plugin.json" -Value (Expand-Template $ClaudePluginJson) -Encoding UTF8
Write-Skill "$ClaudeDir/skills/$Skill/SKILL.md"

# Codex
New-Item -ItemType Directory -Force -Path "$CodexDir/.codex-plugin" | Out-Null
Set-Content -Path "$CodexDir/.codex-plugin/plugin.json" -Value (Expand-Template $CodexPluginJson) -Encoding UTF8
Write-Skill "$CodexDir/skills/$Skill/SKILL.md"

# Gemini
New-Item -ItemType Directory -Force -Path "$GeminiDir" | Out-Null
Set-Content -Path "$GeminiDir/gemini-extension.json" -Value (Expand-Template $GeminiExtensionJson) -Encoding UTF8
Set-Content -Path "$GeminiDir/GEMINI.md" -Value (Expand-Template $GeminiContextMd) -Encoding UTF8
Write-Skill "$GeminiDir/skills/$Skill/SKILL.md"

if ($WithAgent) {
    if ($WithAgent -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        Write-Host "WARN: -WithAgent name should be kebab-case. Got: $WithAgent" -ForegroundColor Yellow
    }
    Write-Agent "$ClaudeDir/agents/$WithAgent.md" $WithAgent
    Write-Agent "$CodexDir/agents/$WithAgent.md" $WithAgent
    Write-Agent "$GeminiDir/agents/$WithAgent.md" $WithAgent
}

Write-Host ""
Write-Host "Scaffolded $Name across 3 platforms:"
Write-Host "  $ClaudeDir/"
Write-Host "  $CodexDir/"
Write-Host "  $GeminiDir/"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit skills/$Skill/SKILL.md in each platform dir."
if ($WithAgent) { Write-Host "  1b. Edit agents/$WithAgent.md (3 copies)." }
Write-Host "  2. Paste this into .claude-plugin/marketplace.json:"
Write-Host ""
Write-Host (Expand-Template $MarketplaceSnippet)
Write-Host ""
Write-Host "  3. Run: .\scripts\plugin-validate.ps1"
Write-Host ""
