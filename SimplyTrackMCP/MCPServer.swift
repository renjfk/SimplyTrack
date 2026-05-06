//
//  MCPServer.swift
//  SimplyTrackMCP
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation
import MCP

/// MCP stdio server implementation that forwards requests to main app via Unix domain sockets
actor MCPServer {
    private let ipcClient: IPCClient

    init() throws {
        // Get socket path from environment variable
        guard let socketPath = ProcessInfo.processInfo.environment["SIMPLYTRACK_SOCKET_PATH"] else {
            throw NSError(
                domain: "SimplyTrackMCP",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "SIMPLYTRACK_SOCKET_PATH environment variable not set"]
            )
        }
        self.ipcClient = IPCClient(socketPath: socketPath)
    }

    /// Runs the MCP stdio server using the official MCP SDK
    func run() async throws {
        // Using Unix domain sockets for IPC communication

        // Test connection to main app
        let version: String
        do {
            version = try await ipcClient.getVersion()
        } catch {
            throw NSError(
                domain: "SimplyTrackMCP",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Cannot connect to SimplyTrack app. Please ensure SimplyTrack is running. Details: \(error.localizedDescription)"]
            )
        }

        // Create server with capabilities according to the SDK documentation
        let server = Server(
            name: "SimplyTrack",
            version: version,
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )

        // Register tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: Self.tools)
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
            try await server.start(transport: transport)
            // Keep the server running using the proper SDK method
            await server.waitUntilCompleted()
        } catch {
            throw error
        }
    }

    private static var tools: [Tool] {
        [
            Tool(
                name: "get_usage_activity",
                description: "Legacy compact daily usage summary. Returns pipe-separated name:duration rows for app or website usage.",
                inputSchema: usageActivitySchema
            ),
            Tool(
                name: "get_usage_range",
                description: "Return JSON summary of tracked usage across a time range. Supports app/website/all filters and grouping by name, identifier, type, or session.",
                inputSchema: usageRangeSchema
            ),
            Tool(
                name: "get_raw_sessions",
                description: "Return raw tracked sessions as JSON rows clipped to the requested time range. Use this when exact start/end times matter.",
                inputSchema: rawSessionsSchema
            ),
            Tool(
                name: "get_current_activity",
                description: "Return active in-progress sessions as JSON. Useful for asking what the user appears to be doing right now.",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            ),
            Tool(
                name: "get_hourly_timeline",
                description: "Return JSON with 24 hourly buckets for a date, splitting sessions across hour boundaries.",
                inputSchema: timelineSchema
            ),
            Tool(
                name: "get_daily_summary",
                description: "Return JSON daily summary of top activities for a date, grouped by activity name.",
                inputSchema: dailySummarySchema
            ),
        ]
    }

    private static var usageActivitySchema: Value {
        objectSchema(properties: [
            "topPercentage": property(type: "number", description: "Include top activities by usage time - 0.8 means top 80% most used (default: 0.8)"),
            "dateString": property(type: "string", description: "Specific date to analyze in YYYY-MM-DD format, or omit for today"),
            "typeFilter": property(type: "string", description: "Data type: 'app' or 'website' (default: 'app')"),
        ])
    }

    private static var usageRangeSchema: Value {
        objectSchema(properties: rangeProperties(extra: ["groupBy": property(type: "string", description: "Grouping: 'name', 'identifier', 'type', or 'session' (default: 'name')")]))
    }

    private static var rawSessionsSchema: Value {
        objectSchema(properties: rangeProperties(extra: [:]))
    }

    private static var timelineSchema: Value {
        objectSchema(properties: [
            "dateString": property(type: "string", description: "Date in YYYY-MM-DD format, or omit for today"),
            "typeFilter": property(type: "string", description: "Data type: 'app', 'website', or 'all' (default: 'all')"),
        ])
    }

    private static var dailySummarySchema: Value {
        objectSchema(properties: [
            "dateString": property(type: "string", description: "Date in YYYY-MM-DD format, or omit for today"),
            "typeFilter": property(type: "string", description: "Data type: 'app', 'website', or 'all' (default: 'all')"),
            "limit": property(type: "number", description: "Maximum number of activities to return (default: 20)"),
        ])
    }

    private static func rangeProperties(extra: [String: Value]) -> [String: Value] {
        var properties = [
            "startTime": property(type: "string", description: "Range start as ISO-8601 date/time or YYYY-MM-DD. Defaults to 24 hours before endTime."),
            "endTime": property(type: "string", description: "Range end as ISO-8601 date/time or YYYY-MM-DD. Defaults to now."),
            "typeFilter": property(type: "string", description: "Data type: 'app', 'website', or 'all' (default: 'all')"),
            "includeActive": property(type: "boolean", description: "Whether to include active in-progress sessions (default: true)"),
        ]
        properties.merge(extra) { _, new in new }
        return properties
    }

    private static func objectSchema(properties: [String: Value]) -> Value {
        .object(["type": .string("object"), "properties": .object(properties)])
    }

    private static func property(type: String, description: String) -> Value {
        .object(["type": .string(type), "description": .string(description)])
    }

    /// Handler for tool calls
    private func handleCallTool(params: CallTool.Parameters) async -> CallTool.Result {
        do {
            let output: String?
            switch params.name {
            case "get_usage_activity":
                output = try await ipcClient.getUsageActivity(
                    topPercentage: params.arguments?["topPercentage"]?.doubleValue ?? 0.8,
                    dateString: params.arguments?["dateString"]?.stringValue,
                    typeFilter: params.arguments?["typeFilter"]?.stringValue ?? "app"
                )
            case "get_usage_range":
                output = try await ipcClient.getUsageRange(
                    startTime: params.arguments?["startTime"]?.stringValue,
                    endTime: params.arguments?["endTime"]?.stringValue,
                    typeFilter: params.arguments?["typeFilter"]?.stringValue,
                    groupBy: params.arguments?["groupBy"]?.stringValue,
                    includeActive: params.arguments?["includeActive"]?.boolValue
                )
            case "get_raw_sessions":
                output = try await ipcClient.getRawSessions(
                    startTime: params.arguments?["startTime"]?.stringValue,
                    endTime: params.arguments?["endTime"]?.stringValue,
                    typeFilter: params.arguments?["typeFilter"]?.stringValue,
                    includeActive: params.arguments?["includeActive"]?.boolValue
                )
            case "get_current_activity":
                output = try await ipcClient.getCurrentActivity()
            case "get_hourly_timeline":
                output = try await ipcClient.getHourlyTimeline(
                    dateString: params.arguments?["dateString"]?.stringValue,
                    typeFilter: params.arguments?["typeFilter"]?.stringValue
                )
            case "get_daily_summary":
                output = try await ipcClient.getDailySummary(
                    dateString: params.arguments?["dateString"]?.stringValue,
                    typeFilter: params.arguments?["typeFilter"]?.stringValue,
                    limit: params.arguments?["limit"]?.doubleValue.map(Int.init)
                )
            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }

            return .init(content: [.text(output ?? "No usage data found")], isError: false)
        } catch {
            return .init(content: [.text("Error running \(params.name): \(error.localizedDescription)")], isError: true)
        }
    }
}
