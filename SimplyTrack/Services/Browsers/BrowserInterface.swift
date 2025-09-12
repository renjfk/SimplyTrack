//
//  BrowserInterface.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import Foundation
import os.log

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
    
    /// Executes an AppleScript command for this browser.
    /// - Parameter script: The AppleScript code to execute
    /// - Returns: The result of the script execution, or nil if execution failed
    func executeAppleScript(_ script: String) -> String?
}

/// Base implementation providing common AppleScript execution functionality.
/// Browser-specific classes can inherit from this to get shared AppleScript execution logic.
class BaseBrowser: BrowserInterface {
    let bundleId: String
    let displayName: String
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "BrowserInterface")
    
    init(bundleId: String, displayName: String) {
        self.bundleId = bundleId
        self.displayName = displayName
    }
    
    /// Default implementation - subclasses should override
    func getCurrentURL() -> String? {
        fatalError("Subclasses must implement getCurrentURL()")
    }
    
    /// Default implementation - subclasses should override
    func isInPrivateBrowsingMode() -> Bool {
        fatalError("Subclasses must implement isInPrivateBrowsingMode()")
    }
    
    /// Shared AppleScript execution logic with error handling and permission management.
    /// - Parameter script: The AppleScript code to execute
    /// - Returns: The result string, or nil if execution failed
    func executeAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int
            
            // Handle permission-related errors
            if errorCode == -1743 || errorCode == -1744 {
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
        if result != nil {
            PermissionManager.shared.handleBrowserPermissionResult(success: true)
        }
        
        return result?.stringValue
    }
}