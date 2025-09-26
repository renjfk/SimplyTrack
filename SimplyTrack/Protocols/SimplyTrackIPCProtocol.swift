//
//  SimplyTrackIPCProtocol.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation

/// Protocol for IPC communication between MCP server and main SimplyTrack app
///
/// This protocol defines the interface for inter-process communication using NSXPCConnection.
/// The main app implements this protocol via IPCService, and the MCP server connects to it
/// as a client to request data and functionality from the main application.
///
/// ## Architecture
/// - **Main App**: Exports this protocol via NSXPCListener on mach service "com.renjfk.SimplyTrack"
/// - **MCP Server**: Connects as client via NSXPCConnection to consume these services
/// - **Security**: Communication is limited to same-user processes with matching bundle identifier
///
/// ## Thread Safety
/// All methods use completion handlers and are safe to call from any thread.
/// The main app's IPCService ensures proper threading when interacting with SwiftData.
@objc protocol SimplyTrackIPCProtocol {

    /// Retrieves aggregated usage activity data for a specific date and type
    ///
    /// This method fetches usage statistics from the main app's SwiftData store,
    /// aggregates the data according to the specified parameters, and returns
    /// a formatted string suitable for AI tool consumption.
    ///
    /// - Parameters:
    ///   - topPercentage: Percentage of top activities to include (0.0-1.0).
    ///                   For example, 0.8 includes the top 80% most-used activities.
    ///                   Default: 0.8
    ///   - dateString: Target date in "yyyy-MM-dd" format. If nil, uses current date.
    ///   - typeFilter: Filter by usage type. Valid values: "app", "website".
    ///                Default: "app"
    ///   - completion: Completion handler called with results
    ///     - result: Formatted usage data string, or nil if no data found
    ///     - error: Error if data retrieval failed, nil on success
    ///
    /// ## Example Usage
    /// ```swift
    /// ipcService.getUsageActivity(
    ///     topPercentage: 0.9,
    ///     dateString: "2024-09-26",
    ///     typeFilter: "app"
    /// ) { result, error in
    ///     if let error = error {
    ///         print("Failed to get usage: \(error)")
    ///     } else if let usage = result {
    ///         print("Usage data: \(usage)")
    ///     } else {
    ///         print("No usage data available")
    ///     }
    /// }
    /// ```
    ///
    /// ## Output Format
    /// Returns a pipe-separated string in the format: `name:duration|name:duration|...|Total:duration`
    ///
    /// - **Format**: Each entry is `activityName:duration`
    /// - **Duration examples**:
    ///   - `3h45m` = 3 hours and 45 minutes
    ///   - `2h0m` = exactly 2 hours (0 minutes)
    ///   - `45m` = 45 minutes (less than 1 hour)
    ///   - `5m` = 5 minutes
    /// - **Ordering**: Activities sorted by usage time (highest first)
    /// - **Total**: Final entry is always `Total:duration` showing total tracked time
    /// - **Example**: `"Xcode:3h45m|Safari:2h18m|Terminal:1h20m|Total:7h23m"`
    func getUsageActivity(
        topPercentage: Double,
        dateString: String?,
        typeFilter: String,
        completion: @escaping (String?, Error?) -> Void
    )

    /// Retrieves the current version of the SimplyTrack application
    ///
    /// This method returns the app's version string from the main bundle.
    /// It also serves as a connectivity check - if this method succeeds,
    /// it indicates the main app is running and IPC communication is working.
    ///
    /// - Parameter completion: Completion handler called with the version string
    ///   - version: Current app version (e.g., "1.2.3"), never nil
    ///
    /// ## Example Usage
    /// ```swift
    /// ipcService.getVersion { version in
    ///     print("SimplyTrack version: \(version)")
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// This method does not return errors in the completion handler.
    /// If the main app is not running or IPC fails, the NSXPCConnection
    /// will handle the error at the connection level.
    func getVersion(completion: @escaping (String) -> Void)
}
