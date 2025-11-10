//
//  ArcBrowser.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 10.11.2025.
//

import Foundation

/// Arc-specific implementation of browser interface.
/// Handles URL detection and incognito mode detection for Arc browser.
class ArcBrowser: BaseBrowser {

    init() {
        super.init(bundleId: "company.thebrowser.Browser", displayName: "Arc")
    }

    /// Arc-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
                tell application "Arc"
                    if (count of windows) > 0 then
                        tell front window
                            return URL of active tab
                        end tell
                    end if
                end tell
            """
    }

    /// Checks if Arc is currently in incognito mode.
    /// Uses the 'incognito' property available in Arc's AppleScript interface.
    /// Note: Permissions are already verified by getCurrentURL() call, so no need to re-check.
    /// - Returns: true if incognito mode is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
                tell application "Arc"
                    if (count of windows) > 0 then
                        tell front window
                            return incognito
                        end tell
                    end if
                end tell
            """

        let scriptResult = executeAppleScript(script)

        guard let result = scriptResult.result,
            let isIncognito = Bool(result.lowercased())
        else {
            return false
        }

        return isIncognito
    }
}
