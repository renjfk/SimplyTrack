//
//  CSVExportServiceTests.swift
//  SimplyTrackTests
//
//  Created by Soner Köksal on 06.05.2026.
//

import Foundation
import SwiftData
import Testing

@testable import SimplyTrack

struct CSVExportServiceTests {

    @Test func csvStringIncludesHeadersAndEscapesValues() {
        let row = CSVExportService.Row(
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 65),
            category: "website",
            name: "Example, \"Docs\"",
            identifier: "example.com",
            duration: 65
        )

        let csv = CSVExportService.csvString(for: [row])

        #expect(csv.contains("start_time,end_time,category,name,identifier,duration_seconds,duration"))
        #expect(csv.contains("website,\"Example, \"\"Docs\"\"\",example.com,65,1m 5s"))
    }

    @Test func rowsFiltersByExportPeriodAndExcludesActiveSessions() throws {
        let container = try ModelContainer(for: UsageSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let exportDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 10)))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: exportDate))

        let included = UsageSession(type: .app, identifier: "com.example.app", name: "Example", startTime: exportDate)
        included.endSession(at: exportDate.addingTimeInterval(60))
        context.insert(included)

        let active = UsageSession(type: .website, identifier: "example.com", name: "Example", startTime: exportDate.addingTimeInterval(120))
        context.insert(active)

        let excludedDay = UsageSession(type: .app, identifier: "com.example.next", name: "Next", startTime: nextDay)
        excludedDay.endSession(at: nextDay.addingTimeInterval(60))
        context.insert(excludedDay)

        let dayRows = try CSVExportService.rows(for: exportDate, period: .day, modelContext: context)
        let weekRows = try CSVExportService.rows(for: exportDate, period: .week, modelContext: context)

        #expect(dayRows.map(\.identifier) == ["com.example.app"])
        #expect(weekRows.map(\.identifier).contains("com.example.app"))
        #expect(!weekRows.map(\.identifier).contains("example.com"))
    }
}
