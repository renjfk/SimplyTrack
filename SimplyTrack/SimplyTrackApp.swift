//
//  SimplyTrackApp.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import SwiftUI
import AppKit
import SwiftData
import CoreGraphics
import ServiceManagement
import UserNotifications

@main
struct SimplyTrackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .modelContainer(DatabaseManager.shared.modelContainer)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var trackingTimer: Timer?
    private var saveTimer: Timer?
    private var currentApp: NSRunningApplication?
    private var isTracking = false
    private var modelContainer: ModelContainer?
    
    @Published var notificationPermissionDenied = false
    
    // Session tracking
    private var currentAppSession: UsageSession?
    private var currentWebsiteSession: UsageSession?
    
    // Batch operations for atomic saves
    @MainActor private var pendingSessions: [UsageSession] = []
    @MainActor private var pendingIcons: [(identifier: String, iconData: Data)] = []
    
    // Idle detection
    private var lastActivityTime: Date = Date()
    private let idleThreshold: TimeInterval = 300 // 5 minutes in seconds
    
    private func getSystemIdleTime() -> TimeInterval {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        return TimeInterval(idleTime)
    }
    
    private func showError(_ message: String, error: Error) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "SimplyTrack Error"
            alert.informativeText = "\(message): \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupTracking()
        setupNotifications()
        
        Task {
            await performInitialUpdateCheck()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Use RunLoop to run the async task synchronously
        let semaphore = DispatchSemaphore(value: 0)
        
        Task { @MainActor in
            await self.saveAllActiveSessions()
            semaphore.signal()
        }
        
        // Keep running the run loop until task completes
        let runLoop = RunLoop.current
        let timeout = Date(timeIntervalSinceNow: 2.0)
        
        while semaphore.wait(timeout: .now() + 0.1) == .timedOut && Date() < timeout {
            runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
    }
    
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            if let svgData = loadSVGIcon() {
                statusButton.image = NSImage(data: svgData)
            } else {
                statusButton.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "SimplyTrack")
            }
            
            #if DEBUG
            statusButton.toolTip = "SimplyTrack (Debug Mode)"
            #else
            statusButton.toolTip = "SimplyTrack"
            #endif
            
            statusButton.action = #selector(togglePopover)
            statusButton.target = self
        }
        
        Task { @MainActor in
            setupPopover()
        }
    }
    
    @MainActor
    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 600)
        popover?.behavior = .transient
        
        modelContainer = DatabaseManager.shared.modelContainer
        popover?.contentViewController = NSHostingController(
            rootView: ContentView()
                .modelContainer(modelContainer!)
                .environmentObject(self)
        )
        popover?.delegate = self
    }
    
    func setupTracking() {
        modelContainer = DatabaseManager.shared.modelContainer
        startTracking()
    }
    
    private func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            self.handleAppChange(notification)
        }
        
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                await self.updateCurrentActivity()
            }
        }
        
        // Save sessions atomically every 30 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await self.performAtomicSave()
            }
        }
    }
    
    private func handleAppChange(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        currentApp = app
    }
    
    @MainActor private func updateCurrentActivity() async {
        let now = Date()
        let systemIdleTime = getSystemIdleTime()
        
        // Check if user is idle (inactive for more than 5 minutes)
        if systemIdleTime >= idleThreshold {
            // End any active sessions when user goes idle
            await endAllActiveSessions()
            return
        }
        
        // Update last activity time since user is active
        lastActivityTime = now
        
        // Track app usage
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmostApp.bundleIdentifier,
           let name = frontmostApp.localizedName {
            
            // Check for loginwindow - treat as idle state
            if bundleId.hasPrefix("com.apple.loginwindow") {
                await endAllActiveSessions()
                return
            }
            
            // Queue icon for batch saving
            queueIcon(identifier: bundleId, app: frontmostApp)
            
            updateAppSession(
                identifier: bundleId,
                name: name,
                now: now
            )
        }
        
        // Track website usage (non-blocking)
        Task {
            if let websiteData = await WebTracker.shared.getCurrentWebsiteData() {
                await MainActor.run {
                    // Queue icon if we have data
                    if let iconData = websiteData.iconData {
                        queueIconData(identifier: websiteData.domain, iconData: iconData)
                    }
                    
                    updateWebsiteSession(
                        identifier: websiteData.domain,
                        name: websiteData.domain,
                        now: now
                    )
                }
            } else {
                await MainActor.run {
                    // End website session if no website detected
                    endWebsiteSession()
                }
            }
        }
    }
    
    @MainActor private func updateAppSession(
        identifier: String,
        name: String,
        now: Date
    ) {
        // If current app session is different, end the old one and start new one
        if let currentSession = currentAppSession {
            if currentSession.identifier != identifier {
                currentSession.endSession(at: now)
                queueSession(currentSession)
                currentAppSession = UsageSession(type: .app, identifier: identifier, name: name, startTime: now)
            }
            // Same app, continue session (no action needed)
        } else {
            // No active app session, start new one
            currentAppSession = UsageSession(type: .app, identifier: identifier, name: name, startTime: now)
        }
    }
    
    @MainActor private func updateWebsiteSession(
        identifier: String,
        name: String,
        now: Date
    ) {
        // If current website session is different, end the old one and start new one
        if let currentSession = currentWebsiteSession {
            if currentSession.identifier != identifier {
                currentSession.endSession(at: now)
                queueSession(currentSession)
                currentWebsiteSession = UsageSession(type: .website, identifier: identifier, name: name, startTime: now)
            }
            // Same website, continue session (no action needed)
        } else {
            // No active website session, start new one
            currentWebsiteSession = UsageSession(type: .website, identifier: identifier, name: name, startTime: now)
        }
    }
    
    @MainActor private func endAllActiveSessions() async {
        let now = Date()
        if let appSession = currentAppSession {
            appSession.endSession(at: now)
            queueSession(appSession)
            currentAppSession = nil
        }
        if let websiteSession = currentWebsiteSession {
            websiteSession.endSession(at: now)
            queueSession(websiteSession)
            currentWebsiteSession = nil
        }
    }
    
    @MainActor private func endWebsiteSession() {
        guard let websiteSession = currentWebsiteSession else { return }
        websiteSession.endSession()
        queueSession(websiteSession)
        currentWebsiteSession = nil
    }
    
    // MARK: - Icon Management
    
    private func loadSVGIcon() -> Data? {
        guard let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "svg") else {
            return nil
        }
        
        guard var svgString = try? String(contentsOf: url) else {
            return nil
        }
        
        #if DEBUG
        // Make the entire icon yellow for debug builds
        svgString = svgString.replacingOccurrences(of: "stroke:#ffffff", with: "stroke:#ffff00")
        #endif
        
        return svgString.data(using: .utf8)
    }
    
    private func getAppIconAsPNG(for app: NSRunningApplication) -> Data? {
        guard let icon = app.icon else { return nil }
        
        // Create a new image with 32x32 size using modern API
        let targetSize = NSSize(width: 32, height: 32)
        let resizedImage = NSImage(size: targetSize, flipped: false) { rect in
            icon.draw(in: rect)
            return true
        }
        
        // Convert to PNG
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .png, properties: [:])
    }
    
    // MARK: - Batch Session Management
    
    @MainActor private func queueSession(_ session: UsageSession) {
        pendingSessions.append(session)
    }
    
    @MainActor private func queueIcon(identifier: String, app: NSRunningApplication) {
        // Check if icon needs updating (includes queue check)
        if shouldUpdateIcon(identifier: identifier) {
            if let iconData = getAppIconAsPNG(for: app) {
                pendingIcons.append((identifier: identifier, iconData: iconData))
            }
        }
    }
    
    @MainActor private func queueIconData(identifier: String, iconData: Data) {
        // Check if icon needs updating (includes queue check)
        if shouldUpdateIcon(identifier: identifier) {
            pendingIcons.append((identifier: identifier, iconData: iconData))
        }
    }
    
    @MainActor private func shouldUpdateIcon(identifier: String) -> Bool {
        // First check if already queued for update
        if pendingIcons.contains(where: { $0.identifier == identifier }) {
            return false
        }
        
        guard let container = modelContainer else { return true }
        
        do {
            let descriptor = FetchDescriptor<Icon>(
                predicate: #Predicate<Icon> { icon in
                    icon.identifier == identifier
                }
            )
            
            let existingIcons = try container.mainContext.fetch(descriptor)
            if let existingIcon = existingIcons.first {
                // Update if icon is older than a week or has no data
                return existingIcon.needsUpdate || existingIcon.iconData == nil
            } else {
                // No existing icon, need to create one
                return true
            }
        } catch {
            // On error, assume we should update
            return true
        }
    }
    
    @MainActor private func performAtomicSave() async {
        // Get sessions and icons to save synchronously on main actor
        let sessionsToSave = pendingSessions
        let iconsToSave = pendingIcons
        pendingSessions.removeAll()
        pendingIcons.removeAll()
        
        // Save sessions and icons in transaction
        if !sessionsToSave.isEmpty || !iconsToSave.isEmpty {
            await saveSessionsAndIcons(sessionsToSave, iconsToSave)
        }
    }
    
    @MainActor private func saveSessionsAndIcons(_ sessions: [UsageSession], _ icons: [(identifier: String, iconData: Data)]) async {
        guard let container = modelContainer else { return }
        
        do {
            try container.mainContext.transaction {
                // Insert all sessions in a single transaction
                for session in sessions {
                    container.mainContext.insert(session)
                }
                
                // Insert or update icons
                for iconInfo in icons {
                    let targetIdentifier = iconInfo.identifier
                    let descriptor = FetchDescriptor<Icon>(
                        predicate: #Predicate<Icon> { icon in
                            icon.identifier == targetIdentifier
                        }
                    )
                    
                    let existingIcons = try container.mainContext.fetch(descriptor)
                    if let existingIcon = existingIcons.first {
                        // Update existing icon with timestamp
                        existingIcon.updateIcon(with: iconInfo.iconData)
                    } else {
                        // Insert new icon
                        let icon = Icon(identifier: iconInfo.identifier, iconData: iconInfo.iconData)
                        container.mainContext.insert(icon)
                    }
                }
            }
        } catch {
            let totalItems = sessions.count + icons.count
            showError("Failed to save \(totalItems) items", error: error)
            
            // Re-queue failed items for retry on next save cycle
            pendingSessions.append(contentsOf: sessions)
            pendingIcons.append(contentsOf: icons)
        }
    }
    
    @MainActor private func saveAllActiveSessions() async {
        // End all active sessions and force immediate save before app terminates
        await endAllActiveSessions()
        
        await performAtomicSave()
    }
    
    @objc func togglePopover() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
            }
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showError("Failed to \(enabled ? "enable" : "disable") launch at login", error: error)
        }
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverWillShow(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("PopoverWillShow"), object: nil)
    }
    
    func popoverDidClose(_ notification: Notification) {
        NotificationCenter.default.post(name: NSNotification.Name("PopoverDidClose"), object: nil)
    }
    
    private func performInitialUpdateCheck() async {
        try? await Task.sleep(for: .seconds(5))
        
        do {
            let hasUpdate = try await UpdateManager.shared.checkForUpdates()
            if hasUpdate {
                showUpdateNotification()
            }
        } catch {
            // Silent fail for background update check - don't disturb user
            // Error will be shown if they manually check for updates
        }
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if !granted {
                    await MainActor.run {
                        self.notificationPermissionDenied = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.notificationPermissionDenied = true
                }
            }
        }
        
        let updateCategory = UNNotificationCategory(
            identifier: NotificationConstants.updateCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([updateCategory])
    }
    
    private func showUpdateNotification() {
        Task {
            do {
                _ = try await UpdateManager.shared.checkForUpdates(showNotification: true)
            } catch {
                // Silent fail for background update check
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            do {
                try await UpdateManager.shared.downloadAndOpenInstaller()
            } catch {
                await MainActor.run {
                    self.showError("Failed to download installer", error: error)
                }
            }
        default:
            break
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}
