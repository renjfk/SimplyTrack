//
//  SafariBrowser.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import Foundation
import os.log
import ApplicationServices

/// Safari-specific implementation of browser interface.
/// Handles URL detection and private browsing detection for Safari.
class SafariBrowser: BaseBrowser {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SafariBrowser")
    
    init() {
        super.init(bundleId: "com.apple.Safari", displayName: "Safari")
    }
    
    /// Gets the current active URL from Safari.
    /// - Returns: The current URL from the active tab, or nil if not available
    override func getCurrentURL() -> String? {
        let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set currentTab to current tab of window 1
                    return URL of currentTab
                end if
            end tell
        """
        
        let result = executeAppleScript(script)
        return result
    }
    
    /// Checks if Safari is currently in private browsing mode.
    /// Uses System Events to check for private window menu item.
    /// - Returns: true if private browsing is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        // Check if we have both System Events and Accessibility permissions
        let hasSystemEventsPermission = PermissionManager.shared.checkSystemEventsPermissions() == .granted
        let hasAccessibilityPermission = PermissionManager.shared.checkAccessibilityPermissions() == .granted
        
        if !hasSystemEventsPermission || !hasAccessibilityPermission {
            return false
        }
        
        let systemEventsScript = """
tell application "System Events"
  tell process "Safari"
      try
          set theMenuBar to menu bar 1
          set theWindowMenu to menu "Window" of theMenuBar
          return (menu item "Move Tab to New Private Window" of theWindowMenu) exists
      on error errorMessage number errorNumber
          return false
      end try
  end tell
end tell
"""
        
        let result = executeAppleScript(systemEventsScript)
        
        if let resultString = result, let isPrivate = Bool(resultString.lowercased()) {
            return isPrivate
        }
        
        return false
    }
}
