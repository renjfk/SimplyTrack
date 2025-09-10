//
//  AppDelegate.swift
//  SimplyTrack
//
//  Main application delegate responsible for coordinating app lifecycle,
//  initializing core services, and managing cross-service communication.
//  Created by Soner Köksal on 27.08.2025.
//

import SwiftUI
import AppKit
import SwiftData
import os

/// Main application delegate that coordinates the app lifecycle and manages core services.
/// Serves as the central coordinator between tracking, persistence, notifications, and UI management.
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")
    
    // MARK: - Core Services
    
    private var menuBarManager: MenuBarManager?
    private var trackingService: TrackingService?
    private var sessionPersistenceService: SessionPersistenceService?
    private var notificationService: NotificationService?
    
    // MARK: - Published Properties
    
    /// Indicates whether notification permissions were denied by user
    @Published var notificationPermissionDenied = false
    
    /// Currently selected date in the UI (used across views)
    @Published var selectedDate = Date()
    
    // MARK: - AI Settings Storage
    
    @AppStorage("summaryNotificationsEnabled", store: .app) private var summaryNotificationsEnabled = false
    @AppStorage("aiEndpoint", store: .app) private var aiEndpoint = ""
    @AppStorage("aiModel", store: .app) private var aiModel = ""
    @AppStorage("summaryNotificationPrompt", store: .app) private var summaryNotificationPrompt = AppStorageDefaults.summaryNotificationPrompt
    @AppStorage("summaryNotificationTime", store: .app) private var summaryNotificationTime: Double = AppStorageDefaults.summaryNotificationTime
    @AppStorage("lastDailySummaryNotification", store: .app) private var lastDailySummaryNotification: Double = 0
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application launching")
        
        // Initialize all services with proper dependency injection
        initializeServices()
        
        // Start services in correct order
        menuBarManager?.setupMenuBar()
        trackingService?.startTracking()
        notificationService?.setupNotifications()
        notificationService?.startNotificationScheduler()
        
        // Start background update checking
        Task {
            await startUpdateScheduler()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application terminating")
        
        // Save any pending usage data before termination
        let semaphore = DispatchSemaphore(value: 0)
        
        Task { @MainActor in
            await sessionPersistenceService?.saveAllActiveSessions()
            semaphore.signal()
        }
        
        // Wait for save to complete with 2-second timeout to avoid hanging
        let runLoop = RunLoop.current
        let timeout = Date(timeIntervalSinceNow: 2.0)
        
        while semaphore.wait(timeout: .now() + 0.1) == .timedOut && Date() < timeout {
            runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
    }
    
    // MARK: - Service Initialization
    
    @MainActor private func initializeServices() {
        let modelContainer = DatabaseManager.shared.modelContainer
        
        // Initialize session persistence service first (no dependencies)
        sessionPersistenceService = SessionPersistenceService(modelContainer: modelContainer)
        
        // Initialize tracking service (depends on session persistence)
        trackingService = TrackingService(
            modelContainer: modelContainer,
            sessionPersistenceService: sessionPersistenceService!
        )
        
        // Initialize notification service (depends on app delegate for UI updates)
        notificationService = NotificationService(
            modelContainer: modelContainer,
            appDelegate: self
        )
        
        // Initialize menu bar manager (depends on app delegate for coordination)
        menuBarManager = MenuBarManager(
            modelContainer: modelContainer,
            appDelegate: self
        )
    }
    
    private func startUpdateScheduler() async {
        let logger = self.logger
        
        // Schedule periodic update checks every hour
        Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { _ in
            Task { @MainActor in
                do {
                    _ = try await UpdateManager.shared.checkForUpdates()
                } catch {
                    logger.error("Background update check failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Public Methods for Services
    
    /// Displays an error dialog to the user with the specified message and error details.
    /// Can be called from any service that needs to show user-facing errors.
    /// - Parameters:
    ///   - message: User-friendly description of what operation failed
    ///   - error: The underlying error that occurred
    func showError(_ message: String, error: Error) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "SimplyTrack Error"
            alert.informativeText = "\(message): \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Toggles the main popover visibility.
    /// Must be called on main actor since it modifies UI state.
    @MainActor func togglePopover() {
        menuBarManager?.togglePopover()
    }
    
    /// Resets the selected date to today.
    /// Used when opening popover from status bar or when user wants to return to current day.
    func resetToTodayView() {
        selectedDate = Date()
    }
}
