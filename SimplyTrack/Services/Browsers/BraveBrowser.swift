//
//  BraveBrowser.swift
//  SimplyTrack
//

import Foundation

/// Brave-specific implementation of browser interface.
/// Handles URL detection and incognito mode detection for Brave browser.
/// Brave is Chromium-based and shares the same AppleScript interface as Chrome.
class BraveBrowser: BaseBrowser {

    init() {
        super.init(bundleId: "com.brave.Browser", displayName: "Brave")
    }

    /// Brave-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
                tell application "Brave Browser"
                    if (count of windows) > 0 then
                        set currentTab to active tab of window 1
                        return URL of currentTab
                    end if
                end tell
            """
    }

    /// Checks if Brave is currently in incognito mode.
    /// Uses the 'mode' property available in Brave's AppleScript interface (same as Chrome).
    /// Note: Permissions are already verified by getCurrentURL() call, so no need to re-check.
    /// - Returns: true if incognito mode is detected, false if regular browsing is detected, nil if detection failed
    override func isInPrivateBrowsingMode() -> Bool? {
        let script = """
                tell application "Brave Browser"
                    if (count of windows) > 0 then
                        return mode of window 1 is equal to "incognito"
                    end if
                end tell
            """

        let scriptResult = executeAppleScript(script)

        guard let result = scriptResult.result,
            let isIncognito = Bool(result.lowercased())
        else {
            return nil
        }

        return isIncognito
    }
}
