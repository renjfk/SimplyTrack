//
//  CSVExportService.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 06.05.2026.
//

import Foundation
import SwiftData

/// Formats usage sessions as standards-compliant CSV export data.
struct CSVExportService {
    enum Period: String {
        case day
        case week
    }

    /// Exportable usage row independent from SwiftData model state.
    struct Row {
        let startTime: Date
        let endTime: Date
        let category: String
        let name: String
        let identifier: String
        let duration: TimeInterval
    }

    static func csvString(for rows: [Row]) -> String {
        let headers = ["start_time", "end_time", "category", "name", "identifier", "duration_seconds", "duration"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let lines =
            [headers.joined(separator: ",")]
            + rows.map { row in
                [
                    formatter.string(from: row.startTime),
                    formatter.string(from: row.endTime),
                    row.category,
                    row.name,
                    row.identifier,
                    String(Int(row.duration.rounded())),
                    row.duration.formattedDuration,
                ]
                .map(escape)
                .joined(separator: ",")
            }

        return lines.joined(separator: "\n") + "\n"
    }

    static func csvString(for date: Date, period: Period, modelContext: ModelContext) throws -> String {
        let rows = try rows(for: date, period: period, modelContext: modelContext)
        return csvString(for: rows)
    }

    static func rows(for date: Date, period: Period, modelContext: ModelContext) throws -> [Row] {
        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date

        if period == .day {
            startDate = calendar.startOfDay(for: date)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        } else {
            startDate = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate)!
        }

        let descriptor = FetchDescriptor<UsageSession>(
            predicate: #Predicate<UsageSession> { session in
                session.startTime >= startDate && session.startTime < endDate && session.endTime != nil
            },
            sortBy: [
                SortDescriptor(\.startTime),
                SortDescriptor(\.type),
                SortDescriptor(\.name),
            ]
        )

        return try modelContext.fetch(descriptor).compactMap { session in
            guard let endTime = session.endTime else { return nil }

            return Row(
                startTime: session.startTime,
                endTime: endTime,
                category: session.type,
                name: session.name,
                identifier: session.identifier,
                duration: session.duration
            )
        }
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
