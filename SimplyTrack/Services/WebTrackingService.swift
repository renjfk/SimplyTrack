//
//  WebTrackingService.swift
//  SimplyTrack
//
//  Handles browser integration, AppleScript execution, favicon fetching, and website detection
//  Supports Safari, Chrome, and Edge through AppleScript communication for website tracking
//

import AppKit
import ApplicationServices
import Foundation
import SwiftUI

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

    private let browsers: [String: BrowserInterface] = [
        SafariBrowser(),
        ChromeBrowser(),
        EdgeBrowser(),
    ].reduce(into: [:]) { result, browser in
        result[browser.bundleId] = browser
    }

    private let faviconCacheActor = FaviconCacheActor()

    // Privacy settings
    @AppStorage("trackPrivateBrowsing", store: .app) private var trackPrivateBrowsing = AppStorageDefaults.trackPrivateBrowsing

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
    /// Respects privacy settings by filtering out private/incognito tabs when tracking is disabled.
    /// - Returns: Tuple containing URL and browser bundle ID, nil if unsupported browser or no URL
    func getCurrentWebsiteWithBrowser() -> (url: String, browserBundleId: String)? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
            let bundleId = frontmostApp.bundleIdentifier,
            let browser = browsers[bundleId]
        else {
            return nil
        }

        // Check if private browsing is active and tracking is disabled
        if !trackPrivateBrowsing && browser.isInPrivateBrowsingMode() {
            return nil
        }

        guard let url = browser.getCurrentURL() else { return nil }
        return (url: url, browserBundleId: bundleId)
    }

    // MARK: - Browser Management

    /// Gets a browser instance for the given bundle identifier.
    /// - Parameter bundleId: The bundle identifier of the browser
    /// - Returns: BrowserInterface instance if supported, nil otherwise
    func getBrowser(for bundleId: String) -> BrowserInterface? {
        return browsers[bundleId]
    }

    // MARK: - URL Processing

    private func extractDomain(from urlString: String) -> String {
        // Only track HTTP and HTTPS URLs
        guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
            return ""  // Return empty string to filter out non-web URLs
        }

        guard let url = URL(string: urlString),
            let host = url.host
        else {
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
            "https://www.\(domain)/favicon.png",
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
                #"<link[^>]*href=["\']([^"\']+)["\'][^>]*rel=["\'](?:shortcut )?icon["\']"#,
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
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

}
