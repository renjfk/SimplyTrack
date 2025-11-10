//
//  GeneralSettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import ServiceManagement
import SwiftUI

/// General settings view for app preferences and system integration.
/// Handles launch at login configuration and update frequency settings.
struct GeneralSettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager.shared
    @State private var launchAtLoginEnabled = false
    @AppStorage("updateFrequency", store: .app) private var updateFrequency: UpdateFrequency = .daily
    @AppStorage("idleTimeoutSeconds", store: .app) private var idleTimeoutSeconds: Double = AppStorageDefaults.idleTimeoutSeconds

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "power")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Toggle(
                            "Launch SimplyTrack at login",
                            isOn: Binding(
                                get: { launchAtLoginEnabled },
                                set: { _ in toggleLaunchAtLogin() }
                            )
                        )
                        .toggleStyle(.switch)
                        Spacer()
                    }

                    Text("Automatically start SimplyTrack when you log in to your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.green)
                            .frame(width: 16)
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Text("Idle timeout")

                        Spacer()

                        Picker("", selection: $idleTimeoutSeconds) {
                            Text("1 minute").tag(60.0)
                            Text("2 minutes").tag(120.0)
                            Text("5 minutes").tag(300.0)
                            Text("10 minutes").tag(600.0)
                            Text("15 minutes").tag(900.0)
                            Text("30 minutes").tag(1800.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    Text("Stop tracking after this period of inactivity")
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
