//
//  DataModels.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import Foundation
import SwiftData

enum UsageType: String, Codable, CaseIterable {
    case app
    case website
}

@Model
class Icon {
    @Attribute(.unique) var identifier: String
    var iconData: Data?
    var lastUpdated: Date
    
    init(identifier: String, iconData: Data?) {
        self.identifier = identifier
        self.iconData = iconData
        self.lastUpdated = Date()
    }
    
    var needsUpdate: Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return lastUpdated < oneWeekAgo
    }
    
    func updateIcon(with newData: Data?) {
        self.iconData = newData
        self.lastUpdated = Date()
    }
}

@Model
class UsageSession {
    @Attribute(.unique) var id: UUID = UUID()
    var type: String
    var identifier: String // bundleId for apps, domain for websites
    var name: String
    var startTime: Date
    var endTime: Date?
    
    var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
    
    init(type: UsageType, identifier: String, name: String, startTime: Date = Date()) {
        self.id = UUID()
        self.type = type.rawValue
        self.identifier = identifier
        self.name = name
        self.startTime = startTime
        self.endTime = nil
    }
    
    func endSession(at endTime: Date = Date()) {
        self.endTime = endTime
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
