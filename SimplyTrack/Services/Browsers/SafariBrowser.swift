//
//  SafariBrowser.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import ApplicationServices
import Foundation
import os.log

/// Safari-specific implementation of browser interface.
/// Handles URL detection and private browsing detection for Safari.
class SafariBrowser: BaseBrowser {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SafariBrowser")

    init() {
        super.init(bundleId: "com.apple.Safari", displayName: "Safari")
    }

    /// Safari-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
                tell application "Safari"
                    if (count of windows) > 0 then
                        set currentTab to current tab of window 1
                        return URL of currentTab
                    end if
                end tell
            """
    }

    /// Checks if Safari is currently in private browsing mode.
    /// Uses System Events to check for private window menu item.
    /// - Returns: true if private browsing is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let systemEventsScript = """
            tell application "System Events"
              tell process "Safari"
                  set theMenuBar to menu bar 1
                  set theWindowMenu to menu "Window" of theMenuBar
                  return (menu item "Move Tab to New Private Window" of theWindowMenu) exists
              end tell
            end tell
            """

        let scriptResult = executeAppleScript(systemEventsScript)

        // Handle System Events permission result
        if let error = scriptResult.error {
            // Handle permission-related errors
            if scriptResult.errorCode == -1719 {
                // Accessibility permission denied
                PermissionManager.shared.handleAccessibilityPermissionResult(success: false)
            } else if scriptResult.errorCode == -1743 || scriptResult.errorCode == -1744 {
                // System Events permission errors
                PermissionManager.shared.handleSystemEventsPermissionResult(success: false)
            } else {
                // Log non-permission System Events errors
                logger.error("Safari System Events AppleScript error: \(error.description)")
            }
            return false
        }

        // If we successfully executed System Events AppleScript, permissions are working
        if scriptResult.result != nil {
            PermissionManager.shared.handleSystemEventsPermissionResult(success: true)
            PermissionManager.shared.handleAccessibilityPermissionResult(success: true)
        }

        if let resultString = scriptResult.result, let isPrivate = Bool(resultString.lowercased()) {
            return isPrivate
        }

        return false
    }
}
