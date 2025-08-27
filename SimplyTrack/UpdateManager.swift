//
//  UpdateManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 05.09.2025.
//

import Foundation
import AppKit
import UserNotifications
import CryptoKit

struct NotificationConstants {
    static let updateCategoryIdentifier = "UPDATE_AVAILABLE"
    static let installActionIdentifier = "INSTALL_UPDATE"
    static let laterActionIdentifier = "LATER"
    static let updateNotificationIdentifier = "update-available"
}

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

enum UpdateError: LocalizedError {
    case noInternetConnection
    case invalidResponse
    case noUpdateAvailable
    case dmgAssetNotFound
    case checksumAssetNotFound
    case downloadFailed
    case checksumValidationFailed
    case mountFailed
    case replacementFailed
    case cleanupFailed
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
        case .mountFailed:
            return "Failed to mount DMG"
        case .replacementFailed:
            return "Failed to replace application"
        case .cleanupFailed:
            return "Failed to cleanup temporary files"
        case .invalidVersion:
            return "Invalid version format"
        }
    }
}

@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    private var isCheckingForUpdates = false
    private var isDownloadingInstaller = false
    private var availableUpdate: GitHubRelease?
    private var lastUpdateCheck: Date?
    
    private let githubAPIURL = "https://api.github.com/repos/renjfk/SimplyTrack/releases/latest"
    
    private init() {}
    
    private func executeCommand(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil
    ) async throws -> (output: String, error: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        
        if let workingDirectory = workingDirectory {
            task.currentDirectoryURL = workingDirectory
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        try task.run()
        task.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return (output: output, error: error, status: task.terminationStatus)
    }
    
    func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
    
    func checkForUpdates(showNotification: Bool = false) async throws -> Bool {
        guard !isCheckingForUpdates && !isDownloadingInstaller else {
            return availableUpdate != nil
        }
        
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        
        do {
            let release = try await fetchLatestRelease()
            lastUpdateCheck = Date()
            
            let currentVersion = getCurrentVersion()
            let latestVersion = cleanVersionString(release.tagName)
            
            if isNewerVersion(latestVersion, than: currentVersion) {
                availableUpdate = release
                if showNotification {
                    try await showUpdateNotification()
                }
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
    
    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: githubAPIURL) else {
            throw UpdateError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.invalidResponse
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return release
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
              httpResponse.statusCode == 200 else {
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
              httpResponse.statusCode == 200 else {
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
