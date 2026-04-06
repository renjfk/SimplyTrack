# AGENTS.md - SimplyTrack

Guidelines for AI agents working in this repository. Keep this file concise -
only document constraints and rules an agent would get wrong without being told.
Implementation details belong in code comments, not here.

## Project Overview

**SimplyTrack** is a native macOS menu bar app built with Swift, SwiftUI, and SwiftData.
Tracks app and website usage locally. No web tech stack (no JS/TS/npm).

- **Min deployment target:** macOS 14.6 (per-target override; project-level default is 15.5)
- **Build system:** Xcode (`.xcodeproj`, no SPM `Package.swift` at root)
- **SPM dependencies:** `modelcontextprotocol/swift-sdk` (>=0.10.2), `apple/swift-nio` (>=2.86.2)

## Architecture

Four targets in the Xcode project:

- `SimplyTrack` - main menu bar app (scheme: `SimplyTrack`)
- `SimplyTrackMCP` - CLI helper, bridges stdio to Unix domain sockets for AI client IPC (scheme: `SimplyTrackMCP`)
- `SimplyTrackTests` - unit tests using Swift Testing framework
- `SimplyTrackUITests` - UI tests using XCTest

### Key Invariants

- Singletons for managers: `static let shared` with `private init()`
- Services contain business logic; Managers handle system resources
- `@MainActor` on all UI-related services and views
- Swift `actor` for thread-safe concurrent types (e.g., `MCPServer`)
- `#if DEBUG` / `#else` for environment-specific behavior (separate databases, socket paths)
- `BrowserInterface` protocol for browser-specific implementations

### Directory Structure

```
SimplyTrack/
  App/          # Entry point, AppDelegate
  Managers/     # Singleton managers (Database, Keychain, Permissions, etc.)
  Models/       # SwiftData @Model types and enums
  Services/     # Business logic (tracking, IPC, notifications)
    Browsers/   # Browser-specific implementations
  Utils/        # Extensions, helpers, aggregators
  Views/        # SwiftUI views
    Settings/   # Settings-related views
SimplyTrackMCP/ # Flat structure: main.swift, MCPServer.swift, IPCClient.swift
```

## Build Commands

```bash
xcodebuild -project SimplyTrack.xcodeproj -scheme SimplyTrack -configuration Debug build
xcodebuild -project SimplyTrack.xcodeproj -scheme SimplyTrack -configuration Release build
xcodebuild -project SimplyTrack.xcodeproj -scheme SimplyTrackMCP -configuration Debug build
xcodebuild -project SimplyTrack.xcodeproj -scheme SimplyTrack test
xcodebuild -project SimplyTrack.xcodeproj -scheme SimplyTrack \
  test -only-testing:SimplyTrackTests/SimplyTrackTests/example
swift-format --in-place --recursive SimplyTrack/ SimplyTrackMCP/ SimplyTrackTests/ SimplyTrackUITests/
swift-format lint --recursive SimplyTrack/
```

Verify changes: build + test with zero failures. Always run `swift-format --in-place` on files you modify.

## Code Style

- **Formatting**: enforced by `swift-format` with pre-commit hook. Config in `.swift-format` (200 char line length, 4-space indent)
- **Imports**: alphabetically sorted, no blank lines between them
- **Naming**: PascalCase types, camelCase everything else. Booleans use `is`/`has`/`can`/`show` prefix. No UPPER_SNAKE constants
- **File headers**: every file starts with `// FileName.swift // SimplyTrack` comment block
- **Organization**: `// MARK: -` sections within files. `///` doc comments on public API
- **Errors**: `do/catch` for recoverable, `guard` for preconditions, `Logger` (from `os`) for structured logging
- **Concurrency**: prefer `async/await` and `Task { }`. Use `@MainActor` for UI, avoid `DispatchQueue.main`

## Testing

- **Unit tests**: Swift Testing (`import Testing`, `@Test`, `#expect(...)`) with `@testable import SimplyTrack`
- **UI tests**: XCTest (`import XCTest`) - do NOT use `@testable import`, runs against built app

## CI/CD

Release via `workflow_dispatch` in `.github/workflows/release.yml`. Versioning is major.minor only (no patch).
Pipeline: tag + version bump -> archive + sign -> DMG (`appdmg`) -> notarize -> GitHub Release.
