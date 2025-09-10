# Manual Release Process Guide

This document describes the step-by-step manual release process for SimplyTrack using AI assistance to analyze commits, generate release notes, and trigger the GitHub Actions workflow. The process can be executed through Claude Desktop (with GitHub MCP) or Claude Code (with `gh` CLI integration).

## Overview

The manual release process involves:

1. **AI-driven commit analysis** - Analyze commit history since last release
2. **AI-generated release notes** following strict formatting conventions
3. **Preview and review** - release notes shown before any actions taken
4. **Human review and approval** for quality control
5. **Workflow dispatch** - trigger GitHub Actions via MCP or `gh` CLI
6. **Automated build and release** - existing workflow handles the rest
7. **User-facing focus** filtering out technical commits

## Prerequisites

### For Claude Desktop (MCP):
- Claude Desktop with [GitHub MCP server](https://github.com/github/github-mcp-server) configured
- GitHub repository access (MCP handles authentication)

### For Claude Code:
- [GitHub CLI (`gh`)](https://cli.github.com) installed and authenticated (`gh auth login`)
- Or [GitHub MCP server](https://github.com/github/github-mcp-server) configured (if available)

### Common Requirements:
- Understanding of conventional commit patterns
- Familiarity with major.minor versioning (no patch versions)

## AI-Assisted Release Process

### Option 1: Claude Desktop (MCP)

Use this single prompt in Claude Desktop to handle the entire release process:

#### Master Release Prompt for Claude Desktop

```
I need to create a new release for SimplyTrack. Please use GitHub MCP to:

STEP 1: ANALYZE COMMITS
- Get the latest release tag from the repository
- Fetch all commits between that tag and current HEAD
- Analyze each commit for user-facing changes

STEP 2: GENERATE RELEASE NOTES
Create structured release notes with this EXACT format:

### ⚠️ Breaking Changes
[Only if breaking changes exist - triggers major version]
- Description focusing on user impact (abc1234)

### ✨ New Features
- Feature description emphasizing user benefit (abc1234)

### 🚀 Improvements  
- Improvement description with user impact (abc1234)

### 🐛 Bug Fixes
- Fix description focusing on resolved user issue (abc1234)

REQUIREMENTS:
- Focus ONLY on user-facing changes and impact
- EXCLUDE: docs, build, ci, chore, refactor, test commits  
- Use active voice, present tense
- Include commit short hashes (GitHub renders as links)
- Version logic: major.minor format only (no patch)
  - MINOR version (1.1 → 1.2): New features, bug fixes, improvements
  - MAJOR version (1.2 → 2.0): Breaking changes detected
- Show this preview BEFORE any actions

STEP 3: SHOW PREVIEW
Display the generated release notes and ask for approval before proceeding.

STEP 4: TRIGGER WORKFLOW (after approval)
Use GitHub MCP to trigger the "Build and Release" workflow with:
- workflow_id: release.yml
- release_tag: v[VERSION]  
- release_notes: [generated content]
- draft: true
- prerelease: false

Please start with Step 1 - analyze the commits and show me the preview.
```

### Option 2: Claude Code (gh CLI or MCP)

Use this prompt in Claude Code to handle the entire release process:

#### Master Release Prompt for Claude Code

```
I need to create a new release for SimplyTrack. Please:

STEP 1: ANALYZE COMMITS
- Use `gh` CLI or available tools to get the latest release tag
- Fetch all commits between that tag and current HEAD
- Analyze each commit for user-facing changes

STEP 2: GENERATE RELEASE NOTES
Create structured release notes with this EXACT format:

### ⚠️ Breaking Changes
[Only if breaking changes exist - triggers major version]
- Description focusing on user impact (abc1234)

### ✨ New Features
- Feature description emphasizing user benefit (abc1234)

### 🚀 Improvements  
- Improvement description with user impact (abc1234)

### 🐛 Bug Fixes
- Fix description focusing on resolved user issue (abc1234)

REQUIREMENTS:
- Focus ONLY on user-facing changes and impact
- EXCLUDE: docs, build, ci, chore, refactor, test commits  
- Use active voice, present tense
- Include commit short hashes (GitHub renders as links)
- Version logic: major.minor format only (no patch)
  - MINOR version (1.1 → 1.2): New features, bug fixes, improvements
  - MAJOR version (1.2 → 2.0): Breaking changes detected
- Show this preview BEFORE any actions

STEP 3: SHOW PREVIEW
Display the generated release notes and ask for approval before proceeding.

STEP 4: TRIGGER WORKFLOW (after approval)
Use `gh workflow run` to trigger the "Build and Release" workflow:

```bash
gh workflow run release.yml \
  -f release_tag="v[VERSION]" \
  -f release_notes="[generated content]" \
  -f draft=true \
  -f prerelease=false
```

Please start with Step 1 - analyze the commits and show me the preview.

## How It Works

Both Claude Desktop (MCP) and Claude Code will:
1. **Analyze commits** since last release via GitHub MCP or `gh` CLI
2. **Generate release notes** with proper formatting and categorization  
3. **Show preview** and ask for approval
4. **Trigger GitHub Actions workflow** with the release notes

## Features

- **Automatic filtering** of technical commits (docs, tests, CI, etc.)
- **User-focused** release notes with clear impact descriptions
- **Smart versioning** - minor for features/fixes, major for breaking changes
- **Preview before action** - human approval required

## Troubleshooting

### Claude Desktop (MCP):
- **No MCP Connection**: Ensure GitHub MCP server is running
- **Permission Denied**: Verify MCP has workflow dispatch permissions

### Claude Code:
- **gh CLI issues**: Run `gh auth status` to verify authentication
- **Workflow dispatch failed**: Check repository permissions for workflow dispatch
- **MCP not available**: Falls back to `gh` CLI automatically

### Common Issues:
- **Process Fails**: AI can retry with different parameters or suggest manual steps
- **Invalid release notes**: Review format requirements and regenerate

---

*Use the appropriate master prompt above to start your next release.*