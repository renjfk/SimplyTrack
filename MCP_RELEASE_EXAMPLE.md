# MCP Release Process Example

Example of the MCP-driven release process with Claude Desktop.

## Example Session

### User Prompt
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

### Claude Response

```
**STEP 1: ANALYZING COMMITS**

Latest release: v1.1
Found 8 commits to analyze

**STEP 2: GENERATING RELEASE NOTES**

## SimplyTrack v1.2

### ✨ New Features
* Added dark mode support with automatic system preference detection (b29ffaf)
* Implemented export to CSV functionality for time tracking data (bd32f00)

### 🐛 Bug Fixes
* Fixed crash when opening app on macOS Sonoma (e4f5g6h)
* Resolved timezone display issues in time reports (i7j8k9l)

---
**Release Type**: minor
**Commits**: 8
**Generated**: 2024-09-07 15:30:00 UTC

**Does this look correct? Should I proceed to trigger the release workflow?**

- release_tag: `v1.2`
- draft: `true`
```

### User Confirmation
```
Yes, proceed.
```

### Final Response
```
**STEP 4: TRIGGERING WORKFLOW**

✅ Workflow triggered successfully!
Run ID: #42
Monitor at: https://github.com/user/SimplyTrack/actions/runs/12345
```

## What Gets Included/Excluded

**Included:**
- `feat:` - New features
- `fix:` - Bug fixes  
- `perf:` - Performance improvements
- Other user-facing changes

**Excluded:**
- `docs:` - Documentation
- `test:` - Tests
- `ci:` - CI/CD changes
- `chore:` - Maintenance
- `refactor:` - Code restructuring