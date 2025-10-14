//
//  UsageAggregator.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 09.09.2025.
//

import Foundation
import SwiftData

/// Utility for aggregating and formatting usage session data for AI summary generation.
/// Provides methods to extract top activities from database and format them for AI prompts.
/// Used by NotificationService to prepare usage data for daily summary notifications.
struct UsageAggregator {

    /// Aggregates usage data for a given date and returns top X percentage of activities
    /// - Parameters:
    ///   - date: The date to aggregate usage for
    ///   - type: Type of usage to include (.app or .website)
    ///   - topPercentage: Percentage of top activities to include (0.0 to 1.0)
    ///   - modelContext: SwiftData model context for database access
    /// - Returns: Formatted string like "Safari:3h45m|VSCode:2h30m|github.com:1h20m|Total:8h15m"
    static func aggregateUsage(for date: Date, type: UsageType, topPercentage: Double = 0.8, modelContext: ModelContext) throws -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch sessions for the given date and type
        let descriptor = FetchDescriptor<UsageSession>(
            predicate: #Predicate<UsageSession> { session in
                session.startTime >= startOfDay && session.startTime < endOfDay && session.endTime != nil && session.type == type.rawValue
            }
        )

        let sessions = try modelContext.fetch(descriptor)
        return aggregateAndFormat(sessions: sessions, topPercentage: topPercentage)
    }
    
    /// Aggregates idle time for a given date
    /// - Parameters:
    ///   - date: The date to aggregate idle time for
    ///   - modelContext: SwiftData model context for database access
    /// - Returns: Total idle time for the date
    static func aggregateIdleTime(for date: Date, modelContext: ModelContext) throws -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<UsageSession>(
            predicate: #Predicate<UsageSession> { session in
                session.startTime >= startOfDay && session.startTime < endOfDay && session.endTime != nil && session.type == "idle"
            }
        )

        let sessions = try modelContext.fetch(descriptor)
        return sessions.reduce(0) { $0 + $1.duration }
    }

    private static func aggregateAndFormat(sessions: [UsageSession], topPercentage: Double) -> String {
        var appUsage: [String: TimeInterval] = [:]
        var websiteUsage: [String: TimeInterval] = [:]

        // Aggregate usage by name
        for session in sessions {
            let duration = session.duration

            if session.type == UsageType.app.rawValue {
                appUsage[session.name] = (appUsage[session.name] ?? 0) + duration
            } else if session.type == UsageType.website.rawValue {
                websiteUsage[session.name] = (websiteUsage[session.name] ?? 0) + duration
            } else if session.type == UsageType.idle.rawValue {
                appUsage["Idle"] = (appUsage["Idle"] ?? 0) + duration
            }
        }

        // Combine all usage and sort by duration
        var allUsage: [(name: String, duration: TimeInterval)] = []
        allUsage.append(contentsOf: appUsage.map { (name: $0.key, duration: $0.value) })
        allUsage.append(contentsOf: websiteUsage.map { (name: $0.key, duration: $0.value) })

        // Sort by duration descending
        allUsage.sort { $0.duration > $1.duration }

        // Calculate total duration
        let totalDuration = allUsage.reduce(0) { $0 + $1.duration }

        // Get top activities based on duration percentage
        let targetDuration = totalDuration * topPercentage
        let topUsage = allUsage.reduce(into: (activities: [(name: String, duration: TimeInterval)](), accumulated: 0.0)) { result, usage in
            guard result.accumulated < targetDuration else { return }
            result.activities.append(usage)
            result.accumulated += usage.duration
        }.activities

        // Ensure we have at least one activity even if topPercentage is very small
        let finalTopUsage = topUsage.isEmpty && !allUsage.isEmpty ? [allUsage[0]] : topUsage

        // Format output
        var components: [String] = []

        for usage in finalTopUsage {
            let formatted = formatDuration(usage.duration)
            components.append("\(usage.name):\(formatted)")
        }

        // Add total
        let totalFormatted = formatDuration(totalDuration)
        components.append("Total:\(totalFormatted)")

        return components.joined(separator: "|")
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
