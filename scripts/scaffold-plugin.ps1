#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# scaffold-plugin.ps1 -- Bootstrap a new plugin across all three platforms.
#
# Usage:
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "what it does"
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -Skill default-skill
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -WithAgent reviewer
#   .\scripts\scaffold-plugin.ps1 -Name my-plugin -Description "..." -DryRun

param(
    [Parameter(Mandatory=$true)] [string]$Name,
    [Parameter(Mandatory=$true)] [string]$Description,
    [string]$Skill = "default-skill",
    [string]$WithAgent = "",
    [string]$Author = "Son Nguyen",
    [string]$AuthorUrl = "https://github.com/hoangsonww",
    [switch]$DryRun
)

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

function Write-Skill {
    param([string]$Path)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    @"
---
description: $Description
---

# $Skill

TODO: replace this body with the actual agent instructions.

Suggested structure:
1. State the user's goal in one sentence.
2. List the tools/MCP servers this skill uses.
3. Outline the steps the agent should take.
4. Specify the output format.
"@ | Set-Content -Path $Path -Encoding UTF8
}

function Write-Agent {
    param([string]$Path, [string]$AgentName)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    @"
---
name: $AgentName
description: TODO -- describe when this agent activates and what it does. Be specific so the model knows the trigger.
---

You are the $AgentName agent. TODO: replace with the agent's persona, goals, and constraints.
"@ | Set-Content -Path $Path -Encoding UTF8
}

# Claude
New-Item -ItemType Directory -Force -Path "$ClaudeDir/.claude-plugin" | Out-Null
@"
{
  "name": "$Name",
  "description": "$Description",
  "version": "0.1.0",
  "author": {
    "name": "$Author",
    "url": "$AuthorUrl"
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
"@ | Set-Content -Path "$ClaudeDir/.claude-plugin/plugin.json" -Encoding UTF8
Write-Skill "$ClaudeDir/skills/$Skill/SKILL.md"

# Codex
New-Item -ItemType Directory -Force -Path "$CodexDir/.codex-plugin" | Out-Null
@"
{
  "name": "$Name-codex",
  "version": "0.1.0",
  "description": "$Description",
  "author": {
    "name": "$Author"
  },
  "skills": "./skills/",
  "agents": "./agents/",
  "interface": {
    "displayName": "$Name",
    "shortDescription": "$Description",
    "longDescription": "$Description",
    "developerName": "$Author",
    "category": "Productivity",
    "capabilities": ["Read", "Write"]
  }
}
"@ | Set-Content -Path "$CodexDir/.codex-plugin/plugin.json" -Encoding UTF8
Write-Skill "$CodexDir/skills/$Skill/SKILL.md"

# Gemini
New-Item -ItemType Directory -Force -Path "$GeminiDir" | Out-Null
@"
{
  "name": "$Name",
  "version": "0.1.0",
  "description": "$Description",
  "author": {
    "name": "$Author"
  },
  "license": "MIT",
  "contextFileName": "GEMINI.md"
}
"@ | Set-Content -Path "$GeminiDir/gemini-extension.json" -Encoding UTF8

@"
# $Name

You are the $Name agent. TODO: replace with the system instructions Gemini should load on every session.

## Available skills

- $Skill -- TODO describe.
"@ | Set-Content -Path "$GeminiDir/GEMINI.md" -Encoding UTF8
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
Write-Host "    {"
Write-Host "      `"name`": `"$Name`","
Write-Host "      `"source`": `"./$ClaudeDir`","
Write-Host "      `"description`": `"$Description`","
Write-Host "      `"category`": `"research`","
Write-Host "      `"tags`": []"
Write-Host "    },"
Write-Host ""
Write-Host "  3. Run: .\scripts\plugin-validate.ps1"
Write-Host ""
