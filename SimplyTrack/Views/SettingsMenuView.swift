//
//  SettingsMenuView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI
import ServiceManagement

/// Dropdown settings menu providing access to app preferences and actions.
/// Includes about panel, preferences, data clearing, update checking, and quit functionality.
/// Integrates with UpdateManager for manual update checks with error handling.
struct SettingsMenuView: View {
    @State private var showingUpdateAlert = false
    @State private var updateError: UpdateError?
    
    /// Current view mode for contextual data clearing
    let viewMode: ContentView.ViewMode
    /// Controls display of data clearing confirmation dialog
    @Binding var showingClearDataConfirmation: Bool
    
    var body: some View {
        Menu {
            Button("About SimplyTrack") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            
            Divider()

            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",", modifiers: .command)
            
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
    
    private func checkForUpdates() async {
        do {
            let hasUpdate = try await UpdateManager.shared.checkForUpdates(ignoreLastUpdate: true)
            if !hasUpdate {
                showingUpdateAlert = true
            }
            // If update is available, notification will be shown automatically
        } catch {
            updateError = error as? UpdateError ?? UpdateError.invalidResponse
        }
    }
}
