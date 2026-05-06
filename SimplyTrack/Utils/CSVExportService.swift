//
//  CSVExportService.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 06.05.2026.
//

import Foundation

/// Formats usage sessions as standards-compliant CSV export data.
struct CSVExportService {
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

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
