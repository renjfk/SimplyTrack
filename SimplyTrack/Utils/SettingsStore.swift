//
//  SettingsStore.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 09.09.2025.
//

import Foundation

/// Default values for app settings stored in UserDefaults.
/// Provides consistent fallback values and template content for AI notifications.
struct AppStorageDefaults {
    /// Default prompt template for AI-generated daily summary notifications.
    /// Contains placeholders for app and website usage data replacement.
    static let summaryNotificationPrompt = """
Create a concise daily summary notification (100-150 chars max). Use emojis and friendly tone. No markdown formatting.

Usage overview:
Apps: {appSummary}
Sites: {websiteSummary}

Focus on key insights and productivity patterns. Make it encouraging and actionable.
"""
    
    /// Default notification time set to 9:00 AM as TimeInterval since epoch.
    /// Used for scheduling daily summary notifications.
    static let summaryNotificationTime: Double = {
        let calendar = Calendar.current
        let components = DateComponents(hour: 9, minute: 0)
        return calendar.date(from: components)?.timeIntervalSince1970 ?? 0
    }()
}

/// UserDefaults extension providing environment-specific storage isolation.
/// Debug builds use separate settings to avoid conflicts with release versions.
extension UserDefaults {
    static let app: UserDefaults = {
        #if DEBUG
        let bundleId = Bundle.main.bundleIdentifier!
        return UserDefaults(suiteName: "\(bundleId).debug") ?? UserDefaults.standard
        #else
        return UserDefaults.standard
        #endif
    }()
}
