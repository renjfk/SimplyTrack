//
//  TimeIntervalExtension.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import Foundation

/// Extension providing human-readable duration formatting for TimeInterval values.
/// Used throughout the app for displaying usage statistics and time durations.
extension TimeInterval {
    /// Formats TimeInterval as human-readable duration string.
    /// Returns format like "2h 30m", "45m 12s", or "8s" based on duration.
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
