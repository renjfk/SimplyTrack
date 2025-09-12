//
//  PermissionManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 02.09.2025.
//

import Foundation
import AppKit
import ApplicationServices

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
        "org.mozilla.firefox",
        "com.operasoftware.Opera", 
        "com.brave.Browser"
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
    
    /// Determines if website tracking is currently possible.
    /// - Returns: True if automation permissions are granted
    func canTrackWebsites() -> Bool {
        return automationPermissionStatus == .granted
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
    
    
    // MARK: - System Events Permissions
    
    /// Checks System Events automation permissions by attempting to access System Events.
    /// This tests the specific permission needed for Safari private browsing detection.
    /// - Returns: Current System Events automation permission status
    func checkSystemEventsPermissions() -> PermissionStatus {
        let testScript = """
        tell application "System Events"
            try
                -- Simple test to see if we can access System Events
                return name of first process
            on error
                return "denied"
            end try
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: testScript)
        let result = appleScript?.executeAndReturnError(&error)
        
        let status: PermissionStatus
        if let error = error {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? -1
            // Error -1743 or -1744 typically indicate permission issues
            status = (errorCode == -1743 || errorCode == -1744) ? .denied : .notDetermined
        } else if let result = result, result.stringValue != "denied" {
            status = .granted
        } else {
            status = .denied
        }
        
        Task { @MainActor in
            self.systemEventsPermissionStatus = status
        }
        
        return status
    }
    
    // MARK: - Accessibility Permissions
    
    /// Checks the current status of Accessibility permissions.
    /// Required for Safari private browsing detection via UI automation.
    /// - Returns: Current accessibility permission status
    func checkAccessibilityPermissions() -> PermissionStatus {
        let hasPermission = AXIsProcessTrusted()
        let status: PermissionStatus = hasPermission ? .granted : .denied
        
        Task { @MainActor in
            self.accessibilityPermissionStatus = status
        }
        
        return status
    }
    
    /// Requests Accessibility permissions by showing the system dialog.
    /// This will prompt the user to grant permissions if not already granted.
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        Task { @MainActor in
            self.accessibilityPermissionStatus = hasPermission ? .granted : .denied
        }
    }
    
    /// Determines if Safari private browsing detection is currently possible.
    /// - Returns: True if both System Events and Accessibility permissions are granted
    func canDetectSafariPrivateBrowsing() -> Bool {
        return systemEventsPermissionStatus == .granted && accessibilityPermissionStatus == .granted
    }
}
