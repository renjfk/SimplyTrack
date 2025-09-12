//
//  BrowserInterface.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import Foundation
import os.log

/// Result of AppleScript execution including error information
struct AppleScriptResult {
    let result: String?
    let errorCode: Int?
    let error: NSDictionary?
}

/// Protocol defining the interface for browser-specific URL detection and private browsing detection.
/// Provides a consistent API for interacting with different browsers through AppleScript.
protocol BrowserInterface {
    /// The bundle identifier for this browser
    var bundleId: String { get }
    
    /// The display name for this browser
    var displayName: String { get }
    
    /// Gets the current active URL from the browser.
    /// - Returns: The current URL as a string, or nil if no URL is available or browser is not active
    func getCurrentURL() -> String?
    
    /// Checks if the current active tab/window is in private browsing mode.
    /// - Returns: true if private browsing is detected, false otherwise
    func isInPrivateBrowsingMode() -> Bool
}

/// Base implementation providing common AppleScript execution functionality.
/// Browser-specific classes can inherit from this to get shared AppleScript execution logic.
class BaseBrowser: BrowserInterface {
    let bundleId: String
    let displayName: String
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BrowserInterface")
    
    /// Abstract property that subclasses must provide with their specific URL retrieval AppleScript
    var currentURLScript: String {
        fatalError("Subclasses must implement currentURLScript")
    }
    
    init(bundleId: String, displayName: String) {
        self.bundleId = bundleId
        self.displayName = displayName
    }
    
    /// Centralized implementation that handles all browser permission errors
    func getCurrentURL() -> String? {
        let scriptResult = executeAppleScript(currentURLScript)
        
        // Handle browser permission result
        if let error = scriptResult.error {
            // Handle permission-related errors
            if scriptResult.errorCode == -1743 || scriptResult.errorCode == -1744 {
                PermissionManager.shared.handleBrowserPermissionResult(success: false)
            } else {
                // Log non-permission AppleScript errors using Logger
                logger.error("Browser (\(self.displayName)) AppleScript error: \(error.description)")
                
                // Send error to UI
                PermissionManager.shared.handleBrowserError("Browser communication error: \(error.description)")
            }
            return nil
        }
        
        // If we successfully executed AppleScript, permissions are working
        if scriptResult.result != nil {
            PermissionManager.shared.handleBrowserPermissionResult(success: true)
        }
        
        return scriptResult.result
    }
    
    /// Default implementation - subclasses should override
    func isInPrivateBrowsingMode() -> Bool {
        fatalError("Subclasses must implement isInPrivateBrowsingMode()")
    }
    
    /// Internal method for executing AppleScript and returning detailed result information.
    /// Only available to subclasses within the same module.
    /// - Parameter script: The AppleScript code to execute
    /// - Returns: AppleScriptResult containing the result, error code, and error details
    internal func executeAppleScript(_ script: String) -> AppleScriptResult {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        let errorCode = error?["NSAppleScriptErrorNumber"] as? Int
        
        return AppleScriptResult(
            result: result?.stringValue,
            errorCode: errorCode,
            error: error
        )
    }
}
