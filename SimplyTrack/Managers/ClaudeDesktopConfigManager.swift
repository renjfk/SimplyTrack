//
//  ClaudeDesktopConfigManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 26.09.2025.
//

import AppKit
import Foundation
import SwiftUI
import os

/// Manager for handling Claude Desktop MCP configuration
class ClaudeDesktopConfigManager: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ClaudeDesktopConfigManager")

    @Published var status: MCPConfigStatus = .neutral("Checking configuration...")

    enum MCPConfigStatus {
        case neutral(String)
        case success(String)
        case warning(String)
        case error(String)

        var icon: String {
            switch self {
            case .neutral: return "info.circle"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .neutral: return .secondary
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var message: String {
            switch self {
            case .neutral(let message): return message
            case .success(let message): return message
            case .warning(let message): return message
            case .error(let message): return message
            }
        }
    }

    var claudeConfigPath: String {
        // Get the real user home directory bypassing sandbox
        let realHomeDirectory = URL(fileURLWithPath: "/Users/\(NSUserName())")
        return realHomeDirectory.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json").path
    }

    var mcpConfiguration: String {
        let bundlePath = Bundle.main.bundlePath
        let mcpPath = bundlePath + "/Contents/MacOS/SimplyTrackMCP"

        // Use static socket path from IPCServiceManager
        let socketPath = IPCServiceManager.socketPath

        return """
            {
              "mcpServers": {
                "simplytrack": {
                  "command": "\(mcpPath)",
                  "env": {
                    "SIMPLYTRACK_SOCKET_PATH": "\(socketPath)"
                  }
                }
              }
            }
            """
    }

    /// Checks if Claude Desktop is properly configured with SimplyTrack MCP server
    ///
    /// This method validates that the Claude Desktop configuration file contains the correct
    /// MCP server configuration for SimplyTrack, including the proper command path and
    /// socket path environment variable. Updates the `status` property with the result.
    ///
    /// - Sets status to `.success` if configuration matches exactly
    /// - Sets status to `.warning` if configuration is missing or needs update
    func checkConfiguration() {
        let configPath = claudeConfigPath

        guard FileManager.default.fileExists(atPath: configPath) else {
            status = .warning("Configuration mismatch - needs update")
            return
        }

        checkConfigurationAtURL(URL(fileURLWithPath: configPath))
    }

    private func checkConfigurationAtURL(_ configURL: URL) {
        do {
            let configData = try Data(contentsOf: configURL)
            let configJSON = try JSONSerialization.jsonObject(with: configData) as? [String: Any] ?? [:]

            // Check if configuration matches exactly what we expect
            let expectedPath = Bundle.main.bundlePath + "/Contents/MacOS/SimplyTrackMCP"
            let expectedSocketPath = IPCServiceManager.socketPath

            if let mcpServers = configJSON["mcpServers"] as? [String: Any],
                let simplytrackConfig = mcpServers["simplytrack"] as? [String: Any],
                let command = simplytrackConfig["command"] as? String,
                let env = simplytrackConfig["env"] as? [String: String],
                command == expectedPath,
                env["SIMPLYTRACK_SOCKET_PATH"] == expectedSocketPath
            {
                status = .success("Already configured in Claude Desktop")
            } else {
                status = .warning("Configuration mismatch - needs update")
            }
        } catch {
            status = .warning("Configuration mismatch - needs update")
        }
    }

    /// Prompts user to select Claude Desktop configuration file and adds SimplyTrack MCP configuration
    ///
    /// This method presents a file picker dialog allowing the user to select their Claude Desktop
    /// configuration file. Once selected, it adds or updates the SimplyTrack MCP server configuration
    /// with the correct command path and Unix domain socket configuration.
    ///
    /// The method handles:
    /// - Opening a file picker dialog with appropriate defaults
    /// - Merging with existing configuration if present
    /// - Creating proper MCP server configuration with Unix domain socket support
    /// - Updating the `status` property with the operation result
    ///
    /// - Sets status to `.success` if configuration is added successfully
    /// - Sets status to `.error` if file access is denied or write fails
    func addConfiguration() {
        DispatchQueue.main.async { [weak self] in
            let openPanel = NSOpenPanel()
            openPanel.message = "Please select your Claude Desktop configuration file to add SimplyTrack MCP configuration"
            openPanel.prompt = "Select"
            openPanel.allowedContentTypes = [.json]
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Application Support/Claude")
            openPanel.nameFieldStringValue = "claude_desktop_config.json"

            openPanel.begin { [weak self] response in
                guard let self = self else { return }

                if response == .OK, let configURL = openPanel.url {
                    self.addConfigurationToURL(configURL)
                } else {
                    self.status = .error("File access required to update Claude Desktop configuration")
                }
            }
        }
    }

    private func addConfigurationToURL(_ configURL: URL) {
        let bundlePath = Bundle.main.bundlePath
        let mcpPath = bundlePath + "/Contents/MacOS/SimplyTrackMCP"

        // Create the MCP configuration with socket path environment variable
        let mcpServerConfig: [String: Any] = [
            "command": mcpPath,
            "env": [
                "SIMPLYTRACK_SOCKET_PATH": IPCServiceManager.socketPath
            ],
        ]

        var configJSON: [String: Any] = [:]

        // Read existing config if it exists
        if FileManager.default.fileExists(atPath: configURL.path) {
            do {
                let existingData = try Data(contentsOf: configURL)
                configJSON = (try JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
            } catch {
                status = .error("Failed to read existing config: \(error.localizedDescription)")
                return
            }
        }

        // Add or update mcpServers section
        var mcpServers = configJSON["mcpServers"] as? [String: Any] ?? [:]
        mcpServers["simplytrack"] = mcpServerConfig
        configJSON["mcpServers"] = mcpServers

        // Write the updated configuration
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: configJSON, options: .prettyPrinted)
            try updatedData.write(to: configURL)
            status = .success("Successfully added to Claude Desktop")
        } catch {
            status = .error("Failed to write configuration: \(error.localizedDescription)")
        }
    }
}
