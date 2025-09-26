//
//  UsageSession.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import Foundation
import SwiftData

/// SwiftData model representing a single usage session for an app or website.
/// Tracks the start and end times of user interactions with applications and websites.
/// Used for generating usage statistics, summaries, and time-tracking analytics.
@Model
class UsageSession {
    /// Unique identifier for this usage session
    @Attribute(.unique) var id: UUID = UUID()
    /// Type of usage being tracked ("app" or "website")
    var type: String
    /// Unique identifier for the tracked item (bundle ID for apps, domain for websites)
    var identifier: String
    /// Human-readable display name for the tracked item
    var name: String
    /// When this usage session began
    var startTime: Date
    /// When this usage session ended (nil for active sessions)
    var endTime: Date?

    /// Calculated duration of this usage session in seconds.
    /// Returns 0 for active sessions (endTime is nil).
    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }

    /// Creates a new usage session starting at the specified time.
    /// - Parameters:
    ///   - type: Whether this tracks an app or website
    ///   - identifier: Bundle ID for apps or domain for websites
    ///   - name: Display name for the tracked item
    ///   - startTime: When the session began (defaults to now)
    init(type: UsageType, identifier: String, name: String, startTime: Date = Date()) {
        self.id = UUID()
        self.type = type.rawValue
        self.identifier = identifier
        self.name = name
        self.startTime = startTime
        self.endTime = nil
    }

    /// Marks this usage session as ended at the specified time.
    /// - Parameter endTime: When the session ended (defaults to now)
    func endSession(at endTime: Date = Date()) {
        self.endTime = endTime
    }
}
