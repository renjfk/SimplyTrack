//
//  DatabaseManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import Foundation
import SwiftData

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private init() {}
    
    // Shared ModelContainer for the entire app
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
