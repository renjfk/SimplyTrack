//
//  WebTrackingService.swift
//  SimplyTrack
//
//  Handles browser integration, AppleScript execution, favicon fetching, and website detection
//  Supports Safari, Chrome, and Edge through AppleScript communication for website tracking
//

import Foundation
import AppKit
import ApplicationServices
import os.log

actor FaviconCacheActor {
    private var cache: [String: Data] = [:]
    
    /// Retrieves cached favicon data for a domain.
    /// - Parameter key: Domain name used as cache key
    /// - Returns: Cached favicon data if available, nil otherwise
    func get(_ key: String) -> Data? {
        return cache[key]
    }
    
    /// Stores favicon data in the cache for a domain.
    /// - Parameters:
    ///   - key: Domain name to use as cache key
    ///   - value: Favicon data to cache
    func set(_ key: String, _ value: Data) {
        cache[key] = value
    }
}

class WebTrackingService {
    private let supportedBrowsers = [
        "com.apple.Safari": "Safari",
        "com.google.Chrome": "Chrome", 
        "com.microsoft.edgemac": "Edge"
    ]
    
    private let faviconCacheActor = FaviconCacheActor()
    
    init() {}
    
    // MARK: - Public Interface
    
    /// Gets the current website URL from the frontmost supported browser.
    /// - Returns: Current website URL if a supported browser is active, nil otherwise
    func getCurrentWebsite() -> String? {
        return getCurrentWebsiteWithBrowser()?.url
    }
    
    /// Gets the current website domain and favicon data from the frontmost supported browser.
    /// Downloads and caches favicon if not already available.
    /// - Returns: Tuple containing domain and favicon data, nil if no website detected
    func getCurrentWebsiteData() async -> (domain: String, iconData: Data?)? {
        guard let websiteInfo = getCurrentWebsiteWithBrowser() else {
            return nil
        }
        
        let domain = extractDomain(from: websiteInfo.url)
        guard !domain.isEmpty else { return nil }
        
        let iconData = await getFaviconData(for: domain, sourceURL: websiteInfo.url)
        return (domain: domain, iconData: iconData)
    }
    
    /// Gets the current website URL along with the browser bundle identifier.
    /// Only works with frontmost applications that are supported browsers.
    /// - Returns: Tuple containing URL and browser bundle ID, nil if unsupported browser or no URL
    func getCurrentWebsiteWithBrowser() -> (url: String, browserBundleId: String)? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier,
              supportedBrowsers.keys.contains(bundleId) else {
            return nil
        }
        
        let url: String?
        switch bundleId {
        case "com.apple.Safari":
            url = getSafariURL()
        case "com.google.Chrome":
            url = getChromeURL()
        case "com.microsoft.edgemac":
            url = getEdgeURL()
        default:
            url = nil
        }
        
        guard let validUrl = url else { return nil }
        return (url: validUrl, browserBundleId: bundleId)
    }
    
    // MARK: - Browser-Specific URL Detection
    
    private func getSafariURL() -> String? {
        let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set currentTab to current tab of window 1
                    return URL of currentTab
                end if
            end tell
        """
        return executeAppleScript(script)
    }
    
    private func getChromeURL() -> String? {
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
    
    private func getEdgeURL() -> String? {
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
    
    // MARK: - AppleScript Execution
    
    private func executeAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int
            
            // Handle permission-related errors
            if errorCode == -1743 || errorCode == -1744 {
                PermissionManager.shared.handleBrowserPermissionResult(success: false)
            } else {
                // Log non-permission AppleScript errors using os_log
                os_log(.error, log: .default, "BrowserDetector AppleScript error: %@", error.description)
                
                // Send error to UI
                PermissionManager.shared.handleBrowserError("Browser communication error: \(error.description)")
            }
            return nil
        }
        
        // If we successfully executed AppleScript, permissions are working
        if result != nil {
            PermissionManager.shared.handleBrowserPermissionResult(success: true)
        }
        
        return result?.stringValue
    }
    
    // MARK: - Accessibility API Fallback
    
    private func getURLViaAccessibility(bundleId: String) -> String? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
              let pid = app.processIdentifier as pid_t? else {
            return nil
        }
        
        let appRef = AXUIElementCreateApplication(pid)
        var windows: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windows)
        guard result == .success,
              let windowsArray = windows as? [AXUIElement],
              !windowsArray.isEmpty else {
            return nil
        }
        
        // Try to get URL from the first window's address bar
        let window = windowsArray[0]
        var focused: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXFocusedUIElementAttribute as CFString, &focused)
        
        // This is a simplified approach - a full implementation would need more complex UI traversal
        return nil
    }
    
    // MARK: - URL Processing
    
    private func extractDomain(from urlString: String) -> String {
        // Only track HTTP and HTTPS URLs
        guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
            return "" // Return empty string to filter out non-web URLs
        }
        
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        // Remove www. prefix if present
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        
        return host
    }
    
    // MARK: - Website Icon Fetching
    
    private func getFaviconData(for domain: String, sourceURL: String) async -> Data? {
        // Thread-safe cache read
        if let cachedData = await faviconCacheActor.get(domain) {
            return cachedData
        }
        
        // First try to get favicon from the actual page URL
        if let faviconURL = await extractFaviconFromPage(sourceURL) {
            if let data = await fetchFaviconFromURL(faviconURL) {
                // Thread-safe cache write
                await faviconCacheActor.set(domain, data)
                return data
            }
        }
        
        // Fall back to domain-level favicons (prefer HTTPS due to ATS)
        let faviconURLs = [
            "https://\(domain)/favicon.ico",
            "https://www.\(domain)/favicon.ico", 
            "https://\(domain)/favicon.png",
            "https://www.\(domain)/favicon.png"
        ]
        
        for urlString in faviconURLs {
            if let data = await fetchFaviconFromURL(urlString) {
                // Thread-safe cache write
                await faviconCacheActor.set(domain, data)
                return data
            }
        }
        
        return nil
    }
    
    private func extractFaviconFromPage(_ pageURL: String) async -> String? {
        guard let url = URL(string: pageURL) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? ""
            
            // Look for <link rel="icon"> or <link rel="shortcut icon">
            let patterns = [
                #"<link[^>]*rel=["\'](?:shortcut )?icon["\'][^>]*href=["\']([^"\']+)["\']"#,
                #"<link[^>]*href=["\']([^"\']+)["\'][^>]*rel=["\'](?:shortcut )?icon["\']"#
            ]
            
            for pattern in patterns {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: html.count)
                
                if let match = regex.firstMatch(in: html, options: [], range: range) {
                    let hrefRange = match.range(at: 1)
                    if let swiftRange = Range(hrefRange, in: html) {
                        let href = String(html[swiftRange])
                        
                        // Convert relative URL to absolute
                        if href.hasPrefix("http") {
                            return href
                        } else if href.hasPrefix("//") {
                            let scheme = pageURL.hasPrefix("https://") ? "https:" : "http:"
                            return scheme + href
                        } else if href.hasPrefix("/") {
                            if let baseURL = URL(string: pageURL) {
                                return "\(baseURL.scheme!)://\(baseURL.host!)\(href)"
                            }
                        } else {
                            // Relative path
                            if let baseURL = URL(string: pageURL) {
                                let basePath = baseURL.deletingLastPathComponent().absoluteString
                                return basePath + href
                            }
                        }
                    }
                }
            }
        } catch {
            // Failed to fetch page, continue to domain fallback
        }
        
        return nil
    }
    
    private func fetchFaviconFromURL(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let originalImage = NSImage(data: data) else { return nil }
            
            // Convert favicon to 32x32 PNG format
            return await convertFaviconToPNG(originalImage)
        } catch {
            // Continue to next URL
        }
        
        return nil
    }
    
    private func convertFaviconToPNG(_ image: NSImage) async -> Data? {
        // Create a new image with 32x32 size using modern API
        let targetSize = NSSize(width: 32, height: 32)
        let resizedImage = NSImage(size: targetSize, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        
        // Convert to PNG
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .png, properties: [:])
    }
}
