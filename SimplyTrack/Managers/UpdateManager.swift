//
//  UpdateManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 05.09.2025.
//

import AppKit
import CryptoKit
import Foundation
import SwiftUI
import UserNotifications

/// Constants for update notification identifiers and categories.
/// Used by UpdateManager and NotificationService for coordinating update notifications.
struct NotificationConstants {
    static let updateCategoryIdentifier = "UPDATE_AVAILABLE"
    static let installActionIdentifier = "INSTALL_UPDATE"
    static let laterActionIdentifier = "LATER"
    static let updateNotificationIdentifier = "update-available"
}

/// User-configurable frequency for checking software updates.
/// Determines how often the app checks GitHub releases for new versions.
enum UpdateFrequency: String, CaseIterable, RawRepresentable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case never = "Never"
}

/// GitHub API response structure for release information.
/// Contains version details, release notes, and downloadable assets.
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case assets
    }
}

/// Individual downloadable file within a GitHub release.
/// Represents DMG installers, checksums, and other release artifacts.
struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// Errors that can occur during the update check and installation process.
/// Covers network issues, file validation, and installation failures.
enum UpdateError: LocalizedError {
    case noInternetConnection
    case invalidResponse
    case noUpdateAvailable
    case dmgAssetNotFound
    case checksumAssetNotFound
    case downloadFailed
    case checksumValidationFailed
    case invalidVersion

    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection available"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .noUpdateAvailable:
            return "No update available"
        case .dmgAssetNotFound:
            return "DMG file not found in release"
        case .checksumAssetNotFound:
            return "Checksum file not found in release"
        case .downloadFailed:
            return "Failed to download update"
        case .checksumValidationFailed:
            return "Downloaded file failed checksum validation"
        case .invalidVersion:
            return "Invalid version format"
        }
    }
}

/// Manages software updates by checking GitHub releases and handling installations.
/// Provides automatic update checking, secure download validation, and user notifications.
/// Integrates with the notification system to inform users of available updates.
@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private var isCheckingForUpdates = false
    private var isDownloadingInstaller = false
    private var availableUpdate: GitHubRelease?

    @AppStorage("updateFrequency", store: .app) private var updateFrequency: UpdateFrequency = .daily
    @AppStorage("lastUpdateCheck", store: .app) private var lastUpdateCheck: Double = 0

    private let githubAPIURL = "https://api.github.com/repos/renjfk/SimplyTrack/releases/latest"
    private let githubAllReleasesURL = "https://api.github.com/repos/renjfk/SimplyTrack/releases"

    private init() {}

    /// Gets the current app version from the bundle info.
    /// - Returns: Version string from CFBundleShortVersionString, "0.0" if not found
    func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Gets the user's configured update check frequency.
    /// - Returns: Current update frequency setting
    func getUpdateFrequency() -> UpdateFrequency {
        return updateFrequency
    }

    /// Checks for available updates from GitHub releases.
    /// Respects user's frequency settings and prevents duplicate notifications.
    /// - Parameter ignoreLastUpdate: Whether to bypass frequency throttling
    /// - Returns: True if an update is available, false otherwise
    /// - Throws: UpdateError for network or parsing failures
    func checkForUpdates(ignoreLastUpdate: Bool = false) async throws -> Bool {
        guard !isCheckingForUpdates && !isDownloadingInstaller else {
            return availableUpdate != nil
        }

        // Check if we should skip based on frequency setting
        if !ignoreLastUpdate && !shouldCheckForUpdates() {
            return availableUpdate != nil
        }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let release = try await fetchLatestRelease()

            let currentVersion = getCurrentVersion()
            let latestVersion = cleanVersionString(release.tagName)

            // Only update timestamp after successful check
            lastUpdateCheck = Date().timeIntervalSince1970

            if isNewerVersion(latestVersion, than: currentVersion) {
                availableUpdate = release
                try await showUpdateNotification()
                return true
            } else {
                availableUpdate = nil
                return false
            }
        } catch {
            availableUpdate = nil
            throw error
        }
    }

    private func showUpdateNotification() async throws {
        let content = UNMutableNotificationContent()
        content.title = "SimplyTrack Update Available"
        content.body = "A new version is ready to install. Click to download and open the installer."
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationConstants.updateCategoryIdentifier

        let request = UNNotificationRequest(
            identifier: NotificationConstants.updateNotificationIdentifier,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    private func shouldCheckForUpdates() -> Bool {
        // Never check if frequency is set to never
        guard updateFrequency != .never else { return false }

        // Always check if no previous check
        guard lastUpdateCheck > 0 else { return true }

        let now = Date()
        let lastCheckDate = Date(timeIntervalSince1970: lastUpdateCheck)
        let timeSinceLastCheck = now.timeIntervalSince(lastCheckDate)

        switch updateFrequency {
        case .daily:
            return timeSinceLastCheck >= 24 * 60 * 60  // 24 hours
        case .weekly:
            return timeSinceLastCheck >= 7 * 24 * 60 * 60  // 7 days
        case .monthly:
            return timeSinceLastCheck >= 30 * 24 * 60 * 60  // 30 days
        case .never:
            return false
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: githubAPIURL) else {
            throw UpdateError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw UpdateError.invalidResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return release
    }

    /// Fetches release notes for all versions between the last launched version and current version.
    /// - Parameters:
    ///   - lastVersion: The version that was last launched (empty string for first launch)
    ///   - currentVersion: The current app version
    /// - Returns: Combined release notes content and version range string, or nil if no releases found
    /// - Throws: UpdateError for network or parsing failures
    func fetchReleaseNotesSince(lastVersion: String, currentVersion: String) async throws -> (content: String, versionRange: String)? {
        guard let url = URL(string: githubAllReleasesURL) else {
            throw UpdateError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw UpdateError.invalidResponse
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

        // Filter releases between lastVersion and currentVersion
        let relevantReleases = filterReleasesBetweenVersions(
            releases: releases,
            fromVersion: lastVersion,
            toVersion: currentVersion
        )

        guard !relevantReleases.isEmpty else {
            return nil
        }

        // Combine release notes from all relevant versions
        let combinedContent = combineReleaseNotes(releases: relevantReleases)
        let versionRange = createVersionRange(releases: relevantReleases, currentVersion: currentVersion)

        return (content: combinedContent, versionRange: versionRange)
    }

    private func filterReleasesBetweenVersions(releases: [GitHubRelease], fromVersion: String, toVersion: String) -> [GitHubRelease] {
        let cleanToVersion = cleanVersionString(toVersion)
        let cleanFromVersion = fromVersion.isEmpty ? "" : cleanVersionString(fromVersion)

        return releases.filter { release in
            let releaseVersion = cleanVersionString(release.tagName)

            // Always include the current version
            if releaseVersion == cleanToVersion {
                return true
            }

            // If no previous version, include all older releases
            if fromVersion.isEmpty {
                return isNewerVersion(cleanToVersion, than: releaseVersion)
            }

            // Include releases newer than fromVersion but older than toVersion
            return isNewerVersion(releaseVersion, than: cleanFromVersion) && !isNewerVersion(releaseVersion, than: cleanToVersion)
        }
    }

    private func combineReleaseNotes(releases: [GitHubRelease]) -> String {
        // Sort releases by version in descending order (newest first)
        let sortedReleases = releases.sorted { release1, release2 in
            let version1 = cleanVersionString(release1.tagName)
            let version2 = cleanVersionString(release2.tagName)
            return isNewerVersion(version1, than: version2)
        }

        var combinedContent = ""

        for release in sortedReleases {
            let version = cleanVersionString(release.tagName)
            let publishDate = formatPublishDate(release.publishedAt)

            combinedContent += "## \(release.name.isEmpty ? "Version \(version)" : release.name)\n"
            if !publishDate.isEmpty {
                combinedContent += "*Released: \(publishDate)*\n\n"
            }
            combinedContent += "\(release.body)\n\n"
        }

        return combinedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createVersionRange(releases: [GitHubRelease], currentVersion: String) -> String {
        guard !releases.isEmpty else { return currentVersion }

        if releases.count == 1 {
            return cleanVersionString(releases[0].tagName)
        }

        let versions = releases.map { cleanVersionString($0.tagName) }
        let sortedVersions = versions.sorted { isNewerVersion($1, than: $0) }  // oldest first

        if let oldest = sortedVersions.first, let newest = sortedVersions.last {
            return "\(oldest) - \(newest)"
        }

        return currentVersion
    }

    private func formatPublishDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: dateString) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func cleanVersionString(_ version: String) -> String {
        return version.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(v1Components.count, v2Components.count)

        for i in 0..<maxCount {
            let v1Part = i < v1Components.count ? v1Components[i] : 0
            let v2Part = i < v2Components.count ? v2Components[i] : 0

            if v1Part > v2Part {
                return true
            } else if v1Part < v2Part {
                return false
            }
        }

        return false
    }

    /// Downloads the update installer and opens it for user installation.
    /// Validates checksums for security and terminates the app to allow installation.
    /// - Throws: UpdateError for download, validation, or file system failures
    func downloadAndOpenInstaller() async throws {
        guard !isCheckingForUpdates && !isDownloadingInstaller else {
            return
        }

        guard let release = availableUpdate else {
            throw UpdateError.noUpdateAvailable
        }

        guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
            throw UpdateError.dmgAssetNotFound
        }

        guard let checksumAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg.sha256") }) else {
            throw UpdateError.checksumAssetNotFound
        }

        isDownloadingInstaller = true

        defer {
            isDownloadingInstaller = false
        }

        do {
            let dmgURL = try await downloadDMG(from: dmgAsset.browserDownloadUrl)
            try await validateChecksum(dmgURL: dmgURL, checksumURL: checksumAsset.browserDownloadUrl)

            // Open the DMG for user to install manually
            _ = await MainActor.run {
                NSWorkspace.shared.open(dmgURL)
            }

            // Exit the app so user can install the update
            await MainActor.run {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            throw error
        }
    }

    private func downloadDMG(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw UpdateError.downloadFailed
        }

        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileName = url.lastPathComponent
        let localURL = downloadsDir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }

        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw UpdateError.downloadFailed
        }

        // Verify the file was downloaded and has content
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
            throw UpdateError.downloadFailed
        }

        do {
            try FileManager.default.moveItem(at: tempURL, to: localURL)
        } catch {
            throw UpdateError.downloadFailed
        }

        // Verify the moved file still exists and has the same size
        let finalAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        guard let finalFileSize = finalAttributes[.size] as? Int64, finalFileSize == fileSize else {
            throw UpdateError.downloadFailed
        }

        return localURL
    }

    private func validateChecksum(dmgURL: URL, checksumURL: String) async throws {
        guard let url = URL(string: checksumURL) else {
            throw UpdateError.downloadFailed
        }

        // Download checksum file
        let (checksumData, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw UpdateError.downloadFailed
        }

        guard let checksumContent = String(data: checksumData, encoding: .utf8) else {
            throw UpdateError.downloadFailed
        }

        // Extract expected checksum (format: "checksum  filename")
        let checksumLine = checksumContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = checksumLine.components(separatedBy: .whitespaces)
        guard let expectedChecksum = components.first else {
            throw UpdateError.downloadFailed
        }

        // Calculate actual checksum of downloaded DMG
        let dmgData = try Data(contentsOf: dmgURL)
        let actualChecksum = SHA256.hash(data: dmgData)
        let actualChecksumString = actualChecksum.compactMap { String(format: "%02x", $0) }.joined()

        // Compare checksums
        guard expectedChecksum.lowercased() == actualChecksumString.lowercased() else {
            // Remove corrupted file
            try? FileManager.default.removeItem(at: dmgURL)
            throw UpdateError.checksumValidationFailed
        }
    }
}
