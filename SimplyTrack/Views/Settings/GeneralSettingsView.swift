//
//  GeneralSettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import SwiftUI
import ServiceManagement

/// General settings view for app preferences and system integration.
/// Handles launch at login configuration and update frequency settings.
struct GeneralSettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager.shared
    @State private var launchAtLoginEnabled = false
    @AppStorage("updateFrequency", store: .app) private var updateFrequency: UpdateFrequency = .daily
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("Launch SimplyTrack at login", isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { _ in toggleLaunchAtLogin() }
                        ))
                        .toggleStyle(.switch)
                        Spacer()
                    }
                    
                    Text("Automatically start SimplyTrack when you log in to your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Check for updates")
                        
                        Spacer()
                        
                        Picker("", selection: $updateFrequency) {
                            ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Text("How often SimplyTrack should check for new versions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                launchAtLoginEnabled = await loginItemManager.getCurrentStatus()
            }
        }
    }
    
    private func toggleLaunchAtLogin() {
        Task {
            do {
                launchAtLoginEnabled = try await loginItemManager.toggleLaunchAtLogin()
            } catch {
                // Error handling is done in the manager
            }
        }
    }
    
}

#Preview {
    GeneralSettingsView()
        .frame(width: 550, height: 400)
}
