//
//  UsageType.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import Foundation

/// Enumeration of trackable usage types in the SimplyTrack application.
/// Used to categorize different kinds of user activity for analytics and reporting.
enum UsageType: String, Codable, CaseIterable {
    /// Application usage tracking (foreground app activity)
    case app
    /// Website usage tracking (browser-based activity)
    case website
}