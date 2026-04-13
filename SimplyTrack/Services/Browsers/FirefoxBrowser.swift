//
//  FirefoxBrowser.swift
//  SimplyTrack
//

import Foundation
import os.log

/// Firefox-specific implementation of browser interface.
/// Unlike Chromium-based browsers, Firefox does not expose tabs or URLs through its AppleScript dictionary.
/// Instead, this implementation uses the macOS Accessibility API (via System Events) to read the URL
/// from Firefox's address bar. Requires `accessibility.force_disabled` set to `-1` in Firefox's `about:config`.
class FirefoxBrowser: BaseBrowser {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FirefoxBrowser")

    /// Private browsing suffix appended to Firefox window titles
    private static let privateBrowsingSuffix = "\u{2014} Private Browsing"

    init() {
        super.init(bundleId: "org.mozilla.firefox", displayName: "Firefox")
    }

    /// Not used - Firefox overrides getCurrentURL() directly since it uses System Events instead of
    /// direct browser AppleScript.
    override var currentURLScript: String {
        return ""
    }

    /// Gets the current URL from Firefox using the macOS Accessibility API.
    /// Reads the address bar value via System Events and prepends `https://` since Firefox
    /// displays URLs without the scheme.
    /// - Returns: The current URL as a string, or nil if unavailable
    override func getCurrentURL() -> String? {
        let script = """
                tell application "System Events" to tell process "Firefox"
                    get value of combo box 1 of group 1 of toolbar 2 of group 1 of window 1
                end tell
            """

        let scriptResult = executeAppleScript(script)

        if let error = scriptResult.error {
            if scriptResult.errorCode == -1719 || scriptResult.errorCode == -1728 {
                // Accessibility tree not available - Firefox requires about:config change
                logger.warning("Firefox accessibility tree not available. User needs to set accessibility.force_disabled to -1 in about:config.")
                PermissionManager.shared.handleBrowserError(
                    "Firefox requires additional setup for website tracking: open about:config in Firefox and set accessibility.force_disabled to -1."
                )
            } else if scriptResult.errorCode == -1743 || scriptResult.errorCode == -1744 {
                PermissionManager.shared.handleSystemEventsPermissionResult(success: false)
            } else {
                logger.error("Firefox Accessibility AppleScript error: \(error.description)")
                PermissionManager.shared.handleBrowserError("Firefox communication error: \(error.description)")
            }
            return nil
        }

        if scriptResult.result != nil {
            PermissionManager.shared.handleSystemEventsPermissionResult(success: true)
            PermissionManager.shared.handleAccessibilityPermissionResult(success: true)
        }

        guard let urlValue = scriptResult.result, !urlValue.isEmpty else {
            return nil
        }

        // Filter out Firefox internal pages (about:config, about:preferences, etc.)
        if urlValue.hasPrefix("about:") {
            return nil
        }

        // Firefox displays URLs without the scheme in the address bar
        if urlValue.hasPrefix("http://") || urlValue.hasPrefix("https://") {
            return urlValue
        }
        return "https://\(urlValue)"
    }

    /// Checks if Firefox is currently in private browsing mode.
    /// Firefox appends a localized private browsing indicator to the window title.
    /// - Returns: true if private browsing is detected, false otherwise
    override func isInPrivateBrowsingMode() -> Bool {
        let script = """
                tell application "Firefox" to return name of front window
            """

        let scriptResult = executeAppleScript(script)

        guard let windowName = scriptResult.result else {
            return false
        }

        return windowName.hasSuffix(Self.privateBrowsingSuffix)
    }
}
