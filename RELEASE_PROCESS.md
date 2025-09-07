# Manual Release Process Guide

This document describes the step-by-step manual release process for SimplyTrack using GitHub MCP integration through Claude Desktop to analyze commits, generate release notes, preview in artifacts, and trigger the GitHub Actions workflow - all handled via MCP.

## Overview

The manual release process involves:

1. **MCP-driven commit analysis** - Claude Desktop fetches and analyzes commit history
2. **AI-generated release notes** following strict formatting conventions
3. **Preview in artifacts** - release notes shown before any actions taken
4. **Human review and approval** for quality control
5. **MCP workflow dispatch** - trigger GitHub Actions via MCP
6. **Automated build and release** - existing workflow handles the rest
7. **User-facing focus** filtering out technical commits

## Prerequisites

- Claude Desktop with GitHub MCP server configured
- GitHub repository access (MCP handles authentication)
- Understanding of conventional commit patterns
- Familiarity with major.minor versioning (no patch versions)

## Complete MCP-Driven Release Process

Use this single prompt in Claude Desktop to handle the entire release process:

### Master Release Prompt for Claude Desktop

```
I need to create a new release for SimplyTrack. Please use GitHub MCP to:

STEP 1: ANALYZE COMMITS
- Get the latest release tag from the repository
- Fetch all commits between that tag and current HEAD
- Analyze each commit for user-facing changes

STEP 2: GENERATE RELEASE NOTES
Create structured release notes with this EXACT format:

## SimplyTrack v[VERSION]

### ⚠️ Breaking Changes
[Only if breaking changes exist - triggers major version]
* Description focusing on user impact (abc1234)

### ✨ New Features
* Feature description emphasizing user benefit (abc1234)

### 🚀 Improvements  
* Improvement description with user impact (abc1234)

### 🐛 Bug Fixes
* Fix description focusing on resolved user issue (abc1234)

---
**Release Type**: [major/minor]
**Commits**: [count] 
**Generated**: [timestamp]

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
- release_tag: v[VERSION]  
- release_notes: [generated content]
- draft: true
- prerelease: false (unless specified)

For pre-releases, add "prerelease: true" to STEP 4.
For beta versions, use format like "v1.2-beta.1".

Please start with Step 1 - analyze the commits and show me the preview.
```

## How It Works

Claude Desktop will:
1. **Analyze commits** since last release via GitHub MCP
2. **Generate release notes** with proper formatting and categorization  
3. **Show preview** and ask for approval
4. **Trigger GitHub Actions workflow** with the release notes

## Features

- **Automatic filtering** of technical commits (docs, tests, CI, etc.)
- **User-focused** release notes with clear impact descriptions
- **Smart versioning** - minor for features/fixes, major for breaking changes
- **Preview before action** - human approval required

## Troubleshooting

- **No MCP Connection**: Ensure GitHub MCP server is running
- **Permission Denied**: Verify MCP has workflow dispatch permissions
- **Process Fails**: Claude can retry with different parameters or suggest manual steps

---

*Use the master prompt in Claude Desktop to start your next release. The entire process from commit analysis to workflow trigger will be handled automatically with human approval checkpoints.*