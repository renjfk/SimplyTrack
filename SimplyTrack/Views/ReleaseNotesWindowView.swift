//
//  ReleaseNotesWindowView.swift
//  SimplyTrack
//
//  Displays release notes in an independent window for menu bar apps
//

import AppKit
import SwiftUI

/// View that displays release notes in a standalone window.
/// Used when the app starts hidden and needs to show release notes independently of the main popover.
struct ReleaseNotesWindowView: View {
    let releaseNotesContent: String
    let versionRange: String
    let onClose: (Bool) -> Void

    @State private var neverShowAgain = false

    private var releaseNotesLines: [String] {
        releaseNotesContent.components(separatedBy: .newlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("What's New in SimplyTrack")
                            .font(.headline)
                        Text("Version \(versionRange)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()

                Divider()
            }

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(releaseNotesLines, id: \.self) { line in
                        formatMarkdownLine(line)
                    }
                }
                .padding()
            }

            // Footer
            VStack(spacing: 0) {
                Divider()

                HStack {
                    Toggle("Never show release notes", isOn: $neverShowAgain)
                        .toggleStyle(.checkbox)

                    Spacer()

                    Button("Close") {
                        onClose(neverShowAgain)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func formatMarkdownLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            Text("")
                .frame(height: 6)
        } else if trimmed.hasPrefix("## ") {
            // Header
            Text(String(trimmed.dropFirst(3)))
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else if trimmed.hasPrefix("### ") {
            // Subheader
            Text(String(trimmed.dropFirst(4)))
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("- ") {
            // Bullet point
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                formatBulletText(String(trimmed.dropFirst(2)))
                Spacer()
            }
        } else if trimmed.hasPrefix("*") && trimmed.hasSuffix("*") && trimmed.count > 2 {
            // Italic text
            Text(String(trimmed.dropFirst().dropLast()))
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Regular text
            Text(trimmed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func formatBulletText(_ text: String) -> some View {
        // Look for commit hash pattern: (abc1234) at the end
        let commitPattern = #/\(([a-f0-9]{6,8})\)$/#

        if let match = text.firstMatch(of: commitPattern) {
            let commitHash = String(match.1)
            let textWithoutCommit = String(text.prefix(text.count - match.0.count)).trimmingCharacters(in: .whitespaces)
            let commitURL = "https://github.com/renjfk/SimplyTrack/commit/\(commitHash)"

            HStack(spacing: 4) {
                Text(textWithoutCommit)
                Text("(")
                    .foregroundColor(.secondary)
                Link(commitHash, destination: URL(string: commitURL)!)
                    .font(.system(.body, design: .monospaced))
                Text(")")
                    .foregroundColor(.secondary)
            }
        } else {
            Text(text)
        }
    }
}

#Preview {
    ReleaseNotesWindowView(
        releaseNotesContent: """
            ## v0.3
            *Released: 10 Sep 2025*

            ### ✨ New Features
            - Add automatic release notes notifications when updates are available (84e04f3)

            ### 🐛 Bug Fixes
            - Fix notification clicks not properly navigating to yesterday's data (5569a33)

            ## v0.2
            *Released: 10 Sep 2025*

            ### ✨ New Features
            - Add scheduled morning summary notifications with AI-generated insights of previous day's usage (88bc2a8)
            - Add comprehensive settings dialog with General and AI configuration tabs (88bc2a8)
            - Add OpenAI Chat Completion API integration with secure keychain storage for customizable AI insights (88bc2a8)
            - Add clear data action for current day or week view with confirmation dialog (5fd4bf0)
            - Add customizable notification time and prompt configuration in settings (88bc2a8)

            ### 🚀 Improvements
            - Move "Launch at Login" setting to centralized settings window for better organization (88bc2a8)
            - Use separate database and yellow icon during development to avoid overwriting release app data (41ddfed)

            ### 🐛 Bug Fixes
            - Fix "today" view to automatically update to current day when app remains open overnight (b29ffaf)
            - Remove duplicate DMG artifacts from release builds to clean up downloads (bd32f00)

            ## v0.1
            *Released: 5 Sep 2025*

            ### ✨ New Features
            - Initial release of SimplyTrack - comprehensive app and website usage tracking for macOS
            - Real-time monitoring of foreground applications and active browser tabs  
            - Beautiful SwiftUI interface with daily and weekly usage views
            - Automatic idle detection to track only active usage time
            - Menu bar integration with clean popover interface
            - Launch at login support for seamless background tracking
            - Secure local data storage with SwiftData
            """,
        versionRange: "0.1 - 0.2",
        onClose: { _ in }
    )
}
