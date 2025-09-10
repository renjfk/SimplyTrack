//
//  AISettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import SwiftUI

/// AI settings view for configuring OpenAI integration and daily summary notifications.
/// Handles API endpoint configuration, authentication, and notification scheduling.
struct AISettingsView: View {
    @AppStorage("aiEndpoint", store: .app) private var aiEndpoint = ""
    @AppStorage("aiModel", store: .app) private var aiModel = ""
    
    @State private var aiApiKey = ""
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    
    // Notification settings
    @AppStorage("summaryNotificationsEnabled", store: .app) private var summaryNotificationsEnabled = false
    @AppStorage("summaryNotificationTime", store: .app) private var summaryNotificationTime: Double = AppStorageDefaults.summaryNotificationTime
    @AppStorage("summaryNotificationPrompt", store: .app) private var summaryNotificationPrompt = AppStorageDefaults.summaryNotificationPrompt
    
    private var hasValidationErrors: Bool {
        aiEndpoint.isEmpty || aiModel.isEmpty || summaryNotificationPrompt.isEmpty
    }
    
    private var canTestSettings: Bool {
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
                        errorMessage: "Endpoint is required"
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField(text: $aiApiKey, prompt: Text("sk-...")) {
                            Text("API Key")
                        }
                        .onChange(of: aiApiKey) { _, newValue in
                            saveApiKeyToKeychain(newValue)
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
                        errorMessage: "Model is required"
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button("Test Connection") {
                                Task {
                                    await testConnection()
                                }
                            }
                            .disabled(!canTestSettings || isTestingConnection)
                            
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
                        HStack {
                            Toggle("Enable summary notification", isOn: Binding(
                                get: { summaryNotificationsEnabled && !hasValidationErrors },
                                set: { newValue in
                                    summaryNotificationsEnabled = newValue
                                }
                            ))
                                .disabled(hasValidationErrors)
                                .toggleStyle(.switch)
                            Spacer()
                        }
                        
                        Text("Send daily notification with AI-generated usage summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Notification time")
                            
                            Spacer()
                            
                            DatePicker("", selection: Binding(
                                get: { Date(timeIntervalSince1970: summaryNotificationTime) },
                                set: { summaryNotificationTime = $0.timeIntervalSince1970 }
                            ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                        }
                        
                        Text("Time to receive daily summary notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(text: $summaryNotificationPrompt, prompt: Text("Create a brief daily summary..."), axis: .vertical) {
                            Text("Prompt")
                        }
                        .lineLimit(5...10)
                        
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
            }
            .formStyle(.grouped)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadApiKeyFromKeychain()
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
            print("Failed to load API key from keychain: \(error)")
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
            print("Failed to save API key to keychain: \(error)")
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

struct ValidatedTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let helpText: String
    let required: Bool
    let errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(text: $text, prompt: Text(placeholder)) {
                Text(title)
            }
            
            if required && text.isEmpty {
                Text(errorMessage)
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

struct ValidatedSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let helpText: String
    let errorMessage: String?
    let shouldValidate: Bool
    let validator: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(text: $text, prompt: Text(placeholder)) {
                Text(title)
            }
            .onChange(of: text) { _, newValue in
                if shouldValidate {
                    validator(newValue)
                }
            }
            
            if shouldValidate, let error = errorMessage {
                Text(error)
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
