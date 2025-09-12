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
    
    /// Chrome-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set currentTab to active tab of window 1
                    return URL of currentTab
                end if
            end tell
        """
    }
    
    /// Checks if Chrome is currently in incognito mode.
    /// Uses the reliable 'mode' property available in Chrome's AppleScript interface.
    /// Note: Permissions are already verified by getCurrentURL() call, so no need to re-check.
    /// - Returns: true if incognito mode is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    return mode of window 1 is equal to "incognito"
                end if
            end tell
        """
        
        let scriptResult = executeAppleScript(script)
        
        guard let result = scriptResult.result,
              let isIncognito = Bool(result.lowercased()) else {
            return false
        }
        
        return isIncognito
    }
}