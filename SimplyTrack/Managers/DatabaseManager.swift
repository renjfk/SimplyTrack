//
//  DatabaseManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import Foundation
import SwiftData

/// Manages the SwiftData model container and database configuration for the application.
/// Provides environment separation with different database files for debug and release builds.
/// Serves as the central point for database access throughout the app.
class DatabaseManager {
    /// Shared singleton instance for database operations
    static let shared = DatabaseManager()

    private init() {}

    /// SwiftData model container configured for the current environment.
    /// Debug builds use a separate database file to avoid conflicts with release data.
    lazy var modelContainer: ModelContainer = {
        do {
            #if DEBUG
                // Debug builds use a separate database file in the same directory
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let debugURL = appSupport.appendingPathComponent("debug.store")
                let configuration = ModelConfiguration(
                    schema: Schema([UsageSession.self, Icon.self]),
                    url: debugURL
                )
                return try ModelContainer(for: UsageSession.self, Icon.self, configurations: configuration)
            #else
                // Release builds use SwiftData's default location
                return try ModelContainer(for: UsageSession.self, Icon.self)
            #endif
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()
}
