//
//  MCPServer.swift
//  SimplyTrackMCP
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation
import MCP
import os

/// MCP stdio server implementation that forwards requests to main app via IPC
actor MCPServer {
    private let logger = Logger(subsystem: "com.renjfk.SimplyTrackMCP", category: "MCPServer")

    private lazy var ipcService: SimplyTrackIPCProtocol = {
        let connection = NSXPCConnection(machServiceName: "com.renjfk.SimplyTrack")
        connection.remoteObjectInterface = NSXPCInterface(with: SimplyTrackIPCProtocol.self)
        connection.resume()
        return connection.remoteObjectProxy as! SimplyTrackIPCProtocol
    }()

    /// Runs the MCP stdio server using the official MCP SDK
    func run() async throws {
        logger.error("Starting SimplyTrack MCP server...")

        // Get version from main app (this also checks if it's running)
        let version: String
        do {
            version = try await getVersion()
        } catch {
            logger.error("Main SimplyTrack app is not running")
            throw MCPServerError.mainAppNotRunning
        }

        // Create server with capabilities according to the SDK documentation
        let server = Server(
            name: "SimplyTrack",
            version: version,
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )

        logger.error("Server created, registering handlers...")

        // Register tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: "get_usage_activity",
                    description: """
                        Get user's application or website usage data showing time spent on different activities.

                        This tool retrieves detailed usage statistics from SimplyTrack, including:
                        - Time spent on each application or website
                        - Percentage of total usage time
                        - Activity duration and frequency
                        - Aggregated data for productivity analysis

                        The data is formatted as human-readable text suitable for analysis and insights.
                        Perfect for understanding work patterns, identifying productivity trends, and time management.

                        ## Response Format:

                        The tool returns data in a simple pipe-separated format: `name:duration|name:duration|...|Total:duration`

                        ### Example Responses:

                        **Application Usage (typeFilter: "app"):**
                        ```
                        Xcode:3h45m|Safari:2h18m|Terminal:1h20m|Total:7h23m
                        ```

                        **Website Usage (typeFilter: "website"):**
                        ```
                        github.com:1h35m|stackoverflow.com:58m|docs.swift.org:42m|claude.ai:37m|Total:4h12m
                        ```

                        **No Data Available:**
                        ```
                        No usage data found
                        ```

                        **Format Details:**
                        - Each entry: `activityName:duration`
                        - Duration format examples:
                          • `3h45m` = 3 hours and 45 minutes
                          • `2h0m` = exactly 2 hours (0 minutes)
                          • `45m` = 45 minutes (less than 1 hour)
                          • `5m` = 5 minutes
                        - Activities are ordered by usage time (highest first)
                        - Final entry is always `Total:duration` showing total tracked time
                        - Activities included based on topPercentage (default 80% of total usage time)

                        Returns: Pipe-separated usage data string as shown above, or "No usage data found" if no data exists.
                        """,
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "topPercentage": .object([
                                "type": .string("number"),
                                "description": .string("Include top activities by usage time - 0.8 means top 80% most used (default: 0.8)"),
                            ]),
                            "dateString": .object([
                                "type": .string("string"),
                                "description": .string("Specific date to analyze in YYYY-MM-DD format, or omit for today"),
                            ]),
                            "typeFilter": .object([
                                "type": .string("string"),
                                "description": .string("Data type: 'app' for applications or 'website' for web browsing (default: 'app')"),
                            ]),
                        ]),
                    ])
                )
            ]
            return .init(tools: tools)
        }

        // Register tool call handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                return .init(content: [.text("Server not available")], isError: true)
            }
            return await self.handleCallTool(params: params)
        }

        // Register prompts list handler (empty response)
        await server.withMethodHandler(ListPrompts.self) { _ in
            return .init(prompts: [])
        }

        // Register resources list handler (empty response)
        await server.withMethodHandler(ListResources.self) { _ in
            return .init(resources: [])
        }

        // Create stdio transport
        let transport = StdioTransport()

        // Start the server and keep it running
        do {
            logger.error("Starting server transport...")
            try await server.start(transport: transport)

            logger.error("Server started successfully, waiting for completion...")
            // Keep the server running using the proper SDK method
            await server.waitUntilCompleted()
        } catch {
            logger.error("MCP server error: \(error.localizedDescription)")
            throw error
        }
    }

    /// Handler for tool calls
    private func handleCallTool(params: CallTool.Parameters) async -> CallTool.Result {
        switch params.name {
        case "get_usage_activity":
            // Extract parameters exactly like IPC service
            let topPercentage = params.arguments?["topPercentage"]?.doubleValue ?? 0.8
            let dateString = params.arguments?["dateString"]?.stringValue
            let typeFilter = params.arguments?["typeFilter"]?.stringValue ?? "app"

            do {
                // Use same logic as IPC service
                let usage = try await getUsageActivity(
                    topPercentage: topPercentage,
                    dateString: dateString,
                    typeFilter: typeFilter
                )

                if let usage = usage, !usage.isEmpty {
                    return .init(
                        content: [.text(usage)],
                        isError: false
                    )
                } else {
                    return .init(
                        content: [.text("No usage data found")],
                        isError: false
                    )
                }
            } catch {
                logger.error("Failed to fetch usage activity: \(error.localizedDescription)")
                return .init(
                    content: [.text("Error fetching usage activity: \(error.localizedDescription)")],
                    isError: true
                )
            }

        default:
            return .init(
                content: [.text("Unknown tool: \(params.name)")],
                isError: true
            )
        }
    }

    /// Get usage activity data by forwarding to main app via IPC
    private func getUsageActivity(topPercentage: Double, dateString: String?, typeFilter: String) async throws -> String? {
        // Forward request to main app via IPC
        return try await withCheckedThrowingContinuation { continuation in
            ipcService.getUsageActivity(
                topPercentage: topPercentage,
                dateString: dateString,
                typeFilter: typeFilter
            ) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Get version from the main SimplyTrack app
    private func getVersion() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            ipcService.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }
}

/// Errors for MCP server
enum MCPServerError: LocalizedError {
    case mainAppNotRunning
    case ipcConnectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .mainAppNotRunning:
            return "SimplyTrack main application is not running. Please start the app first."
        case .ipcConnectionFailed(let error):
            return "Failed to connect to SimplyTrack app: \(error.localizedDescription)"
        }
    }
}
