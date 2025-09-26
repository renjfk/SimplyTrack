//
//  NotificationService.swift
//  SimplyTrack
//
//  Handles daily summary notifications, AI integration, and notification permissions
//  Manages scheduled notifications, user notification center delegation, and AI-powered usage summaries
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import os

/// Service responsible for managing user notifications and AI-powered usage summaries.
/// Handles notification permissions, schedules daily summary notifications, integrates with AI services,
/// and manages notification interactions. Also serves as the app's notification center delegate.
@MainActor
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NotificationService")

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    private weak var appDelegate: AppDelegate?

    // MARK: - Settings

    @AppStorage("summaryNotificationsEnabled", store: .app) private var summaryNotificationsEnabled = false
    @AppStorage("aiEndpoint", store: .app) private var aiEndpoint = ""
    @AppStorage("aiModel", store: .app) private var aiModel = ""
    @AppStorage("summaryNotificationPrompt", store: .app) private var summaryNotificationPrompt = AppStorageDefaults.summaryNotificationPrompt
    @AppStorage("summaryNotificationTime", store: .app) private var summaryNotificationTime: Double = AppStorageDefaults.summaryNotificationTime
    @AppStorage("lastDailySummaryNotification", store: .app) private var lastDailySummaryNotification: Double = 0

    /// Initializes the notification service with required dependencies.
    /// - Parameters:
    ///   - modelContainer: SwiftData container for accessing usage data
    ///   - appDelegate: App delegate reference for UI coordination
    init(modelContainer: ModelContainer, appDelegate: AppDelegate) {
        self.modelContainer = modelContainer
        self.appDelegate = appDelegate
        super.init()
    }

    // MARK: - Public Interface

    /// Sets up notification permissions and categories.
    /// Requests user authorization for notifications and configures notification categories.
    /// Updates app delegate state if permission is denied.
    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if !granted {
                    appDelegate?.notificationPermissionDenied = true
                }
            } catch {
                appDelegate?.notificationPermissionDenied = true
            }
        }

        let updateCategory = UNNotificationCategory(
            identifier: NotificationConstants.updateCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([updateCategory])
    }

    /// Starts the notification scheduler that checks for daily summary notifications.
    /// Creates a timer that runs every 5 minutes to check if it's time to send the daily notification.
    func startNotificationScheduler() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                await self.checkForDailyNotification()
            }
        }
    }

    // MARK: - Daily Summary Logic

    private func checkForDailyNotification() async {
        // Validate that all required settings are configured
        guard summaryNotificationsEnabled && !aiEndpoint.isEmpty && !aiModel.isEmpty && !summaryNotificationPrompt.isEmpty else {
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let scheduledTime = Date(timeIntervalSince1970: summaryNotificationTime)
        let todayScheduledTime =
            calendar.date(
                bySettingHour: calendar.component(.hour, from: scheduledTime),
                minute: calendar.component(.minute, from: scheduledTime),
                second: 0,
                of: now
            ) ?? now

        // Ensure we've reached the scheduled notification time
        guard now >= todayScheduledTime else { return }

        // Prevent sending duplicate notifications on the same day
        let lastNotificationDate = Date(timeIntervalSince1970: lastDailySummaryNotification)
        if lastDailySummaryNotification > 0 && calendar.isDate(lastNotificationDate, inSameDayAs: now) {
            return
        }

        // Generate AI summary and send notification
        await sendDailySummaryNotification()

        // Record notification timestamp to prevent duplicates
        lastDailySummaryNotification = now.timeIntervalSince1970
    }

    private func sendDailySummaryNotification() async {
        // Calculate yesterday's date for usage aggregation
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        let appSummary: String
        let websiteSummary: String

        do {
            appSummary = try UsageAggregator.aggregateUsage(
                for: yesterday,
                type: .app,
                topPercentage: 0.8,
                modelContext: modelContainer.mainContext
            )

            websiteSummary = try UsageAggregator.aggregateUsage(
                for: yesterday,
                type: .website,
                topPercentage: 0.8,
                modelContext: modelContainer.mainContext
            )
        } catch {
            logger.error("Failed to aggregate usage data: \(error.localizedDescription)")
            return
        }

        // Substitute usage data into the user's prompt template
        let fullPrompt =
            summaryNotificationPrompt
            .replacingOccurrences(of: "{appSummary}", with: appSummary)
            .replacingOccurrences(of: "{websiteSummary}", with: websiteSummary)

        do {
            // Retrieve AI service API key from secure keychain storage
            let apiKey = try KeychainManager.shared.retrieve(key: "aiApiKey") ?? ""
            guard !apiKey.isEmpty else {
                logger.error("API key not found in keychain for daily summary")
                return
            }

            // Generate AI summary using configured endpoint and model
            let openAI = OpenAIService(apiURL: aiEndpoint, apiKey: apiKey)
            let messages = [OpenAIChatMessage(role: "user", content: fullPrompt)]
            let response = try await openAI.chatCompletions(
                model: aiModel,
                messages: messages,
                temperature: 0.7,
                maxTokens: 300
            )

            // Create and deliver notification with AI-generated summary
            if let aiSummary = response.choices.first?.message.content {
                let content = UNMutableNotificationContent()
                content.title = "Yesterday's Usage Summary"
                content.body = aiSummary
                content.sound = UNNotificationSound.default
                content.userInfo = ["summaryDate": yesterday.timeIntervalSince1970]

                let request = UNNotificationRequest(
                    identifier: "daily-summary",
                    content: content,
                    trigger: nil
                )

                try await UNUserNotificationCenter.current().add(request)
            }
        } catch {
            logger.error("Failed to generate daily summary: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handles user interactions with notifications.
    /// Routes daily summary taps to show usage data for the relevant date,
    /// and update notifications to download and install new versions.
    /// - Parameter response: User's response to the notification

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // Handle daily summary notification tap
            if response.notification.request.identifier == "daily-summary" {
                // Extract summary date from notification metadata
                if let summaryDateInterval = response.notification.request.content.userInfo["summaryDate"] as? TimeInterval {
                    appDelegate?.selectedDate = Date(timeIntervalSince1970: summaryDateInterval)
                } else {
                    // Fallback to yesterday if metadata is missing
                    appDelegate?.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }
                // Show popover with usage data for selected date
                appDelegate?.togglePopover()
            } else {
                // Handle update notification tap - download and install new version
                do {
                    try await UpdateManager.shared.downloadAndOpenInstaller()
                } catch {
                    appDelegate?.showError("Failed to download installer", error: error)
                }
            }
        default:
            break
        }
    }

    /// Determines how notifications should be presented when the app is active.
    /// - Returns: Presentation options allowing banner and sound
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}
