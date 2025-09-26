//
//  SimplyTrackIPCProtocol.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation

/// Protocol for IPC communication between MCP server and main SimplyTrack app
///
/// This protocol defines the client-side interface for the SimplyTrackMCP binary
/// to communicate with the main SimplyTrack application via NSXPCConnection.
///
/// ## MCP Server Usage
/// This is the client-side copy of the protocol used by SimplyTrackMCP to connect
/// to the main app's IPC service. The MCP server uses this interface to:
/// 1. Check if the main app is running (via getVersion)
/// 2. Retrieve usage data for AI tool requests (via getUsageActivity)
///
/// ## Connection Setup
/// ```swift
/// let connection = NSXPCConnection(machServiceName: "com.renjfk.SimplyTrack")
/// connection.remoteObjectInterface = NSXPCInterface(with: SimplyTrackIPCProtocol.self)
/// connection.resume()
/// let ipcService = connection.remoteObjectProxy as! SimplyTrackIPCProtocol
/// ```
///
/// ## Error Handling
/// If the main SimplyTrack app is not running:
/// - Connection attempts will fail
/// - Method calls will timeout or throw NSXPCConnection errors
/// - The MCP server should gracefully handle these cases
///
/// ## Security
/// - Communication occurs over mach services with same-user restriction
/// - No sensitive data should be passed through this interface
/// - The main app validates all requests before processing
@objc protocol SimplyTrackIPCProtocol {

    /// Retrieves aggregated usage activity data from the main SimplyTrack app
    ///
    /// This method requests usage statistics from the main application's data store.
    /// Used by MCP tools to provide usage insights to AI assistants.
    ///
    /// - Parameters:
    ///   - topPercentage: Percentage of top activities to include (0.0-1.0)
    ///   - dateString: Target date in "yyyy-MM-dd" format, or nil for today
    ///   - typeFilter: Activity type filter - "app" or "website"
    ///   - completion: Async completion with formatted usage string or error
    ///
    /// ## Response Format
    /// Returns a pipe-separated string: `name:duration|name:duration|...|Total:duration`
    ///
    /// **Duration Format Examples:**
    /// - `3h45m` = 3 hours 45 minutes
    /// - `2h0m` = exactly 2 hours
    /// - `45m` = 45 minutes only
    /// - `Total:7h23m` = total tracked time
    ///
    /// **Example Response:** `"Xcode:3h45m|Safari:2h18m|Terminal:1h20m|Total:7h23m"`
    ///
    /// ## MCP Tool Integration
    /// This method directly supports the "get_usage_activity" MCP tool,
    /// allowing AI assistants to analyze user productivity patterns.
    func getUsageActivity(topPercentage: Double, dateString: String?, typeFilter: String, completion: @escaping (String?, Error?) -> Void)

    /// Gets the current version of the main SimplyTrack application
    ///
    /// Used both for version reporting and as a connectivity check.
    /// If this method succeeds, the main app is running and accessible.
    ///
    /// - Parameter completion: Called with version string (never fails if connected)
    func getVersion(completion: @escaping (String) -> Void)
}
