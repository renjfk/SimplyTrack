//
//  EdgeBrowser.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import Foundation

/// Edge-specific implementation of browser interface.
/// Handles URL detection and InPrivate mode detection for Microsoft Edge.
class EdgeBrowser: BaseBrowser {
    
    init() {
        super.init(bundleId: "com.microsoft.edgemac", displayName: "Edge")
    }
    
    /// Gets the current active URL from Edge.
    /// - Returns: The current URL from the active tab, or nil if not available
    override func getCurrentURL() -> String? {
        let script = """
            tell application "Microsoft Edge"
                if (count of windows) > 0 then
                    set currentTab to active tab of window 1
                    return URL of currentTab
                end if
            end tell
        """
        return executeAppleScript(script)
    }
    
    /// Checks if Edge is currently in InPrivate mode.
    /// Uses the 'mode' property similar to Chrome, since Edge is Chromium-based.
    /// - Returns: true if InPrivate mode is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
            tell application "Microsoft Edge"
                if (count of windows) > 0 then
                    return mode of window 1 is equal to "incognito"
                end if
            end tell
        """
        
        guard let result = executeAppleScript(script),
              let isInPrivate = Bool(result.lowercased()) else {
            return false
        }
        
        return isInPrivate
    }
}