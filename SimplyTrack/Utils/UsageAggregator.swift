//
//  UsageAggregator.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 09.09.2025.
//

import Foundation
import SwiftData

/// A session returned through the app's local MCP/IPC usage tools.
struct UsageSessionSnapshot: Codable, Sendable {
    let type: String
    let identifier: String
    let name: String
    let startTime: Date
    let endTime: Date?
    let durationSeconds: Int
    let isActive: Bool
}

/// A grouped activity row returned through the app's local MCP/IPC usage tools.
struct UsageActivitySummary: Codable, Sendable {
    let key: String
    let type: String?
    let identifier: String?
    let name: String
    let durationSeconds: Int
    let sessionCount: Int
}

/// A range summary returned through the app's local MCP/IPC usage tools.
struct UsageRangeSummary: Codable, Sendable {
    let startTime: Date
    let endTime: Date
    let totalDurationSeconds: Int
    let sessionCount: Int
    let items: [UsageActivitySummary]
}

/// A single hour bucket returned through the app's local MCP/IPC usage tools.
struct UsageHourlyBucket: Codable, Sendable {
    let hour: Int
    let startTime: Date
    let endTime: Date
    let totalDurationSeconds: Int
    let items: [UsageActivitySummary]
}

/// A 24-hour timeline returned through the app's local MCP/IPC usage tools.
struct UsageHourlyTimeline: Codable, Sendable {
    let date: Date
    let totalDurationSeconds: Int
    let buckets: [UsageHourlyBucket]
}

/// Utility for aggregating and formatting usage session data for AI summary generation.
/// Provides methods to extract top activities from database and format them for AI prompts.
/// Used by NotificationService to prepare usage data for daily summary notifications and by MCP/IPC tools for direct querying.
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

    /// Returns raw session rows intersecting the requested range, clipped to the range boundaries.
    static func rawSessions(start: Date, end: Date, typeFilter: String = "all", includeActive: Bool = true, modelContext: ModelContext) throws -> [UsageSessionSnapshot] {
        let sessions = try querySessions(start: start, end: end, typeFilter: typeFilter, includeActive: includeActive, modelContext: modelContext)
        return sessions.map { session in
            let clippedEnd = min(session.endTime ?? end, end)
            let clippedStart = max(session.startTime, start)
            return UsageSessionSnapshot(
                type: session.type,
                identifier: session.identifier,
                name: session.name,
                startTime: clippedStart,
                endTime: session.endTime.map { min($0, end) },
                durationSeconds: max(0, Int(clippedEnd.timeIntervalSince(clippedStart))),
                isActive: session.endTime == nil
            )
        }
        .filter { $0.durationSeconds > 0 || $0.isActive }
        .sorted { $0.startTime < $1.startTime }
    }

    /// Returns usage grouped by session, name, identifier, type, or hour for a requested range.
    static func usageRange(
        start: Date,
        end: Date,
        typeFilter: String = "all",
        groupBy: String = "name",
        includeActive: Bool = true,
        modelContext: ModelContext
    ) throws -> UsageRangeSummary {
        let snapshots = try rawSessions(start: start, end: end, typeFilter: typeFilter, includeActive: includeActive, modelContext: modelContext)
        let items = summarize(snapshots: snapshots, groupBy: groupBy)
        return UsageRangeSummary(
            startTime: start,
            endTime: end,
            totalDurationSeconds: snapshots.reduce(0) { $0 + $1.durationSeconds },
            sessionCount: snapshots.count,
            items: items
        )
    }

    /// Returns one bucket per hour for the supplied day, splitting sessions across bucket boundaries.
    static func hourlyTimeline(
        for date: Date,
        typeFilter: String = "all",
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> UsageHourlyTimeline {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let snapshots = try rawSessions(start: dayStart, end: dayEnd, typeFilter: typeFilter, includeActive: true, modelContext: modelContext)

        let buckets = (0..<24).map { hour -> UsageHourlyBucket in
            let bucketStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let bucketEnd = calendar.date(byAdding: .hour, value: 1, to: bucketStart)!
            let bucketSnapshots = snapshots.compactMap { snapshot -> UsageSessionSnapshot? in
                let snapshotEnd = min(snapshot.endTime ?? bucketEnd, bucketEnd)
                let snapshotStart = max(snapshot.startTime, bucketStart)
                let duration = max(0, Int(snapshotEnd.timeIntervalSince(snapshotStart)))
                guard duration > 0 else { return nil }
                return UsageSessionSnapshot(
                    type: snapshot.type,
                    identifier: snapshot.identifier,
                    name: snapshot.name,
                    startTime: snapshotStart,
                    endTime: snapshot.endTime.map { min($0, bucketEnd) },
                    durationSeconds: duration,
                    isActive: snapshot.isActive
                )
            }

            return UsageHourlyBucket(
                hour: hour,
                startTime: bucketStart,
                endTime: bucketEnd,
                totalDurationSeconds: bucketSnapshots.reduce(0) { $0 + $1.durationSeconds },
                items: summarize(snapshots: bucketSnapshots, groupBy: "name")
            )
        }

        return UsageHourlyTimeline(
            date: dayStart,
            totalDurationSeconds: buckets.reduce(0) { $0 + $1.totalDurationSeconds },
            buckets: buckets
        )
    }

    private static func querySessions(start: Date, end: Date, typeFilter: String, includeActive: Bool, modelContext: ModelContext) throws -> [UsageSession] {
        let descriptor = FetchDescriptor<UsageSession>(
            predicate: #Predicate<UsageSession> { session in
                session.startTime < end
            },
            sortBy: [SortDescriptor(\UsageSession.startTime)]
        )
        let type = normalizedTypeFilter(typeFilter)

        return try modelContext.fetch(descriptor).filter { session in
            if let type, session.type != type.rawValue {
                return false
            }

            if !includeActive && session.endTime == nil {
                return false
            }

            let effectiveEnd = session.endTime ?? end
            return effectiveEnd > start && session.startTime < end
        }
    }

    private static func normalizedTypeFilter(_ typeFilter: String) -> UsageType? {
        switch typeFilter.lowercased() {
        case "app", "apps", UsageType.app.rawValue:
            return .app
        case "website", "websites", UsageType.website.rawValue:
            return .website
        default:
            return nil
        }
    }

    private static func summarize(snapshots: [UsageSessionSnapshot], groupBy: String) -> [UsageActivitySummary] {
        let grouped = Dictionary(grouping: snapshots) { snapshot -> String in
            switch groupBy.lowercased() {
            case "session":
                return "\(snapshot.type)|\(snapshot.identifier)|\(snapshot.name)|\(snapshot.startTime.timeIntervalSince1970)"
            case "identifier":
                return "\(snapshot.type)|\(snapshot.identifier)"
            case "type":
                return snapshot.type
            default:
                return "\(snapshot.type)|\(snapshot.name)"
            }
        }

        return grouped.map { key, snapshots in
            let first = snapshots[0]
            return UsageActivitySummary(
                key: key,
                type: groupBy.lowercased() == "type" ? first.type : first.type,
                identifier: groupBy.lowercased() == "name" ? nil : first.identifier,
                name: groupBy.lowercased() == "type" ? first.type : first.name,
                durationSeconds: snapshots.reduce(0) { $0 + $1.durationSeconds },
                sessionCount: snapshots.count
            )
        }
        .sorted {
            if $0.durationSeconds == $1.durationSeconds {
                return $0.name < $1.name
            }
            return $0.durationSeconds > $1.durationSeconds
        }
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
