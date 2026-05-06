//
//  CSVExportServiceTests.swift
//  SimplyTrackTests
//
//  Created by Soner Köksal on 06.05.2026.
//

import Foundation
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
}
