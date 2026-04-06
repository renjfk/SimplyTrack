//
//  SessionPersistenceService.swift
//  SimplyTrack
//
//  Handles batch session saving, icon storage, and database transactions
//

import Foundation
import SwiftData
import os

/// Service responsible for persisting usage sessions and icons using batch operations.
/// Implements atomic saves and intelligent icon caching to optimize database performance.
/// All operations are queued and executed in batches to minimize database transactions.
@MainActor
class SessionPersistenceService {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SessionPersistenceService")

    private let modelContainer: ModelContainer

    // MARK: - Batch Operation Queues

    private var pendingSessions: [UsageSession] = []

    private var pendingIcons: [(identifier: String, iconData: Data)] = []

    /// Maximum number of retry attempts before dropping failed items
    private static let maxRetryAttempts = 3
    /// Tracks retry count to prevent unbounded re-queuing on persistent DB failure
    private var retryCount = 0

    // MARK: - In-memory Icon Staleness Cache

    /// Caches known-fresh icon identifiers to avoid querying the database every second.
    /// Entries are identifiers whose icons are known to exist and are not stale.
    /// Cleared periodically so stale icons are eventually re-checked.
    private var freshIconIdentifiers: Set<String> = []
    /// Timestamp of the last cache clear, used to periodically invalidate the staleness cache
    private var lastFreshIconCacheClear = Date()
    /// How often to clear the in-memory icon cache (1 hour)
    private static let freshIconCacheInterval: TimeInterval = 3600

    /// Initializes the persistence service with the required SwiftData container.
    /// - Parameter modelContainer: SwiftData container for database operations
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Public Interface

    /// Queues a usage session for batch saving.
    /// Session will be saved on the next atomic save operation.
    /// - Parameter session: The completed usage session to save
    func queueSession(_ session: UsageSession) {
        pendingSessions.append(session)
    }

    /// Queues icon data for batch saving if it needs updating.
    /// Uses a pure in-memory cache to avoid any database queries on the main thread.
    /// The actual DB staleness check happens in the background save transaction.
    /// - Parameters:
    ///   - identifier: Unique identifier for the icon (bundle ID or domain)
    ///   - iconData: PNG data of the icon
    func queueIconData(identifier: String, iconData: Data) {
        // Avoid duplicate queue entries for the same identifier
        guard !pendingIcons.contains(where: { $0.identifier == identifier }) else { return }

        // Periodically clear the freshness cache so stale icons are eventually re-checked
        let now = Date()
        if now.timeIntervalSince(lastFreshIconCacheClear) > Self.freshIconCacheInterval {
            freshIconIdentifiers.removeAll()
            lastFreshIconCacheClear = now
        }

        // Fast path: skip if we know this icon is fresh (not stale, exists in DB)
        guard !freshIconIdentifiers.contains(identifier) else { return }

        pendingIcons.append((identifier: identifier, iconData: iconData))
    }

    /// Performs an atomic save of all queued sessions and icons.
    /// Clears the queues and executes a single database transaction on a background context.
    /// Called automatically every 30 seconds by TrackingService.
    func performAtomicSave() async {
        // Capture current queue contents synchronously on main actor
        let sessionsToSave = pendingSessions
        let iconsToSave = pendingIcons
        pendingSessions.removeAll()
        pendingIcons.removeAll()

        // Execute save if we have data to persist
        if !sessionsToSave.isEmpty || !iconsToSave.isEmpty {
            await saveSessionsAndIcons(sessionsToSave, iconsToSave)
        }
    }

    /// Saves all pending data immediately.
    /// Used during app termination to ensure no data loss.
    func saveAllActiveSessions() async {
        await performAtomicSave()
    }

    // MARK: - Private Implementation

    private func saveSessionsAndIcons(_ sessions: [UsageSession], _ icons: [(identifier: String, iconData: Data)]) async {
        let container = modelContainer

        // Run DB transaction on a background context to avoid blocking the main thread.
        // The staleness check for icons also happens here instead of on the main thread.
        let savedIconIdentifiers: [String] = await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            context.autosaveEnabled = false

            do {
                // Insert all usage sessions
                for session in sessions {
                    context.insert(session)
                }

                // Filter icons that actually need updating (staleness check on background context)
                var updatedIdentifiers: [String] = []
                for iconInfo in icons {
                    guard Self.iconNeedsUpdate(identifier: iconInfo.identifier, context: context) else {
                        updatedIdentifiers.append(iconInfo.identifier)  // Still fresh, mark it
                        continue
                    }

                    let targetIdentifier = iconInfo.identifier
                    let descriptor = FetchDescriptor<Icon>(
                        predicate: #Predicate<Icon> { icon in
                            icon.identifier == targetIdentifier
                        }
                    )

                    let existingIcons = try context.fetch(descriptor)
                    if let existingIcon = existingIcons.first {
                        existingIcon.updateIcon(with: iconInfo.iconData)
                    } else {
                        let icon = Icon(identifier: iconInfo.identifier, iconData: iconInfo.iconData)
                        context.insert(icon)
                    }
                    updatedIdentifiers.append(iconInfo.identifier)
                }

                try context.save()
                return updatedIdentifiers
            } catch {
                return []
            }
        }.value

        if !savedIconIdentifiers.isEmpty || !sessions.isEmpty {
            logger.info("Successfully saved \(sessions.count) sessions and \(icons.count) icons")
            retryCount = 0

            // Mark all processed icons as fresh so we skip them on subsequent ticks
            for identifier in savedIconIdentifiers {
                freshIconIdentifiers.insert(identifier)
            }
        } else if !sessions.isEmpty || !icons.isEmpty {
            let totalItems = sessions.count + icons.count
            logger.error("Failed to save \(totalItems) items")

            // Re-queue failed items with a retry limit to prevent unbounded growth
            retryCount += 1
            if retryCount <= Self.maxRetryAttempts {
                pendingSessions.append(contentsOf: sessions)
                pendingIcons.append(contentsOf: icons)
                logger.warning("Re-queued items for retry (\(self.retryCount)/\(Self.maxRetryAttempts))")
            } else {
                logger.error("Dropping \(totalItems) items after \(Self.maxRetryAttempts) failed retries")
                retryCount = 0
            }
        }
    }

    /// Checks whether an icon needs updating on a background context during the save transaction.
    /// Returns true if the icon is missing, has no data, or is stale (older than a week).
    private static func iconNeedsUpdate(identifier: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Icon>(
            predicate: #Predicate<Icon> { icon in
                icon.identifier == identifier
            }
        )

        do {
            let existingIcons = try context.fetch(descriptor)
            if let existingIcon = existingIcons.first {
                return existingIcon.needsUpdate || existingIcon.iconData == nil
            }
            return true
        } catch {
            return true
        }
    }
}
