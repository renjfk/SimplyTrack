//
//  IPCService.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation
import SwiftData
import os

/// IPC service implementation for communicating with CLI
class IPCService: NSObject, SimplyTrackIPCProtocol {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "IPCService")
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    func getUsageActivity(topPercentage: Double, dateString: String?, typeFilter: String, completion: @escaping (String?, Error?) -> Void) {
        do {
            let context = ModelContext(modelContainer)

            // Parse date or use today
            let targetDate: Date
            if let dateString = dateString {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                targetDate = formatter.date(from: dateString) ?? Date()
            } else {
                targetDate = Date()
            }

            // Convert string to UsageType
            let usageType = UsageType(rawValue: typeFilter) ?? .app

            // Get aggregator output
            let usage = try UsageAggregator.aggregateUsage(
                for: targetDate,
                type: usageType,
                topPercentage: topPercentage,
                modelContext: context
            )

            completion(usage.isEmpty ? nil : usage, nil)
        } catch {
            logger.error("Failed to fetch usage activity: \(error.localizedDescription)")
            completion(nil, error)
        }
    }

    func getVersion(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let version = UpdateManager.shared.getCurrentVersion()
            completion(version)
        }
    }
}

/// XPC Service manager for handling IPC connections
@MainActor
class IPCServiceManager: NSObject, ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "IPCServiceManager"
    )
    private var listener: NSXPCListener?
    private nonisolated let service: IPCService

    init(modelContainer: ModelContainer) {
        self.service = IPCService(modelContainer: modelContainer)
        super.init()
    }

    func startService() {
        guard listener == nil else {
            logger.info("IPC service already running")
            return
        }

        listener = NSXPCListener(machServiceName: "com.renjfk.SimplyTrack")
        listener?.delegate = self
        listener?.resume()
        logger.info("IPC service started")
    }

    func stopService() {
        listener?.invalidate()
        listener = nil
        logger.info("IPC service stopped")
    }
}

extension IPCServiceManager: NSXPCListenerDelegate {
    nonisolated func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(
            with: SimplyTrackIPCProtocol.self
        )
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
