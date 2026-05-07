//
//  UsageToolRequests.swift
//  SimplyTrack
//
//  Created by Hermes Agent on 06.05.2026.
//

import Foundation

struct UsageRangeRequest: Codable, Sendable {
    let startTime: String?
    let endTime: String?
    let typeFilter: String?
    let groupBy: String?
    let includeActive: Bool?
}

struct UsageTimelineRequest: Codable, Sendable {
    let dateString: String?
    let typeFilter: String?
}

struct UsageDailySummaryRequest: Codable, Sendable {
    let dateString: String?
    let typeFilter: String?
    let limit: Int?
}
