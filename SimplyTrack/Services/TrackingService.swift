//
//  TrackingService.swift
//  SimplyTrack
//
//  Handles app and website usage tracking, idle detection, and session management
//

import AppKit
import CoreGraphics
import Foundation
import SwiftData
import os

/// Core service responsible for tracking app and website usage patterns.
/// Monitors foreground applications, detects website usage through browser integration,
/// handles idle detection, and manages active usage sessions.
@MainActor
class TrackingService {

    /// Interval for persisting usage data to database and cache expiry
    static let dataPersistenceInterval: TimeInterval = 30.0

    /// Bundle identifiers of system UI that should be excluded from tracking.
    private static let excludedBundleIds: Set<String> = [
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.Spotlight",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
    ]

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TrackingService")

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    private let sessionPersistenceService: SessionPersistenceService
    private let webTrackingService = WebTrackingService()
    private let windowDetectionService = WindowDetectionService()

    // MARK: - Tracking State

    private var isTracking = false
    private var currentApp: NSRunningApplication?

    // MARK: - Active Sessions

    private var currentAppSession: UsageSession?
    private var currentWebsiteSession: UsageSession?
    private var isWebsitePollInFlight = false
    private var needsWebsitePollAfterCurrent = false
    private var websitePollStartedAt: Date?
    private var consecutiveWebsitePollFailures = 0
    private var lastSuccessfulWebsitePollAt: Date?
    private var activeWebsitePollTasks = 0
    private var websitePollGeneration = 0
    private var websitePollCooldownUntil: Date?
    private var websiteIconFetchesInFlight: Set<String> = []

    private static let websitePollGraceInterval: TimeInterval = 8.0
    private static let websitePollStaleInterval: TimeInterval = 10.0
    private static let websitePollCooldownInterval: TimeInterval = 5.0
    private static let websitePollFailureThreshold = 3
    private static let maxActiveWebsitePollTasks = 2

    // MARK: - Icon Cache

    /// Caches extracted PNG icon data keyed by bundle ID to avoid re-converting every second.
    /// Icons rarely change, so this cache is never cleared during the app lifecycle.
    private var appIconCache: [String: Data] = [:]

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
            let name = frontmostApp.localizedName
        {

            // Check if a floating/overlay window from another app is actually on top.
            // This handles apps running in always-on-top mode (e.g., Ghostty quick terminal,
            // 1Password Quick Access) that don't become the frontmost app.
            let activeBundleId: String
            let activeName: String
            let activeApp: NSRunningApplication
            let activitySource: String

            if let floatingWindow = windowDetectionService.detectTopmostFloatingWindow(frontmostBundleId: bundleId) {
                activeBundleId = floatingWindow.bundleIdentifier
                activeName = floatingWindow.name
                activeApp = floatingWindow.app
                activitySource = "floating_overlay"
            } else {
                activeBundleId = bundleId
                activeName = name
                activeApp = frontmostApp
                activitySource = "frontmost_application"
            }

            // Skip system UI that shouldn't be tracked (Dock, Spotlight, Control Center, etc.)
            if Self.excludedBundleIds.contains(activeBundleId) {
                // Loginwindow means user is at lock screen — end all active sessions
                if activeBundleId == "com.apple.loginwindow" {
                    await endAllActiveSessions()
                }
                return
            }

            // Extract and queue app icon for batch saving (cached to avoid PNG conversion every second)
            if let iconData = appIconCache[activeBundleId] {
                sessionPersistenceService.queueIconData(identifier: activeBundleId, iconData: iconData)
            } else if let iconData = IconUtils.getAppIconAsPNG(for: activeApp) {
                appIconCache[activeBundleId] = iconData
                sessionPersistenceService.queueIconData(identifier: activeBundleId, iconData: iconData)
            }

            // Update or create app usage session
            logActiveAppChangeIfNeeded(identifier: activeBundleId, name: activeName, source: activitySource)
            updateAppSession(identifier: activeBundleId, name: activeName, now: now)
        }

        scheduleWebsitePoll(now: now)
    }

    private func scheduleWebsitePoll(now: Date) {
        if let websitePollCooldownUntil, now < websitePollCooldownUntil {
            maybeEndWebsiteSessionAfterGrace(now: now)
            return
        }

        if isWebsitePollInFlight {
            needsWebsitePollAfterCurrent = true
            maybeHandleStaleWebsitePoll(now: now)
            return
        }

        guard activeWebsitePollTasks < Self.maxActiveWebsitePollTasks else {
            maybeEndWebsiteSessionAfterGrace(now: now)
            return
        }

        isWebsitePollInFlight = true
        websitePollStartedAt = now
        activeWebsitePollTasks += 1
        websitePollGeneration += 1
        let pollGeneration = websitePollGeneration

        Task {
            let websiteInfo = webTrackingService.getCurrentWebsiteInfo()
            await MainActor.run {
                self.finishWebsitePoll(websiteInfo: websiteInfo, generation: pollGeneration, now: Date())
            }
        }
    }

    private func finishWebsitePoll(websiteInfo: (domain: String, url: String)?, generation: Int, now: Date) {
        activeWebsitePollTasks = max(0, activeWebsitePollTasks - 1)
        guard generation == websitePollGeneration else { return }

        isWebsitePollInFlight = false
        websitePollStartedAt = nil

        if let websiteInfo {
            consecutiveWebsitePollFailures = 0
            lastSuccessfulWebsitePollAt = now

            updateWebsiteSession(
                identifier: websiteInfo.domain,
                name: websiteInfo.domain,
                now: now
            )
            scheduleWebsiteIconFetch(domain: websiteInfo.domain, sourceURL: websiteInfo.url)
        } else {
            consecutiveWebsitePollFailures += 1
            maybeEndWebsiteSessionAfterGrace(now: now)
        }

        if needsWebsitePollAfterCurrent {
            needsWebsitePollAfterCurrent = false
            scheduleWebsitePoll(now: now)
        }
    }

    private func maybeHandleStaleWebsitePoll(now: Date) {
        guard let startedAt = websitePollStartedAt else { return }
        guard now.timeIntervalSince(startedAt) >= Self.websitePollStaleInterval else { return }

        logger.warning("Website poll stale; entering cooldown before recovery")
        isWebsitePollInFlight = false
        websitePollStartedAt = nil
        needsWebsitePollAfterCurrent = false
        consecutiveWebsitePollFailures += 1
        websitePollGeneration += 1
        websitePollCooldownUntil = now.addingTimeInterval(Self.websitePollCooldownInterval)
        maybeEndWebsiteSessionAfterGrace(now: now)
    }

    private func scheduleWebsiteIconFetch(domain: String, sourceURL: String) {
        guard !websiteIconFetchesInFlight.contains(domain) else { return }

        websiteIconFetchesInFlight.insert(domain)
        Task {
            let iconData = await webTrackingService.getFaviconData(for: domain, sourceURL: sourceURL)
            await MainActor.run {
                self.websiteIconFetchesInFlight.remove(domain)
                if let iconData {
                    self.sessionPersistenceService.queueIconData(identifier: domain, iconData: iconData)
                }
            }
        }
    }

    private func maybeEndWebsiteSessionAfterGrace(now: Date) {
        if consecutiveWebsitePollFailures >= Self.websitePollFailureThreshold {
            endWebsiteSession()
            return
        }

        guard let lastSuccessfulWebsitePollAt else {
            endWebsiteSession()
            return
        }

        if now.timeIntervalSince(lastSuccessfulWebsitePollAt) >= Self.websitePollGraceInterval {
            endWebsiteSession()
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

    private func logActiveAppChangeIfNeeded(identifier: String, name: String, source: String) {
        guard currentAppSession?.identifier != identifier else { return }

        logger.log(
            "activity_tracking decision=active_app_changed source=\(source, privacy: .public) bundle=\(identifier, privacy: .public) name=\(name, privacy: .public)"
        )
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
        invalidateCurrentWebsitePoll()

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

    private func invalidateCurrentWebsitePoll() {
        websitePollGeneration += 1
        isWebsitePollInFlight = false
        needsWebsitePollAfterCurrent = false
        websitePollStartedAt = nil
        websitePollCooldownUntil = nil
        consecutiveWebsitePollFailures = 0
        lastSuccessfulWebsitePollAt = nil
    }

    // MARK: - Idle Detection

    private func getSystemIdleTime() -> TimeInterval {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        return TimeInterval(idleTime)
    }
}
