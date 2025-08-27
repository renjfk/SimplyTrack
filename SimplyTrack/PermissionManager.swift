//
//  PermissionManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 02.09.2025.
//

import Foundation
import AppKit

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var automationPermissionStatus: PermissionStatus = .notDetermined
    @Published var lastError: String? = nil
    
    private let supportedBrowserBundleIds = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.operasoftware.Opera", 
        "com.brave.Browser"
    ]
    
    private init() {
        // Don't check permissions on init - let background tracking handle it
    }
    
    func handleBrowserPermissionResult(success: Bool) {
        Task { @MainActor in
            if success {
                self.automationPermissionStatus = .granted
            } else {
                self.automationPermissionStatus = .denied
            }
        }
    }
    
    func openSystemPreferences() {
        // Open Security & Privacy > Privacy > Automation in System Preferences
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    func canTrackWebsites() -> Bool {
        return automationPermissionStatus == .granted
    }
    
    func handleBrowserError(_ errorMessage: String) {
        Task { @MainActor in
            self.lastError = errorMessage
        }
    }
    
    func clearError() {
        Task { @MainActor in
            self.lastError = nil
        }
    }
    
}
