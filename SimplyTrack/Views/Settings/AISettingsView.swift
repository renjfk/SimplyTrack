//
//  AISettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import SwiftUI
import os

/// AI settings view for configuring OpenAI integration and daily summary notifications.
/// Handles API endpoint configuration, authentication, and notification scheduling.
struct AISettingsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AISettingsView")

    @AppStorage("aiEndpoint", store: .app) private var aiEndpoint = ""
    @AppStorage("aiModel", store: .app) private var aiModel = ""

    @State private var aiApiKey = ""
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    @StateObject private var claudeConfigManager = ClaudeDesktopConfigManager()

    // Notification settings
    @AppStorage("summaryNotificationsEnabled", store: .app) private var summaryNotificationsEnabled = false
    @AppStorage("summaryNotificationTime", store: .app) private var summaryNotificationTime: Double = AppStorageDefaults.summaryNotificationTime
    @AppStorage("summaryNotificationPrompt", store: .app) private var summaryNotificationPrompt = AppStorageDefaults.summaryNotificationPrompt

    private var hasAIConfigurationErrors: Bool {
        aiEndpoint.isEmpty || aiModel.isEmpty || summaryNotificationPrompt.isEmpty
    }

    private var canTestAIConnection: Bool {
        !aiEndpoint.isEmpty && !aiModel.isEmpty
    }

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("AI Configuration") {
                    ValidatedTextField(
                        title: "API Endpoint",
                        text: $aiEndpoint,
                        placeholder: "https://api.openai.com/v1/chat/completions",
                        helpText: "Full URL for AI API chat completions endpoint",
                        required: summaryNotificationsEnabled,
                        requiredMessage: "Endpoint is required"
                    ) {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            SecureField(text: $aiApiKey, prompt: Text("sk-...")) {
                                Text("API Key")
                            }
                            .onChange(of: aiApiKey) { _, newValue in
                                saveApiKeyToKeychain(newValue)
                            }
                        }

                        Text("Your API key (optional, stored securely in Keychain)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ValidatedTextField(
                        title: "Model",
                        text: $aiModel,
                        placeholder: "gpt-4",
                        helpText: "AI model to use for features",
                        required: summaryNotificationsEnabled,
                        requiredMessage: "Model is required"
                    ) {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                            .frame(width: 16)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "network")
                                .foregroundColor(.green)
                                .frame(width: 16)
                            Button("Test Connection") {
                                Task {
                                    await testConnection()
                                }
                            }
                            .disabled(!canTestAIConnection || isTestingConnection)

                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            }

                            Spacer()
                        }

                        Text("Test API endpoint and model availability. Your AI provider may charge for each token used.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    if let result = testResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .font(.caption)

                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.top, 4)
                    }

                }

                Section("Summary Notifications") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            Toggle(
                                "Enable summary notification",
                                isOn: Binding(
                                    get: { summaryNotificationsEnabled && !hasAIConfigurationErrors },
                                    set: { newValue in
                                        summaryNotificationsEnabled = newValue
                                    }
                                )
                            )
                            .disabled(hasAIConfigurationErrors)
                            .toggleStyle(.switch)
                            Spacer()
                        }

                        Text("Send daily notification with AI-generated usage summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            Text("Notification time")

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { Date(timeIntervalSince1970: summaryNotificationTime) },
                                    set: { summaryNotificationTime = $0.timeIntervalSince1970 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .frame(width: 100)
                        }

                        Text("Time to receive daily summary notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.purple)
                                .frame(width: 16)
                            TextField(text: $summaryNotificationPrompt, prompt: Text("Create a brief daily summary..."), axis: .vertical) {
                                Text("Prompt")
                            }
                            .lineLimit(5...10)
                        }

                        if summaryNotificationsEnabled && summaryNotificationPrompt.isEmpty {
                            Text("Prompt is required")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Prompt for generating summary notification. Use {appSummary} and {websiteSummary} placeholders.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("AI Tool Integration") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "terminal")
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            Text("MCP Server Configuration")
                                .font(.headline)
                            Spacer()
                        }

                        Text("SimplyTrack includes a bundled MCP (Model Context Protocol) server for AI tool integration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purple)
                                .frame(width: 16)
                            Text("Configuration")
                            Spacer()
                        }

                        TextEditor(text: .constant(claudeConfigManager.mcpConfiguration))
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 160)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )

                        Text("Copy this configuration to your Claude Desktop config file (\(claudeConfigManager.claudeConfigPath))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: claudeConfigManager.status.icon)
                                .foregroundColor(claudeConfigManager.status.color)
                                .frame(width: 16)

                            Text(claudeConfigManager.status.message)
                                .foregroundColor(claudeConfigManager.status.color)

                            Spacer()
                        }

                        HStack(spacing: 8) {
                            if case .warning = claudeConfigManager.status {
                                Button("Auto-Configure") {
                                    claudeConfigManager.addConfiguration()
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button("Copy Configuration") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(claudeConfigManager.mcpConfiguration, forType: .string)
                            }

                            Button("Refresh Status") {
                                claudeConfigManager.checkConfiguration()
                            }

                            Spacer()
                        }

                        Text("Auto-configure Claude Desktop or copy configuration manually")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadApiKeyFromKeychain()
            claudeConfigManager.checkConfiguration()
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        testResult = nil

        do {
            let apiKey = aiApiKey.isEmpty ? "test-key" : aiApiKey
            let openAI = OpenAIService(apiURL: aiEndpoint, apiKey: apiKey)
            let testMessage = [OpenAIChatMessage(role: "user", content: "Hello")]

            let response = try await openAI.chatCompletions(
                model: aiModel,
                messages: testMessage,
                temperature: 0.7,
                maxTokens: 10
            )

            if let content = response.choices.first?.message.content {
                testResult = .success("Connection successful! Response: \"\(content.prefix(50))...\"")
            } else {
                testResult = .success("Connection successful!")
            }
        } catch {
            if aiApiKey.isEmpty {
                // If no API key, check if it's an auth error vs endpoint/model error
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("unauthorized") || errorDescription.contains("401") {
                    testResult = .success("Endpoint and model are valid (authentication required for full test)")
                } else {
                    testResult = .failure("Connection failed: \(error.localizedDescription)")
                }
            } else {
                testResult = .failure("Connection failed: \(error.localizedDescription)")
            }
        }

        isTestingConnection = false
    }

    private func loadApiKeyFromKeychain() {
        do {
            aiApiKey = try KeychainManager.shared.retrieve(key: "aiApiKey") ?? ""
        } catch {
            logger.error("Failed to load API key from keychain: \(error.localizedDescription)")
        }
    }

    private func saveApiKeyToKeychain(_ key: String) {
        do {
            if key.isEmpty {
                try KeychainManager.shared.delete(key: "aiApiKey")
            } else {
                try KeychainManager.shared.save(key: "aiApiKey", value: key)
            }
        } catch {
            logger.error("Failed to save API key to keychain: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensions

extension AISettingsView.TestResult {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    var message: String {
        switch self {
        case .success(let message): return message
        case .failure(let message): return message
        }
    }
}

// MARK: - Reusable Components

struct ValidatedTextField<Icon: View>: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let helpText: String
    let required: Bool
    let requiredMessage: String?
    let icon: Icon

    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        helpText: String,
        required: Bool = false,
        requiredMessage: String? = nil,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.helpText = helpText
        self.required = required
        self.requiredMessage = requiredMessage
        self.icon = icon()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                icon

                TextField(title, text: $text, prompt: Text(placeholder))
            }

            if required && text.isEmpty, let message = requiredMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AISettingsView()
        .frame(width: 550, height: 400)
}
