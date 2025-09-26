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
    /// Performs intelligent caching to avoid unnecessary database writes.
    /// - Parameters:
    ///   - identifier: Unique identifier for the icon (bundle ID or domain)
    ///   - iconData: PNG data of the icon
    func queueIconData(identifier: String, iconData: Data) {
        if shouldUpdateIcon(identifier: identifier) {
            pendingIcons.append((identifier: identifier, iconData: iconData))
        }
    }

    /// Performs an atomic save of all queued sessions and icons.
    /// Clears the queues and executes a single database transaction.
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
        do {
            // Execute all operations in a single database transaction
            try modelContainer.mainContext.transaction {
                // Insert all usage sessions
                for session in sessions {
                    modelContainer.mainContext.insert(session)
                }

                // Process icon updates and insertions
                for iconInfo in icons {
                    let targetIdentifier = iconInfo.identifier
                    let descriptor = FetchDescriptor<Icon>(
                        predicate: #Predicate<Icon> { icon in
                            icon.identifier == targetIdentifier
                        }
                    )

                    let existingIcons = try modelContainer.mainContext.fetch(descriptor)
                    if let existingIcon = existingIcons.first {
                        // Update existing icon with new data and timestamp
                        existingIcon.updateIcon(with: iconInfo.iconData)
                    } else {
                        // Create new icon entry
                        let icon = Icon(identifier: iconInfo.identifier, iconData: iconInfo.iconData)
                        modelContainer.mainContext.insert(icon)
                    }
                }
            }

            logger.info("Successfully saved \(sessions.count) sessions and \(icons.count) icons")

        } catch {
            let totalItems = sessions.count + icons.count
            logger.error("Failed to save \(totalItems) items: \(error.localizedDescription)")

            // Re-queue failed items for automatic retry on next save cycle
            pendingSessions.append(contentsOf: sessions)
            pendingIcons.append(contentsOf: icons)
        }
    }

    private func shouldUpdateIcon(identifier: String) -> Bool {
        // Avoid duplicate queue entries for the same identifier
        if pendingIcons.contains(where: { $0.identifier == identifier }) {
            return false
        }

        do {
            let descriptor = FetchDescriptor<Icon>(
                predicate: #Predicate<Icon> { icon in
                    icon.identifier == identifier
                }
            )

            let existingIcons = try modelContainer.mainContext.fetch(descriptor)
            if let existingIcon = existingIcons.first {
                // Update if icon is stale (older than a week) or missing data
                return existingIcon.needsUpdate || existingIcon.iconData == nil
            } else {
                // No existing icon found, need to create one
                return true
            }
        } catch {
            // On database error, err on the side of updating to ensure we have icons
            return true
        }
    }
}
