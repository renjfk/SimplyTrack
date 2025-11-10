//
//  PermissionManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 02.09.2025.
//

import AppKit
import ApplicationServices
import Foundation

/// Status of macOS system permissions required for app functionality.
/// Used to track automation permissions needed for browser integration.
enum PermissionStatus {
    /// Permission has been granted by the user
    case granted
    /// Permission has been explicitly denied by the user
    case denied
    /// Permission status has not yet been determined
    case notDetermined
}

/// Manages macOS system permissions required for browser automation and website tracking.
/// Monitors AppleScript automation permissions and provides UI feedback for permission states.
/// Coordinates with WebTrackingService to handle browser communication errors.
class PermissionManager: ObservableObject {
    /// Shared singleton instance for permission management
    static let shared = PermissionManager()

    /// Current status of automation permissions for browser AppleScript access
    @Published var automationPermissionStatus: PermissionStatus = .notDetermined
    /// Current status of System Events automation permissions (needed for Safari private browsing detection)
    @Published var systemEventsPermissionStatus: PermissionStatus = .notDetermined
    /// Current status of Accessibility permissions (needed for Safari private browsing detection)
    @Published var accessibilityPermissionStatus: PermissionStatus = .notDetermined
    /// Most recent error message from browser communication attempts
    @Published var lastError: String? = nil

    private let supportedBrowserBundleIds = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.brave.Browser",
    ]

    private init() {
        // Don't check permissions on init - let background tracking handle it
    }

    /// Updates permission status based on browser AppleScript execution results.
    /// Called by WebTrackingService when AppleScript operations succeed or fail.
    /// - Parameter success: Whether the AppleScript operation was successful
    func handleBrowserPermissionResult(success: Bool) {
        Task { @MainActor in
            if success {
                self.automationPermissionStatus = .granted
            } else {
                self.automationPermissionStatus = .denied
            }
        }
    }

    /// Updates System Events permission status based on AppleScript execution results.
    /// Called by Safari browser when System Events operations succeed or fail.
    /// - Parameter success: Whether the System Events AppleScript operation was successful
    func handleSystemEventsPermissionResult(success: Bool) {
        Task { @MainActor in
            if success {
                self.systemEventsPermissionStatus = .granted
            } else {
                self.systemEventsPermissionStatus = .denied
            }
        }
    }

    /// Updates Accessibility permission status based on AppleScript execution results.
    /// Called by Safari browser when Accessibility operations succeed or fail.
    /// - Parameter success: Whether the Accessibility operation was successful
    func handleAccessibilityPermissionResult(success: Bool) {
        Task { @MainActor in
            if success {
                self.accessibilityPermissionStatus = .granted
            } else {
                self.accessibilityPermissionStatus = .denied
            }
        }
    }

    /// Opens System Preferences to the Automation privacy settings.
    /// Allows users to grant AppleScript permissions for browser automation and System Events access.
    func openSystemPreferences() {
        // Open Security & Privacy > Privacy > Automation in System Preferences
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    /// Opens System Preferences to the Accessibility privacy settings.
    /// Allows users to grant Accessibility permissions for Safari private browsing detection.
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Records browser communication errors for UI display.
    /// - Parameter errorMessage: Description of the browser communication error
    func handleBrowserError(_ errorMessage: String) {
        Task { @MainActor in
            self.lastError = errorMessage
        }
    }

    /// Clears the current error message from the UI state.
    func clearError() {
        Task { @MainActor in
            self.lastError = nil
        }
    }
}
