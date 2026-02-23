//
//  WindowDetectionService.swift
//  SimplyTrack
//
//  Detects floating/overlay windows that are on top but not the frontmost app
//

import AppKit
import CoreGraphics
import Foundation

/// Represents a detected active window with its owning application info.
struct DetectedWindow {
    /// Bundle identifier of the owning application
    let bundleIdentifier: String
    /// Display name of the owning application
    let name: String
    /// The running application instance
    let app: NSRunningApplication
    /// The CGWindow layer level of the window
    let windowLevel: Int
}

/// Service responsible for detecting floating and overlay windows that are visually on top
/// of other windows but whose owning app is not the macOS "frontmost" application.
/// This handles cases like Ghostty quick terminal, Spotlight, 1Password Quick Access, etc.
@MainActor
class WindowDetectionService {

    /// Normal window level (kCGNormalWindowLevel = 0)
    private static let normalWindowLevel = Int(CGWindowLevelForKey(.normalWindow))

    /// Minimum window level to consider as a floating/overlay window.
    /// Windows at kCGFloatingWindowLevel (3) and above are considered floating.
    private static let floatingWindowLevel = Int(CGWindowLevelForKey(.floatingWindow))

    /// Window levels at or above this threshold are system-level UI (menu bar, dock, screensaver)
    /// and should be ignored since they aren't user-interactive application windows.
    private static let systemWindowLevelThreshold = Int(CGWindowLevelForKey(.mainMenuWindow))

    /// Minimum window dimensions (in points) to consider a window as actively used.
    /// Filters out tiny helper windows, status items, and invisible accessory windows.
    private static let minimumWindowDimension: CGFloat = 50.0

    /// Cache of PID to NSRunningApplication mappings to avoid repeated lookups.
    private var appCache: [pid_t: NSRunningApplication] = [:]

    /// Timestamp of last cache refresh
    private var lastCacheRefresh = Date.distantPast

    /// How often to refresh the app cache (seconds)
    private static let cacheRefreshInterval: TimeInterval = 5.0

    // MARK: - Public Interface

    /// Detects whether a floating/overlay window is the topmost user-interactive window on screen.
    /// Returns the detected floating window's app info if one is found above the frontmost app,
    /// or nil if the frontmost application's window is truly on top.
    ///
    /// - Parameter frontmostBundleId: The bundle identifier of the current frontmost application
    /// - Returns: A `DetectedWindow` if a floating overlay is on top, nil otherwise
    func detectTopmostFloatingWindow(frontmostBundleId: String) -> DetectedWindow? {
        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[CFString: Any]]
        else {
            return nil
        }

        refreshAppCacheIfNeeded()

        // The window list is ordered front-to-back, so the first entry is the topmost window.
        // We iterate to find the first meaningful user-interactive window.
        for windowInfo in windowList {
            guard let window = parseWindow(windowInfo) else {
                continue
            }

            // Skip system-level windows (menu bar, dock, screensaver, etc.)
            if window.level >= Self.systemWindowLevelThreshold {
                continue
            }

            // Skip windows that are too small to be meaningful
            if window.width < Self.minimumWindowDimension || window.height < Self.minimumWindowDimension {
                continue
            }

            // Skip SimplyTrack's own windows
            if window.bundleIdentifier == Bundle.main.bundleIdentifier {
                continue
            }

            // We found the topmost meaningful window.
            // If it belongs to the frontmost app, no override needed.
            if window.bundleIdentifier == frontmostBundleId {
                return nil
            }

            // If the window is at a floating level or above, it's an overlay window
            // from a non-frontmost app — this is what we want to detect.
            if window.level >= Self.floatingWindowLevel {
                guard let app = runningApplication(for: window.pid) else {
                    continue
                }

                let name = app.localizedName ?? window.ownerName ?? "Unknown"

                return DetectedWindow(
                    bundleIdentifier: window.bundleIdentifier ?? "unknown.\(window.ownerName ?? "app")",
                    name: name,
                    app: app,
                    windowLevel: window.level
                )
            }

            // If the topmost window is a normal-level window from a different app,
            // this can happen briefly during app switches — don't override.
            return nil
        }

        return nil
    }

    // MARK: - Private Implementation

    /// Parsed representation of a CGWindow entry
    private struct ParsedWindow {
        let pid: pid_t
        let bundleIdentifier: String?
        let ownerName: String?
        let level: Int
        let width: CGFloat
        let height: CGFloat
    }

    /// Parses a CGWindowListCopyWindowInfo dictionary entry into a structured form.
    private func parseWindow(_ info: [CFString: Any]) -> ParsedWindow? {
        // Owner PID is required
        guard let pid = info[kCGWindowOwnerPID] as? pid_t else {
            return nil
        }

        // Window level
        let level = info[kCGWindowLayer] as? Int ?? 0

        // Window bounds
        var width: CGFloat = 0
        var height: CGFloat = 0
        if let bounds = info[kCGWindowBounds] as? [String: CGFloat] {
            width = bounds["Width"] ?? 0
            height = bounds["Height"] ?? 0
        }

        // Owner name from window info
        let ownerName = info[kCGWindowOwnerName] as? String

        // Try to get bundle identifier from cached running application
        let bundleId = runningApplication(for: pid)?.bundleIdentifier

        return ParsedWindow(
            pid: pid,
            bundleIdentifier: bundleId,
            ownerName: ownerName,
            level: level,
            width: width,
            height: height
        )
    }

    /// Returns the NSRunningApplication for a given PID, using a cache to minimize lookups.
    private func runningApplication(for pid: pid_t) -> NSRunningApplication? {
        if let cached = appCache[pid] {
            // Check the cached app is still running
            if !cached.isTerminated {
                return cached
            }
            appCache.removeValue(forKey: pid)
        }

        // Look up and cache
        let app = NSRunningApplication(processIdentifier: pid)
        if let app = app, !app.isTerminated {
            appCache[pid] = app
            return app
        }

        return nil
    }

    /// Refreshes the app cache periodically to evict terminated processes.
    private func refreshAppCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCacheRefresh) >= Self.cacheRefreshInterval else { return }
        lastCacheRefresh = now
        appCache = appCache.filter { !$0.value.isTerminated }
    }
}
