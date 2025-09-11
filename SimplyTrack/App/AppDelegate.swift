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
    
    // MARK: - Release Notes Tracking
    
    @AppStorage("lastLaunchedVersion", store: .app) private var lastLaunchedVersion = ""
    @AppStorage("releaseNotesDisabled", store: .app) private var releaseNotesDisabled = false
    private var releaseNotesWindow: NSWindow?
    private var releaseNotesContent = ""
    private var releaseNotesVersionRange = ""
    
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
        
        // Check if app version changed and show release notes if needed
        Task {
            await checkAndShowReleaseNotes()
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
    
    // MARK: - Release Notes
    
    /// Checks if the app version has changed since last launch and shows release notes if needed.
    /// Fetches release notes from GitHub for all versions between last launch and current version.
    private func checkAndShowReleaseNotes() async {
        let currentVersion = await MainActor.run {
            UpdateManager.shared.getCurrentVersion()
        }
        
        // Skip if user has disabled release notes entirely
        guard !releaseNotesDisabled else {
            lastLaunchedVersion = currentVersion
            return
        }
        
        // Check if version has changed since last launch
        guard currentVersion != lastLaunchedVersion else {
            return // Same version, no need to show release notes
        }
        
        do {
            // Fetch release notes for versions between last and current  
            let releaseData = try await UpdateManager.shared.fetchReleaseNotesSince(
                lastVersion: lastLaunchedVersion,
                currentVersion: currentVersion
            )
            
            if let releaseData = releaseData, !releaseData.content.isEmpty {
                await MainActor.run {
                    self.releaseNotesContent = releaseData.content
                    self.releaseNotesVersionRange = releaseData.versionRange
                    self.showReleaseNotesWindow()
                }
            }
            
            // Update the last launched version
            lastLaunchedVersion = currentVersion
            
        } catch {
            // Silently fail if GitHub API is unavailable - don't show release notes
            logger.error("Failed to fetch release notes: \(error.localizedDescription)")
            
            // Still update the last launched version to avoid repeated attempts
            lastLaunchedVersion = currentVersion
        }
    }
    
    /// Shows the release notes in an independent window that can appear even when popover is hidden.
    @MainActor private func showReleaseNotesWindow() {
        // Get current version before creating the view
        let currentVersion = UpdateManager.shared.getCurrentVersion()
        logger.info("\(self.releaseNotesContent)")
        // Create the release notes view
        let releaseNotesView = ReleaseNotesWindowView(
            releaseNotesContent: releaseNotesContent,
            versionRange: releaseNotesVersionRange,
            onClose: { [weak self] neverShowAgain in
                if neverShowAgain {
                    // User never wants to see release notes, disable and update version
                    UserDefaults.app.set(true, forKey: "releaseNotesDisabled")
                }
                // Always update last launched version when user closes (viewed the notes)
                self?.lastLaunchedVersion = currentVersion
                self?.releaseNotesWindow?.close()
                self?.releaseNotesWindow = nil
            }
        )
        
        // Create the hosting controller
        let hostingController = NSHostingController(rootView: releaseNotesView)
        
        // Create the window
        releaseNotesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        releaseNotesWindow?.title = "What's New in SimplyTrack"
        releaseNotesWindow?.contentViewController = hostingController
        releaseNotesWindow?.isReleasedWhenClosed = false
        releaseNotesWindow?.level = .floating
        
        // Make the window visible first so it has proper frame
        releaseNotesWindow?.makeKeyAndOrderFront(nil)
        
        // Then center it after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            if let window = self?.releaseNotesWindow, let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = window.frame
                let x = screenFrame.origin.x + (screenFrame.size.width - windowFrame.size.width) / 2
                let y = screenFrame.origin.y + (screenFrame.size.height - windowFrame.size.height) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
}
