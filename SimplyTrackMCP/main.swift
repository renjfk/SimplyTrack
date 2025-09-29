//
//  main.swift
//  SimplyTrackMCP
//
//  MCP server entry point - starts stdio server immediately
//  Created by Soner Köksal on 26.09.2025.
//

import Foundation

// Start the MCP stdio server immediately
Task {
    do {
        let server = try MCPServer()
        try await server.run()
    } catch {
        // Print error to stderr so it's visible to users
        fputs("ERROR: \(error.localizedDescription)\n", stderr)
        fflush(stderr)
        exit(1)
    }
}

// Keep the process running
RunLoop.main.run()
