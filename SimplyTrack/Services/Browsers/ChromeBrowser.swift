//
//  ChromeBrowser.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import Foundation

/// Chrome-specific implementation of browser interface.
/// Handles URL detection and incognito mode detection for Google Chrome.
class ChromeBrowser: BaseBrowser {
    
    init() {
        super.init(bundleId: "com.google.Chrome", displayName: "Chrome")
    }
    
    /// Gets the current active URL from Chrome.
    /// - Returns: The current URL from the active tab, or nil if not available
    override func getCurrentURL() -> String? {
        let script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set currentTab to active tab of window 1
                    return URL of currentTab
                end if
            end tell
        """
        return executeAppleScript(script)
    }
    
    /// Checks if Chrome is currently in incognito mode.
    /// Uses the reliable 'mode' property available in Chrome's AppleScript interface.
    /// - Returns: true if incognito mode is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    return mode of window 1 is equal to "incognito"
                end if
            end tell
        """
        
        guard let result = executeAppleScript(script),
              let isIncognito = Bool(result.lowercased()) else {
            return false
        }
        
        return isIncognito
    }
}