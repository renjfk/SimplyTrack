//
//  LoginItemManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import SwiftUI
import ServiceManagement
import os

/// Manages the app's "Launch at Login" functionality using ServiceManagement framework.
/// Handles registration/unregistration with macOS launch services and permission management.
/// Provides UI state for permission denied scenarios and system preferences integration.
class LoginItemManager: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LoginItemManager")
    /// Shared singleton instance for login item management
    static let shared = LoginItemManager()
    
    /// Indicates if the user has denied login item permissions
    @Published var permissionDenied = false
    
    private init() {}
    
    /// Toggles the app's launch at login status.
    /// If permissions are denied, opens system preferences instead.
    /// - Returns: True if launch at login is now enabled, false if disabled
    /// - Throws: ServiceManagement errors if registration fails
    func toggleLaunchAtLogin() async throws -> Bool {
        if permissionDenied {
            openLoginItemsSettings()
            return false
        }
        
        let currentStatus = SMAppService.mainApp.status == .enabled
        
        do {
            if currentStatus {
                try await SMAppService.mainApp.unregister()
                await MainActor.run { 
                    permissionDenied = false
                }
                return false
            } else {
                try SMAppService.mainApp.register()
                await MainActor.run { 
                    permissionDenied = false
                }
                return true
            }
        } catch {
            logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
            await MainActor.run { 
                permissionDenied = true 
            }
            throw error
        }
    }
    
    /// Gets the current launch at login status.
    /// - Returns: True if the app is registered to launch at login
    func getCurrentStatus() async -> Bool {
        return await Task.detached {
            SMAppService.mainApp.status == .enabled
        }.value
    }
    
    /// Opens System Preferences to the Login Items settings.
    /// Used when permissions are denied to guide user to manual configuration.
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}