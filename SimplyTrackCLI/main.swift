//
//  main.swift
//  SimplyTrackCLI
//
//  Separate CLI client that communicates with the main SimplyTrack app via IPC
//  Created by Soner Köksal on 26.09.2025.
//

import ArgumentParser
import Foundation
import os

/// Separate CLI client for SimplyTrack that communicates with main app via XPC
@main
struct SimplyTrackCLIClient: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simplytrack-cli",
        abstract: "CLI client for SimplyTrack that communicates with the main application.",
        version: "1.0.0",
        subcommands: [StdioCommand.self]
    )

    mutating func run() async throws {
        // Default behavior: show help
        print(Self.helpMessage())
    }
}

extension SimplyTrackCLIClient {
    struct StdioCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stdio",
            abstract: "Start MCP stdio server by connecting to the main SimplyTrack application."
        )

        mutating func run() async throws {
            let client = IPCClient()

            do {
                try await client.startStdioServer()
            } catch IPCClientError.mainAppNotRunning {
                print("Error: SimplyTrack main application is not running.")
                print("Please start SimplyTrack.app first, then try again.")
                throw ExitCode(1)
            } catch {
                print("Error: \(error.localizedDescription)")
                throw ExitCode(1)
            }
        }
    }
}

/// IPC client that connects to the main SimplyTrack application
class IPCClient {
    private let logger = Logger(subsystem: "com.renjfk.SimplyTrack.cli", category: "IPCClient")

    func startStdioServer() async throws {
        // Check if main app is running first
        guard try await isMainAppRunning() else {
            throw IPCClientError.mainAppNotRunning
        }

        logger.info("Starting MCP stdio server via IPC connection to main app")

        // Create the MCP stdio server that forwards requests to main app
        let server = CLIMCPServer(ipcClient: self)
        try await server.run()
    }

    /// Check if the main SimplyTrack app is running
    func isMainAppRunning() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: "com.renjfk.SimplyTrack")
            connection.remoteObjectInterface = NSXPCInterface(with: SimplyTrackIPCProtocol.self)

            connection.invalidationHandler = {
                continuation.resume(returning: false)
            }

            connection.resume()

            let service = connection.remoteObjectProxy as? SimplyTrackIPCProtocol
            service?.isAppRunning { isRunning in
                connection.invalidate()
                continuation.resume(returning: isRunning)
            }
        }
    }

    /// Forward usage activity request to main app
    func getUsageActivity(limit: Int, topPercentage: Double, dateString: String?, typeFilter: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: "com.renjfk.SimplyTrack")
            connection.remoteObjectInterface = NSXPCInterface(with: SimplyTrackIPCProtocol.self)

            connection.invalidationHandler = {
                continuation.resume(throwing: IPCClientError.ipcConnectionFailed(NSError(domain: "Connection invalidated", code: -1)))
            }

            connection.resume()

            let service = connection.remoteObjectProxy as? SimplyTrackIPCProtocol
            service?.getUsageActivity(
                limit: limit,
                topPercentage: topPercentage,
                dateString: dateString,
                typeFilter: typeFilter
            ) { result, error in
                connection.invalidate()

                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

/// Errors for IPC client operations
enum IPCClientError: LocalizedError {
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

/// Protocol definition for IPC communication (copied from main app)
@objc protocol SimplyTrackIPCProtocol {
    func getUsageActivity(limit: Int, topPercentage: Double, dateString: String?, typeFilter: String, completion: @escaping (String?, Error?) -> Void)
    func isAppRunning(completion: @escaping (Bool) -> Void)
}
