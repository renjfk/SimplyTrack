//
//  AtlasBrowser.swift
//  SimplyTrack
//

import Foundation

/// ChatGPT Atlas-specific implementation of browser interface.
/// Handles URL detection and incognito mode detection for ChatGPT Atlas.
/// Atlas is Chromium-based and shares the same AppleScript interface as Chrome.
class AtlasBrowser: BaseBrowser {

    init() {
        super.init(bundleId: "com.openai.atlas", displayName: "ChatGPT Atlas")
    }

    /// ChatGPT Atlas-specific AppleScript for URL retrieval
    override var currentURLScript: String {
        return """
                tell application "ChatGPT Atlas"
                    if (count of windows) > 0 then
                        set currentTab to active tab of window 1
                        return URL of currentTab
                    end if
                end tell
            """
    }

    /// Checks if ChatGPT Atlas is currently in incognito mode.
    /// Uses the 'mode' property available in Atlas's Chromium AppleScript interface.
    /// Note: Permissions are already verified by getCurrentURL() call, so no need to re-check.
    /// - Returns: true if incognito mode is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
                tell application "ChatGPT Atlas"
                    if (count of windows) > 0 then
                        return mode of window 1 is equal to "incognito"
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
