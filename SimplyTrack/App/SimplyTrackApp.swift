//
//  SimplyTrackApp.swift
//  SimplyTrack
//
//  SwiftUI application entry point that configures the app structure and integrates
//  with AppDelegate for lifecycle management. Provides settings window and menu configuration.
//  Created by Soner Köksal on 27.08.2025.
//

import SwiftUI
import AppKit
import SwiftData

/// Main SwiftUI application struct that defines the app structure and configuration.
/// Uses AppDelegate for lifecycle management while providing SwiftUI-based settings interface.
@main
struct SimplyTrackApp: App {
    
    /// App delegate adapter that bridges SwiftUI app with NSApplicationDelegate lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Settings window scene - the main user interface for configuration
        Settings {
            SettingsWindow()
        }
        .modelContainer(DatabaseManager.shared.modelContainer) // Inject SwiftData container
        .commands {
            // Replace default app settings menu with custom preferences command
            CommandGroup(replacing: .appSettings) {
                SettingsLink {
                    Text("Preferences...")
                }
                .keyboardShortcut(",", modifiers: .command) // Standard Cmd+, shortcut
                .onAppear {
                    // Ensure app becomes active when preferences are opened
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
