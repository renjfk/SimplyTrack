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

        return """
            {
              "mcpServers": {
                "simplytrack": {
                  "command": "\(mcpPath)"
                }
              }
            }
            """
    }

    func checkConfiguration() {
        // Try direct access first (read-only should work with new entitlement)
        let configPath = claudeConfigPath
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: configPath) else {
            status = .warning("Not configured in Claude Desktop")
            return
        }

        checkConfigurationAtURL(URL(fileURLWithPath: configPath))
    }

    private func checkConfigurationAtURL(_ configURL: URL) {
        do {
            let configData = try Data(contentsOf: configURL)
            let configJSON = try JSONSerialization.jsonObject(with: configData) as? [String: Any] ?? [:]

            if let mcpServers = configJSON["mcpServers"] as? [String: Any],
                let simplytrackConfig = mcpServers["simplytrack"] as? [String: Any],
                let command = simplytrackConfig["command"] as? String
            {

                // Verify the configured path matches our expected MCP binary path
                let expectedPath = Bundle.main.bundlePath + "/Contents/MacOS/SimplyTrackMCP"
                if command == expectedPath {
                    status = .success("Already configured in Claude Desktop")
                } else {
                    status = .warning("Configuration points to different SimplyTrack version")
                }
            } else {
                status = .warning("Not configured in Claude Desktop")
            }
        } catch {
            status = .error("Failed to read configuration: \(error.localizedDescription)")
        }
    }

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

        // Create the MCP configuration
        let mcpServerConfig: [String: Any] = [
            "command": mcpPath
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
