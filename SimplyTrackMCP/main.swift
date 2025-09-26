//
//  main.swift
//  SimplyTrackMCP
//
//  MCP server entry point - starts stdio server immediately
//  Created by Soner Köksal on 26.09.2025.
//

import Foundation
import os

// Start the MCP stdio server immediately
Task {
    let server = MCPServer()

    do {
        try await server.run()
    } catch {
        let logger = Logger(subsystem: "com.renjfk.SimplyTrackMCP", category: "Main")
        logger.error("MCP server failed: \(error.localizedDescription)")
        exit(1)
    }
}

// Keep the process running
RunLoop.main.run()
