//
//  TrackingService.swift
//  SimplyTrack
//
//  Handles app and website usage tracking, idle detection, and session management
//

import Foundation
import AppKit
import SwiftData
import CoreGraphics
import os

/// Core service responsible for tracking app and website usage patterns.
/// Monitors foreground applications, detects website usage through browser integration,
/// handles idle detection, and manages active usage sessions.
@MainActor
class TrackingService {
    
    /// Interval for persisting usage data to database and cache expiry
    static let dataPersistenceInterval: TimeInterval = 30.0
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TrackingService")
    
    // MARK: - Dependencies
    
    private let modelContainer: ModelContainer
    private let sessionPersistenceService: SessionPersistenceService
    private let webTrackingService = WebTrackingService()
    
    // MARK: - Tracking State
    
    private var isTracking = false
    private var currentApp: NSRunningApplication?
    
    // MARK: - Active Sessions
    
    private var currentAppSession: UsageSession?
    private var currentWebsiteSession: UsageSession?
    
    // MARK: - Idle Detection
    
    private var lastActivityTime = Date()
    private let idleThreshold: TimeInterval = 300
    
    /// Initializes the tracking service with required dependencies.
    /// - Parameters:
    ///   - modelContainer: SwiftData container for database operations
    ///   - sessionPersistenceService: Service for persisting usage data
    init(modelContainer: ModelContainer, sessionPersistenceService: SessionPersistenceService) {
        self.modelContainer = modelContainer
        self.sessionPersistenceService = sessionPersistenceService
    }
    
    // MARK: - Public Interface
    
    /// Starts the tracking service and begins monitoring user activity.
    /// Sets up timers for activity monitoring and batch saving.
    /// Does nothing if tracking is already active.
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        logger.info("Starting tracking service")
        
        // Observe app changes from NSWorkspace
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                self.handleAppChange(notification)
            }
        }
        
        // Update activity every second to ensure accurate tracking
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                await self.updateCurrentActivity()
            }
        }
        
        // Save sessions every 30 seconds for data safety
        Timer.scheduledTimer(withTimeInterval: Self.dataPersistenceInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.sessionPersistenceService.performAtomicSave()
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func handleAppChange(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        currentApp = app
    }
    
    private func updateCurrentActivity() async {
        let now = Date()
        let systemIdleTime = getSystemIdleTime()
        
        // Check if user has been idle for more than threshold
        if systemIdleTime >= idleThreshold {
            await endAllActiveSessions()
            return
        }
        
        lastActivityTime = now
        
        // Track foreground application usage
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmostApp.bundleIdentifier,
           let name = frontmostApp.localizedName {
            
            // Special case: loginwindow indicates user is not actively using the system
            if bundleId.hasPrefix("com.apple.loginwindow") {
                await endAllActiveSessions()
                return
            }
            
            // Extract and queue app icon for batch saving
            if let iconData = IconUtils.getAppIconAsPNG(for: frontmostApp) {
                sessionPersistenceService.queueIconData(identifier: bundleId, iconData: iconData)
            }
            
            // Update or create app usage session
            updateAppSession(identifier: bundleId, name: name, now: now)
        }
        
        // Track website usage asynchronously to avoid blocking app tracking
        Task {
            if let websiteData = await webTrackingService.getCurrentWebsiteData() {
                await MainActor.run {
                    // Queue website favicon if available
                    if let iconData = websiteData.iconData {
                        sessionPersistenceService.queueIconData(
                            identifier: websiteData.domain,
                            iconData: iconData
                        )
                    }
                    
                    // Update or create website usage session
                    updateWebsiteSession(
                        identifier: websiteData.domain,
                        name: websiteData.domain,
                        now: now
                    )
                }
            } else {
                // No website detected, end current website session
                await MainActor.run {
                    endWebsiteSession()
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    private func updateAppSession(identifier: String, name: String, now: Date) {
        if let currentSession = currentAppSession {
            // If app changed, end current session and start new one
            if currentSession.identifier != identifier {
                currentSession.endSession(at: now)
                sessionPersistenceService.queueSession(currentSession)
                currentAppSession = UsageSession(type: .app, identifier: identifier, name: name, startTime: now)
            }
            // If same app, continue current session (no action needed)
        } else {
            // No active session, start new one
            currentAppSession = UsageSession(type: .app, identifier: identifier, name: name, startTime: now)
        }
    }
    
    private func updateWebsiteSession(identifier: String, name: String, now: Date) {
        if let currentSession = currentWebsiteSession {
            // If website changed, end current session and start new one
            if currentSession.identifier != identifier {
                currentSession.endSession(at: now)
                sessionPersistenceService.queueSession(currentSession)
                currentWebsiteSession = UsageSession(type: .website, identifier: identifier, name: name, startTime: now)
            }
            // If same website, continue current session (no action needed)
        } else {
            // No active session, start new one
            currentWebsiteSession = UsageSession(type: .website, identifier: identifier, name: name, startTime: now)
        }
    }
    
    private func endWebsiteSession() {
        guard let websiteSession = currentWebsiteSession else { return }
        websiteSession.endSession()
        sessionPersistenceService.queueSession(websiteSession)
        currentWebsiteSession = nil
    }
    
    /// Ends all currently active sessions (both app and website).
    /// Called when user goes idle or system enters inactive state.
    /// Public method that can be called by AppDelegate during app termination.
    func endAllActiveSessions() async {
        let now = Date()
        
        // End app session if active
        if let appSession = currentAppSession {
            appSession.endSession(at: now)
            sessionPersistenceService.queueSession(appSession)
            currentAppSession = nil
        }
        
        // End website session if active
        if let websiteSession = currentWebsiteSession {
            websiteSession.endSession(at: now)
            sessionPersistenceService.queueSession(websiteSession)
            currentWebsiteSession = nil
        }
    }
    
    // MARK: - Idle Detection
    
    private func getSystemIdleTime() -> TimeInterval {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        return TimeInterval(idleTime)
    }
}
