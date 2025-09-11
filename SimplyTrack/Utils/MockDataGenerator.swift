//
//  MockDataGenerator.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 03.09.2025.
//

import Foundation
import SwiftData
import os

/// Configuration parameters for mock data generation during development.
/// Controls timing, duration, and exclusion patterns for realistic test data.
struct MockDataConfig {
    /// Hour when work day begins (0-23)
    let startHour: Int
    /// Hour when work day ends (0-23)
    let endHour: Int
    /// Minimum continuous working time in seconds
    let minWorkingPeriod: TimeInterval
    /// Maximum continuous working time in seconds
    let maxWorkingPeriod: TimeInterval
    /// Minimum idle time between work periods in seconds
    let minIdlePeriod: TimeInterval
    /// Maximum idle time between work periods in seconds
    let maxIdlePeriod: TimeInterval
    /// Minimum individual session duration in seconds
    let minSessionDuration: TimeInterval
    /// Maximum individual session duration in seconds
    let maxSessionDuration: TimeInterval
    /// App bundle identifiers to exclude from mock data generation
    let excludedAppIdentifiers: Set<String>
    /// Website domains to exclude from mock data generation
    let excludedWebsites: Set<String>
    
    /// Default mock data configuration for standard development testing
    static let `default` = MockDataConfig(
        startHour: 9,
        endHour: 18,
        minWorkingPeriod: 30 * 60,        // 30 minutes
        maxWorkingPeriod: 2 * 3600,       // 2 hours
        minIdlePeriod: 5 * 60,            // 5 minutes
        maxIdlePeriod: 45 * 60,           // 45 minutes
        minSessionDuration: 2 * 60,       // 2 minutes
        maxSessionDuration: 25 * 60,      // 25 minutes
        excludedAppIdentifiers: [],
        excludedWebsites: []
    )
    
    /// Intense work pattern configuration for heavy usage testing
    static let intense = MockDataConfig(
        startHour: 8,
        endHour: 22,
        minWorkingPeriod: 45 * 60,        // 45 minutes
        maxWorkingPeriod: 3 * 3600,       // 3 hours
        minIdlePeriod: 2 * 60,            // 2 minutes
        maxIdlePeriod: 20 * 60,           // 20 minutes
        minSessionDuration: 5 * 60,       // 5 minutes
        maxSessionDuration: 45 * 60,      // 45 minutes
        excludedAppIdentifiers: [],
        excludedWebsites: []
    )
    
    /// Casual work pattern configuration for light usage testing
    static let casual = MockDataConfig(
        startHour: 10,
        endHour: 16,
        minWorkingPeriod: 15 * 60,        // 15 minutes
        maxWorkingPeriod: 1 * 3600,       // 1 hour
        minIdlePeriod: 10 * 60,           // 10 minutes
        maxIdlePeriod: 60 * 60,           // 1 hour
        minSessionDuration: 1 * 60,       // 1 minute
        maxSessionDuration: 15 * 60,      // 15 minutes
        excludedAppIdentifiers: [],
        excludedWebsites: []
    )
    
    // Builder-style configuration
    func withStartHour(_ hour: Int) -> MockDataConfig {
        MockDataConfig(
            startHour: hour,
            endHour: endHour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites
        )
    }
    
    func withEndHour(_ hour: Int) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: hour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites
        )
    }
    
    func withWorkingPeriod(min: TimeInterval, max: TimeInterval) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: endHour,
            minWorkingPeriod: min,
            maxWorkingPeriod: max,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites
        )
    }
    
    func withWorkingMinutes(min: Int, max: Int) -> MockDataConfig {
        withWorkingPeriod(min: TimeInterval(min * 60), max: TimeInterval(max * 60))
    }
    
    func withIdlePeriod(min: TimeInterval, max: TimeInterval) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: endHour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: min,
            maxIdlePeriod: max,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites
        )
    }
    
    func withIdleMinutes(min: Int, max: Int) -> MockDataConfig {
        withIdlePeriod(min: TimeInterval(min * 60), max: TimeInterval(max * 60))
    }
    
    func withSessionDuration(min: TimeInterval, max: TimeInterval) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: endHour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: min,
            maxSessionDuration: max,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites
        )
    }
    
    func withSessionMinutes(min: Int, max: Int) -> MockDataConfig {
        withSessionDuration(min: TimeInterval(min * 60), max: TimeInterval(max * 60))
    }
    
    func excludingApps(_ appIdentifiers: Set<String>) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: endHour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers.union(appIdentifiers),
            excludedWebsites: excludedWebsites
        )
    }
    
    func excludingApps(_ appIdentifiers: String...) -> MockDataConfig {
        excludingApps(Set(appIdentifiers))
    }
    
    func excludingWebsites(_ websites: Set<String>) -> MockDataConfig {
        MockDataConfig(
            startHour: startHour,
            endHour: endHour,
            minWorkingPeriod: minWorkingPeriod,
            maxWorkingPeriod: maxWorkingPeriod,
            minIdlePeriod: minIdlePeriod,
            maxIdlePeriod: maxIdlePeriod,
            minSessionDuration: minSessionDuration,
            maxSessionDuration: maxSessionDuration,
            excludedAppIdentifiers: excludedAppIdentifiers,
            excludedWebsites: excludedWebsites.union(websites)
        )
    }
    
    func excludingWebsites(_ websites: String...) -> MockDataConfig {
        excludingWebsites(Set(websites))
    }
}

/// Development utility for generating realistic mock usage data for testing.
/// Creates app and website usage sessions with configurable patterns and timing.
/// Used during development to test UI, analytics, and data processing features.
class MockDataGenerator {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MockDataGenerator")
    
    /// Generates mock usage data for a specific date using configurable patterns
    /// - Parameters:
    ///   - date: Target date to generate data for
    ///   - modelContext: SwiftData context for database operations
    ///   - config: Configuration controlling generation patterns
    ///   - sampleFromDate: Date to sample real session patterns from
    static func populateWithMockData(for date: Date, modelContext: ModelContext, config: MockDataConfig = .default, sampleFromDate: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Skip generating data if this is the sample date itself
        if calendar.isDate(sampleFromDate, inSameDayAs: date) {
            return
        }
        
        do {
            try modelContext.transaction {
                // Clear existing data for this date
                clearDataForDate(date, modelContext: modelContext)
                
                // Generate realistic usage patterns based on sample data
                generateDataFromSample(for: startOfDay, sampleDate: sampleFromDate, config: config, modelContext: modelContext)
            }
        } catch {
            logger.error("Error populating mock data: \(error.localizedDescription)")
        }
    }
    
    private static func clearDataForDate(_ date: Date, modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            let descriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfDay && session.startTime < endOfDay
                }
            )
            let existingSessions = try modelContext.fetch(descriptor)
            for session in existingSessions {
                modelContext.delete(session)
            }
        } catch {
            logger.error("Error clearing existing data: \(error.localizedDescription)")
        }
    }
    
    
    private static func generateDataFromSample(for startDate: Date, sampleDate: Date, config: MockDataConfig, modelContext: ModelContext) {
        let calendar = Calendar.current
        let sampleStartOfDay = calendar.startOfDay(for: sampleDate)
        let sampleEndOfDay = calendar.date(byAdding: .day, value: 1, to: sampleStartOfDay)!
        
        // Fetch real data from the sample date
        do {
            let descriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= sampleStartOfDay && session.startTime < sampleEndOfDay
                },
                sortBy: [SortDescriptor(\.startTime)]
            )
            let sampleSessions = try modelContext.fetch(descriptor)
            
            if sampleSessions.isEmpty {
                // No sample data available, skip generation
                return
            }
            
            // Extract unique apps and websites from sample data
            let uniqueApps = Array(sampleSessions.filter { $0.type == "app" }
                .reduce(into: [String: String]()) { dict, session in
                    dict[session.identifier] = session.name
                }
                .map { ($0.key, $0.value) })
            
            let uniqueWebsites = Array(sampleSessions.filter { $0.type == "website" }
                .reduce(into: [String: String]()) { dict, session in
                    dict[session.identifier] = session.name
                }
                .map { ($0.key, $0.value) })
            
            // Generate new sessions using the sample data as basis
            generateSessionsFromSample(
                for: startDate,
                config: config,
                sampleApps: uniqueApps,
                sampleWebsites: uniqueWebsites,
                modelContext: modelContext
            )
            
        } catch {
            logger.error("Error fetching sample data: \(error.localizedDescription)")
            // No fallback, skip generation if sample data can't be fetched
        }
    }
    
    private static func generateSessionsFromSample(
        for startDate: Date,
        config: MockDataConfig,
        sampleApps: [(String, String)],
        sampleWebsites: [(String, String)],
        modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        let startTime = calendar.date(byAdding: .hour, value: config.startHour, to: startDate)!
        let endTime = calendar.date(byAdding: .hour, value: config.endHour, to: startDate)!
        
        var currentTime = startTime
        
        // Generate alternating working and idle periods (same as original pattern)
        while currentTime < endTime {
            // Generate a working period
            let workingPeriodDuration = TimeInterval.random(in: config.minWorkingPeriod...config.maxWorkingPeriod)
            let workingPeriodEnd = min(currentTime.addingTimeInterval(workingPeriodDuration), endTime)
            
            generateSessionsInPeriodFromSample(
                from: currentTime,
                to: workingPeriodEnd,
                config: config,
                sampleApps: sampleApps,
                sampleWebsites: sampleWebsites,
                modelContext: modelContext
            )
            
            currentTime = workingPeriodEnd
            
            // Add idle period (if not at end of day)
            if currentTime < endTime {
                let idlePeriodDuration = TimeInterval.random(in: config.minIdlePeriod...config.maxIdlePeriod)
                currentTime = min(currentTime.addingTimeInterval(idlePeriodDuration), endTime)
            }
        }
    }
    
    private static func generateSessionsInPeriodFromSample(
        from startTime: Date,
        to endTime: Date,
        config: MockDataConfig,
        sampleApps: [(String, String)],
        sampleWebsites: [(String, String)],
        modelContext: ModelContext
    ) {
        var currentTime = startTime
        
        while currentTime < endTime {
            // Randomly choose between app and website session
            let isAppSession = Bool.random()
            let sessionDuration = TimeInterval.random(in: config.minSessionDuration...config.maxSessionDuration)
            let sessionEndTime = min(currentTime.addingTimeInterval(sessionDuration), endTime)
            
            if isAppSession && !sampleApps.isEmpty {
                let availableApps = sampleApps.filter { !config.excludedAppIdentifiers.contains($0.0) }
                guard !availableApps.isEmpty else {
                    // If all sample apps are excluded, try websites instead
                    if !sampleWebsites.isEmpty {
                        let availableWebsites = sampleWebsites.filter { !config.excludedWebsites.contains($0.0) }
                        if !availableWebsites.isEmpty {
                            let website = availableWebsites.randomElement()!
                            let session = UsageSession(
                                type: .website,
                                identifier: website.0,
                                name: website.1,
                                startTime: currentTime
                            )
                            session.endSession(at: sessionEndTime)
                            modelContext.insert(session)
                        }
                    }
                    currentTime = sessionEndTime.addingTimeInterval(TimeInterval.random(in: 30...180))
                    continue
                }
                
                let app = availableApps.randomElement()!
                let session = UsageSession(
                    type: .app,
                    identifier: app.0,
                    name: app.1,
                    startTime: currentTime
                )
                session.endSession(at: sessionEndTime)
                modelContext.insert(session)
            } else if !sampleWebsites.isEmpty {
                let availableWebsites = sampleWebsites.filter { !config.excludedWebsites.contains($0.0) }
                guard !availableWebsites.isEmpty else {
                    // If all sample websites are excluded, try apps instead
                    if !sampleApps.isEmpty {
                        let availableApps = sampleApps.filter { !config.excludedAppIdentifiers.contains($0.0) }
                        if !availableApps.isEmpty {
                            let app = availableApps.randomElement()!
                            let session = UsageSession(
                                type: .app,
                                identifier: app.0,
                                name: app.1,
                                startTime: currentTime
                            )
                            session.endSession(at: sessionEndTime)
                            modelContext.insert(session)
                        }
                    }
                    currentTime = sessionEndTime.addingTimeInterval(TimeInterval.random(in: 30...180))
                    continue
                }
                
                let website = availableWebsites.randomElement()!
                let session = UsageSession(
                    type: .website,
                    identifier: website.0,
                    name: website.1,
                    startTime: currentTime
                )
                session.endSession(at: sessionEndTime)
                modelContext.insert(session)
            } else {
                // No sample data available, skip this session
                currentTime = sessionEndTime.addingTimeInterval(TimeInterval.random(in: 30...180))
                continue
            }
            
            // Small break between sessions (30 seconds to 3 minutes)
            let breakDuration = TimeInterval.random(in: 30...180)
            currentTime = sessionEndTime.addingTimeInterval(breakDuration)
        }
    }
    
}
