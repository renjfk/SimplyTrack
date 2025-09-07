# MCP Release Process Example

This document shows an example of how the MCP-driven release process works in practice with Claude Desktop.

## Example Session: Creating Release v1.2.0

### User Input (Claude Desktop)
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
[Only if breaking changes exist]
* Description focusing on user impact ([abc1234](commit-link))

### ✨ New Features
* Feature description emphasizing user benefit ([abc1234](commit-link))

### 🚀 Improvements  
* Improvement description with user impact ([abc1234](commit-link))

### 🐛 Bug Fixes
* Fix description focusing on resolved user issue ([abc1234](commit-link))

---
**Release Type**: [major/minor/patch]
**Commits**: [count] 
**Generated**: [timestamp]

REQUIREMENTS:
- Focus ONLY on user-facing changes and impact
- EXCLUDE: docs, build, ci, chore, refactor, test commits  
- Use active voice, present tense
- Include working GitHub commit links
- Determine semantic version based on changes
- Show this preview BEFORE any actions

STEP 3: SHOW PREVIEW
Display the generated release notes and ask for approval before proceeding.

STEP 4: TRIGGER WORKFLOW (after approval)
Use GitHub MCP to trigger the "Build and Release" workflow with:
- release_tag: v[VERSION]  
- release_notes: [generated content]
- draft: true
- prerelease: false (unless specified)

Please start with Step 1 - analyze the commits and show me the preview.
```

### Expected Claude Response

```
I'll help you create a new release for SimplyTrack using GitHub MCP. Let me start by analyzing the commits since the last release.

**STEP 1: ANALYZING COMMITS**

🔍 Getting latest release tag...
Latest release: v1.1 (released 2024-08-15)

🔍 Fetching commits between v1.1 and HEAD...
Found 12 commits to analyze

**STEP 2: GENERATING RELEASE NOTES**

After analyzing the commits, I've categorized the user-facing changes:

📋 **RELEASE NOTES PREVIEW:**

## SimplyTrack v1.2

### ✨ New Features
* Added dark mode support with automatic system preference detection (b29ffaf)
* Implemented export to CSV functionality for time tracking data (bd32f00)  
* Added keyboard shortcuts for common actions (⌘N, ⌘E, ⌘S) (ab5b664)

### 🚀 Improvements
* Improved app startup time by 40% through optimized data loading (d24b0ad)
* Enhanced memory usage efficiency for large datasets (f72d4cb)
* Streamlined preferences interface with better organization (a1c2d3e)

### 🐛 Bug Fixes
* Fixed crash when opening app on macOS Sonoma (e4f5g6h)
* Resolved timezone display issues in time reports (i7j8k9l)
* Fixed memory leak in background time tracking (m0n1p2q)

---
**Release Type**: minor
**Commits**: 12
**Generated**: 2024-09-07 15:30:00 UTC

**STEP 3: PREVIEW CONFIRMATION**

✅ **Analysis Summary:**
- **New Features**: 3 (dark mode, CSV export, keyboard shortcuts)
- **Improvements**: 3 (performance and UX enhancements)  
- **Bug Fixes**: 3 (crash fixes and memory issues)
- **Excluded**: 3 commits (docs updates, test changes, CI improvements)
- **Suggested Version**: v1.2 (minor release due to new features)

**Does this look correct? Should I proceed to trigger the release workflow with these parameters?**

- release_tag: `v1.2`
- release_notes: [the content above]
- draft: `true`
- prerelease: `false`

Please confirm to proceed with **STEP 4: TRIGGER WORKFLOW**.
```

### User Confirmation
```
Yes, this looks perfect! Please proceed to trigger the workflow.
```

### Final Claude Response

```
**STEP 4: TRIGGERING WORKFLOW**

🚀 Dispatching GitHub Actions workflow...

✅ **Workflow Triggered Successfully!**

**Workflow Details:**
- **Workflow**: Build and Release
- **Run ID**: #42
- **Parameters**:
  - release_tag: `v1.2`
  - release_notes: [generated content]
  - draft: `true`
  - prerelease: `false`

**Next Steps:**
1. 🔄 **Monitor Progress**: The workflow is now building and signing the app
2. ⏱️ **Estimated Time**: 15-20 minutes for complete build and notarization
3. 📦 **Draft Release**: Will be created automatically when workflow completes
4. ✅ **Review & Publish**: Check the draft release and publish when ready

**Workflow URL**: https://github.com/user/SimplyTrack/actions/runs/12345

You can monitor the progress in GitHub Actions. I'll be here if you need help with any issues or want to create additional releases!
```

## Commit Analysis Examples

### Example Commits Processed

**Included (User-facing):**
```
b29ffaf - feat: add dark mode toggle in preferences
bd32f00 - fix: resolve crash on macOS Sonoma startup  
ab5b664 - feat: implement CSV export for time data
d24b0ad - perf: optimize app startup time by 40%
f72d4cb - fix: resolve timezone display in reports
```

**Excluded (Technical):**
```
a1b2c3d - docs: update README with new screenshots
e4f5g6h - test: add unit tests for time calculation
i7j8k9l - ci: update GitHub Actions workflow
m0n1o2p - chore: update dependencies to latest versions
q2r3s4t - refactor: restructure data models
```

### Version Detection Logic

**Patch Release** (1.1.0 → 1.1.1):
- Only `fix:` commits found
- No new features or breaking changes

**Minor Release** (1.1.0 → 1.2.0):
- Contains `feat:` commits (new features)
- Performance improvements
- No breaking changes

**Major Release** (1.2.0 → 2.0.0):
- Breaking changes detected:
  - "BREAKING CHANGE:" in commit body
  - "!" after commit type (feat!:, fix!:)
  - Major API changes

## Error Handling Examples

### No Commits Found
```
❌ **No New Commits**

I found that there are no new commits since the last release (v1.1.0).

**Possible Actions:**
1. Check if you're on the right branch
2. Ensure commits have been pushed to remote
3. Consider if a release is actually needed

Would you like me to check a different branch or time range?
```

### Workflow Dispatch Failure
```
❌ **Workflow Trigger Failed**

Error: Insufficient permissions to trigger workflow

**Troubleshooting Steps:**
1. Verify GitHub MCP has `actions:write` permission
2. Check that the workflow file exists: `.github/workflows/release.yml`
3. Ensure you have admin/write access to the repository

**Alternative**: You can manually trigger the workflow in GitHub Actions with these parameters:
- release_tag: `v1.2`
- release_notes: [generated content shown above]

Would you like me to try again or help with manual execution?
```

## Integration Testing

To test this MCP integration:

1. **Verify MCP Setup**
   ```bash
   # Check if GitHub MCP server is running
   # In Claude Desktop, test basic commands first
   ```

2. **Test with Small Changes**
   ```
   Create a patch release for testing - analyze only the last 1-2 commits and generate minimal release notes.
   ```

3. **Validate Workflow Parameters**
   - Ensure `release.yml` accepts the expected input parameters
   - Test workflow dispatch functionality
   - Verify release notes formatting in GitHub

4. **End-to-End Test**
   - Use the full master prompt
   - Review generated release notes carefully  
   - Confirm workflow executes successfully
   - Validate final GitHub release

This example demonstrates the seamless integration between Claude Desktop, GitHub MCP, and the automated release workflow, providing a controlled and efficient release process.