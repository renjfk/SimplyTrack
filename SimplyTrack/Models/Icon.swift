//
//  Icon.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import Foundation
import SwiftData

/// SwiftData model for caching app and website icons.
/// Stores icon data with refresh tracking to minimize unnecessary downloads.
/// Used by TrackingService and SessionPersistenceService for icon management.
@Model
class Icon {
    /// Unique identifier for this icon (bundle ID for apps, domain for websites)
    @Attribute(.unique) var identifier: String
    /// PNG image data for the cached icon
    var iconData: Data?
    /// Timestamp when this icon was last refreshed
    var lastUpdated: Date

    /// Creates a new icon cache entry.
    /// - Parameters:
    ///   - identifier: Bundle ID for apps or domain for websites
    ///   - iconData: PNG data for the icon, nil if not available
    init(identifier: String, iconData: Data?) {
        self.identifier = identifier
        self.iconData = iconData
        self.lastUpdated = Date()
    }

    /// Determines if this cached icon should be refreshed.
    /// Icons are considered stale after one week.
    var needsUpdate: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return lastUpdated < oneWeekAgo
    }

    /// Updates the cached icon with new data and refreshes the timestamp.
    /// - Parameter newData: New PNG icon data to store
    func updateIcon(with newData: Data?) {
        self.iconData = newData
        self.lastUpdated = Date()
    }
}
