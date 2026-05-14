//
//  VivaldiBrowser.swift
//  SimplyTrack
//

import Foundation

/// Vivaldi-specific implementation of browser interface.
/// Handles URL detection and private mode detection for Vivaldi browser.
/// Vivaldi is Chromium-based and exposes a compatible AppleScript interface.
class VivaldiBrowser: BaseBrowser {

    init() {
        super.init(bundleId: "com.vivaldi.Vivaldi", displayName: "Vivaldi")
    }

    /// Vivaldi-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
                tell application id "com.vivaldi.Vivaldi"
                    if (count of windows) > 0 then
                        set currentTab to active tab of window 1
                        return URL of currentTab
                    end if
                end tell
            """
    }

    /// Checks if Vivaldi is currently in private mode.
    /// Uses the 'mode' property available in Chromium-based browser AppleScript interfaces.
    /// Note: Permissions are already verified by getCurrentURL() call, so no need to re-check.
    /// - Returns: true if private mode is detected, false if regular browsing is detected, nil if detection failed
    override func isInPrivateBrowsingMode() -> Bool? {
        let script = """
                tell application id "com.vivaldi.Vivaldi"
                    if (count of windows) > 0 then
                        return mode of window 1 is equal to "incognito"
                    end if
                end tell
            """

        let scriptResult = executeAppleScript(script)

        guard let result = scriptResult.result,
            let isPrivate = Bool(result.lowercased())
        else {
            return nil
        }

        return isPrivate
    }
}
