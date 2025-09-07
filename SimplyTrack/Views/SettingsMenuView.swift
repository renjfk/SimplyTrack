//
//  SettingsMenuView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI
import ServiceManagement

struct SettingsMenuView: View {
    @State private var launchAtLoginEnabled = false
    @Binding var loginItemPermissionDenied: Bool
    @State private var showingUpdateAlert = false
    @State private var updateError: UpdateError?
    
    let viewMode: ContentView.ViewMode
    @Binding var showingClearDataConfirmation: Bool
    
    var body: some View {
        Menu {
            Button("About") {
                AboutWindowController.show()
            }
            
            Button(action: {
                toggleLaunchAtLogin()
            }) {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    if loginItemPermissionDenied {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    } else if launchAtLoginEnabled {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            Button(action: {
                showingClearDataConfirmation = true
            }) {
                HStack {
                    Text("Clear \(viewMode == .day ? "Day" : "Week") Data")
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            Button(action: {
                Task {
                    await checkForUpdates()
                }
            }) {
                HStack {
                    Text("Check for Updates")
                }
            }
            
            Divider()
            
            Button("Quit SimplyTrack") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onAppear {
            Task {
                launchAtLoginEnabled = await Task.detached {
                    SMAppService.mainApp.status == .enabled
                }.value
            }
        }
        .alert("Update Error", isPresented: .constant(updateError != nil)) {
            Button("OK") {
                updateError = nil
            }
        } message: {
            Text(updateError?.localizedDescription ?? "An unknown error occurred")
        }
        .alert("No Updates Available", isPresented: $showingUpdateAlert) {
            Button("OK") {
                showingUpdateAlert = false
            }
        } message: {
            Text("You are already running the latest version of SimplyTrack.")
        }
    }
    
    private func toggleLaunchAtLogin() {
        if loginItemPermissionDenied {
            openLoginItemsSettings()
            return
        }
        
        Task {
            do {
                if launchAtLoginEnabled {
                    try await SMAppService.mainApp.unregister()
                    await MainActor.run { 
                        launchAtLoginEnabled = false
                        loginItemPermissionDenied = false
                    }
                } else {
                    try SMAppService.mainApp.register()
                    await MainActor.run { 
                        launchAtLoginEnabled = true
                        loginItemPermissionDenied = false
                    }
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
                await MainActor.run { 
                    loginItemPermissionDenied = true 
                }
            }
        }
    }
    
    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkForUpdates() async {
        do {
            let hasUpdate = try await UpdateManager.shared.checkForUpdates(showNotification: true)
            if !hasUpdate {
                showingUpdateAlert = true
            }
            // If update is available, notification will be shown automatically
        } catch {
            updateError = error as? UpdateError ?? UpdateError.invalidResponse
        }
    }
}
