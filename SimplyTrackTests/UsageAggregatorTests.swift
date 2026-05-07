//
//  UsageAggregatorTests.swift
//  SimplyTrackTests
//
//  Created by Hermes Agent on 06.05.2026.
//

import Foundation
import SwiftData
import Testing
@testable import SimplyTrack

struct UsageAggregatorTests {

    @Test func rawSessionsClipsDurationsToRequestedRange() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rangeStart = try #require(makeDate("2026-05-06T09:00:00Z"))
        let rangeEnd = try #require(makeDate("2026-05-06T11:00:00Z"))

        insertSession(
            type: .app,
            identifier: "com.apple.Safari",
            name: "Safari",
            start: "2026-05-06T08:30:00Z",
            end: "2026-05-06T09:30:00Z",
            context: context
        )
        insertSession(
            type: .website,
            identifier: "github.com",
            name: "github.com",
            start: "2026-05-06T10:15:00Z",
            end: "2026-05-06T11:15:00Z",
            context: context
        )

        let sessions = try UsageAggregator.rawSessions(
            start: rangeStart,
            end: rangeEnd,
            typeFilter: "all",
            includeActive: false,
            modelContext: context
        )

        #expect(sessions.count == 2)
        #expect(sessions[0].name == "Safari")
        #expect(sessions[0].durationSeconds == 1800)
        #expect(sessions[1].name == "github.com")
        #expect(sessions[1].durationSeconds == 2700)
    }

    @Test func usageRangeGroupsByNameAndFiltersType() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rangeStart = try #require(makeDate("2026-05-06T09:00:00Z"))
        let rangeEnd = try #require(makeDate("2026-05-06T12:00:00Z"))

        insertSession(type: .app, identifier: "com.apple.Safari", name: "Safari", start: "2026-05-06T09:00:00Z", end: "2026-05-06T10:00:00Z", context: context)
        insertSession(type: .app, identifier: "com.apple.Safari", name: "Safari", start: "2026-05-06T10:30:00Z", end: "2026-05-06T11:00:00Z", context: context)
        insertSession(type: .website, identifier: "github.com", name: "github.com", start: "2026-05-06T09:00:00Z", end: "2026-05-06T10:00:00Z", context: context)

        let summary = try UsageAggregator.usageRange(
            start: rangeStart,
            end: rangeEnd,
            typeFilter: "app",
            groupBy: "name",
            includeActive: false,
            modelContext: context
        )

        #expect(summary.totalDurationSeconds == 5400)
        #expect(summary.items.count == 1)
        #expect(summary.items[0].name == "Safari")
        #expect(summary.items[0].durationSeconds == 5400)
        #expect(summary.items[0].sessionCount == 2)
    }

    @Test func hourlyTimelineSplitsSessionsAcrossHourBuckets() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let date = try #require(makeDate("2026-05-06T00:00:00Z"))

        insertSession(type: .app, identifier: "com.apple.dt.Xcode", name: "Xcode", start: "2026-05-06T09:30:00Z", end: "2026-05-06T10:30:00Z", context: context)

        let timeline = try UsageAggregator.hourlyTimeline(
            for: date,
            typeFilter: "app",
            modelContext: context,
            calendar: utcCalendar
        )

        let nonEmptyBuckets = timeline.buckets.filter { $0.totalDurationSeconds > 0 }
        #expect(nonEmptyBuckets.count == 2)
        #expect(nonEmptyBuckets[0].hour == 9)
        #expect(nonEmptyBuckets[0].totalDurationSeconds == 1800)
        #expect(nonEmptyBuckets[1].hour == 10)
        #expect(nonEmptyBuckets[1].totalDurationSeconds == 1800)
    }

    @Test func ipcUsageToolsReturnJSONPayloads() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        insertSession(type: .app, identifier: "com.apple.dt.Xcode", name: "Xcode", start: "2026-05-06T09:30:00Z", end: "2026-05-06T10:30:00Z", context: context)
        insertSession(type: .website, identifier: "github.com", name: "github.com", start: "2026-05-06T10:00:00Z", end: "2026-05-06T11:00:00Z", context: context)
        try context.save()

        let service = IPCService(modelContainer: container)
        let rangeRequest = UsageRangeRequest(
            startTime: "2026-05-06T09:00:00Z",
            endTime: "2026-05-06T12:00:00Z",
            typeFilter: "all",
            groupBy: "name",
            includeActive: true
        )

        let usageRangeJSON = try await callService { service.getUsageRange(request: rangeRequest, completion: $0) }
        #expect(usageRangeJSON.contains("totalDurationSeconds"))
        #expect(usageRangeJSON.contains("Xcode"))

        let rawSessionsJSON = try await callService { service.getRawSessions(request: rangeRequest, completion: $0) }
        #expect(rawSessionsJSON.contains("github.com"))
        #expect(rawSessionsJSON.contains("durationSeconds"))

        let timelineJSON = try await callService { service.getHourlyTimeline(request: UsageTimelineRequest(dateString: "2026-05-06", typeFilter: "all"), completion: $0) }
        #expect(timelineJSON.contains("buckets"))

        let dailySummaryJSON = try await callService { service.getDailySummary(request: UsageDailySummaryRequest(dateString: "2026-05-06", typeFilter: "all", limit: 5), completion: $0) }
        #expect(dailySummaryJSON.contains("sessionCount"))
    }

    private func callService(_ body: (@escaping (String?, Error?) -> Void) -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            body { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result ?? "")
                }
            }
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([UsageSession.self, Icon.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func insertSession(type: UsageType, identifier: String, name: String, start: String, end: String, context: ModelContext) {
        let session = UsageSession(type: type, identifier: identifier, name: name, startTime: makeDate(start)!)
        session.endSession(at: makeDate(end)!)
        context.insert(session)
    }

    private func makeDate(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
