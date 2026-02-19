//
//  ContentView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

/// Main application interface displayed in the menu bar popover.
/// Coordinates usage data visualization, permission management, and user interactions.
/// Supports both daily and weekly views with cached data for performance.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var loginItemManager = LoginItemManager.shared
    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .day
    @State private var showingCalendar = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @EnvironmentObject private var appDelegate: AppDelegate

    @State private var showingClearDataConfirmation = false

    @State private var isViewingTodayWhenSelected = true

    @State private var cachedWorkPeriods: [(startTime: Date, endTime: Date, duration: TimeInterval)] = []
    @State private var cachedWeeklyActivity: [String: TimeInterval] = [:]
    @State private var cachedTotalActiveTime: TimeInterval = 0
    @State private var cachedTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] = []
    @State private var cachedTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] = []

    // Weekly cached data
    @State private var cachedWeeklyTotalActiveTime: TimeInterval = 0
    @State private var cachedWeeklyTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] = []
    @State private var cachedWeeklyTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] = []

    // Expandable sections
    @State private var showAllApps = false
    @State private var showAllWebsites = false

    // Height measurement
    @State private var headerHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    @State private var bottomHeight: CGFloat = 0

    // Popover height management
    @StateObject private var heightManager = PopoverHeightManager.shared

    // Page view state
    @State private var currentPage = 0

    // Data fetch tracking
    @State private var lastDailyFetchDate: Date?
    @State private var lastWeeklyFetchDate: Date?
    @State private var lastDailyFetchTime: Date?
    @State private var lastWeeklyFetchTime: Date?
    @State private var isDailyFetching = false
    @State private var isWeeklyFetching = false
    @State private var isPopoverVisible = false

    private var currentTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        viewMode == .day ? cachedTopApps : cachedWeeklyTopApps
    }

    private var currentTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        viewMode == .day ? cachedTopWebsites : cachedWeeklyTopWebsites
    }

    private var currentTotalActiveTime: TimeInterval {
        viewMode == .day ? cachedTotalActiveTime : cachedWeeklyTotalActiveTime
    }

    /// Display mode for usage data visualization
    enum ViewMode {
        /// Daily view showing single day data
        case day
        /// Weekly view showing aggregated week data
        case week
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .background(
                    GeometryReader { geo in
                        Color.clear.onChange(of: geo.size.height, initial: true) { _, newHeight in
                            headerHeight = newHeight
                        }
                    }
                )

            ScrollView {
                VStack(spacing: 12) {
                    // Permission Banners
                    if permissionManager.automationPermissionStatus == .denied {
                        PermissionBannerView(
                            title: "Browser Tracking Permission Denied",
                            message: "Browser tracking was denied. Enable it in System Preferences to track website usage.",
                            primaryButtonTitle: "Open System Preferences",
                            primaryAction: { permissionManager.openSystemPreferences() },
                            color: .red
                        )
                    }

                    // System Events Permission Banner
                    if permissionManager.systemEventsPermissionStatus == .denied {
                        PermissionBannerView(
                            title: "System Events Permission Required",
                            message: "SimplyTrack needs System Events access to detect Safari private browsing. Enable it in System Preferences.",
                            primaryButtonTitle: "Open System Preferences",
                            primaryAction: { permissionManager.openSystemPreferences() },
                            color: .orange
                        )
                    }

                    // Accessibility Permission Banner
                    if permissionManager.accessibilityPermissionStatus == .denied {
                        PermissionBannerView(
                            title: "Accessibility Permission Required",
                            message: "SimplyTrack needs Accessibility access to detect Safari private browsing. Enable it in System Preferences.",
                            primaryButtonTitle: "Open System Preferences",
                            primaryAction: { permissionManager.openAccessibilityPreferences() },
                            color: .orange
                        )
                    }

                    // Error Banner - show browser communication errors
                    if let error = permissionManager.lastError {
                        PermissionBannerView(
                            title: "Browser Communication Error",
                            message: error,
                            primaryButtonTitle: "Retry",
                            primaryAction: { permissionManager.clearError() },
                            dismissAction: { permissionManager.clearError() },
                            color: .orange
                        )
                    }

                    // Notification Permission Banner
                    if appDelegate.notificationPermissionDenied {
                        PermissionBannerView(
                            title: "Notifications Disabled",
                            message: "Update notifications are disabled. Enable them in System Preferences to get notified of updates.",
                            primaryButtonTitle: "Open System Preferences",
                            primaryAction: { openNotificationSettings() },
                            dismissAction: { appDelegate.notificationPermissionDenied = false },
                            color: .orange
                        )
                    }

                    // Login Items Permission Banner
                    if loginItemManager.permissionDenied {
                        PermissionBannerView(
                            title: "Login Items Permission Required",
                            message: "SimplyTrack needs permission to start automatically. Enable it in Login Items settings.",
                            primaryButtonTitle: "Open Login Items Settings",
                            primaryAction: { loginItemManager.openLoginItemsSettings() },
                            dismissAction: { loginItemManager.permissionDenied = false },
                            color: .orange
                        )
                    }

                    // Active Time Chart
                    ActiveTimeCard(
                        viewMode: viewMode,
                        selectedDate: selectedDate,
                        cachedWorkPeriods: cachedWorkPeriods,
                        cachedWeeklyActivity: cachedWeeklyActivity,
                        totalActiveTime: currentTotalActiveTime,
                        topApps: currentTopApps,
                        weeklyTopApps: cachedWeeklyTopApps,
                        currentPage: $currentPage
                    )

                    // Apps Section
                    UsageListView(
                        type: .apps,
                        items: currentTopApps,
                        showAllItems: $showAllApps
                    )

                    // Websites Section
                    UsageListView(
                        type: .websites,
                        items: currentTopWebsites,
                        showAllItems: $showAllWebsites
                    )
                }
                .padding(12)
                .background(
                    GeometryReader { geo in
                        Color.clear.onChange(of: geo.size.height, initial: true) { _, newHeight in
                            scrollContentHeight = newHeight
                        }
                    }
                )
            }

            // Bottom Controls
            bottomControls
                .background(
                    GeometryReader { geo in
                        Color.clear.onChange(of: geo.size.height, initial: true) { _, newHeight in
                            bottomHeight = newHeight
                        }
                    }
                )
        }
        .frame(width: 340)
        .onChange(of: headerHeight) { _, _ in updateIdealHeight() }
        .onChange(of: scrollContentHeight) { _, _ in updateIdealHeight() }
        .onChange(of: bottomHeight) { _, _ in updateIdealHeight() }
        .onChange(of: selectedDate) { _, _ in
            updateTodayViewingStatus()
            //            MockDataGenerator.populateWithMockData(
            //                for: selectedDate,
            //                modelContext: modelContext,
            //                config: MockDataConfig.intense,
            //                sampleFromDate: { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: "2025-09-05") ?? Date() }()
            //            )
            refreshCachedValues()
        }
        .onChange(of: viewMode) { _, _ in
            refreshCachedValues()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverWillShow"))) { _ in
            isPopoverVisible = true
            if isViewingTodayWhenSelected {
                selectedDate = Date()
            }
            // Force height recalculation on each popover show
            updateIdealHeight()
            // Only refresh if we don't have current data
            refreshCachedValues()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverDidClose"))) { _ in
            isPopoverVisible = false
            showAllApps = false
            showAllWebsites = false
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog(
            "Clear \(viewMode == .day ? "Day" : "Week") Data",
            isPresented: $showingClearDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Data", role: .destructive) {
                clearData(for: selectedDate, period: viewMode)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all tracking data for the selected \(viewMode == .day ? "day" : "week"). This action cannot be undone.")
        }
        .onReceive(appDelegate.$selectedDate) { newDate in
            selectedDate = newDate
            updateTodayViewingStatus()
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { previousPeriod() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showingCalendar.toggle() }) {
                    Text(headerTitle)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingCalendar, arrowEdge: .top) {
                    calendarPopover
                }

                if !isViewingToday {
                    Button(action: { goToToday() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Go to today")
                }
            }

            Spacer()

            Button(action: { nextPeriod() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextPeriod)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var calendarPopover: some View {
        VStack {
            DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
        }
    }

    private var bottomControls: some View {
        HStack {
            Spacer()

            Picker(selection: $viewMode, label: EmptyView()) {
                ForEach([ViewMode.day, ViewMode.week], id: \.self) { mode in
                    Text(mode == .day ? "Day" : "Week")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Spacer()

            SettingsMenuView(
                viewMode: viewMode,
                showingClearDataConfirmation: $showingClearDataConfirmation
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Data Management

    private func refreshCachedValues() {
        // Don't fetch data if popover isn't visible (except on startup)
        if !isPopoverVisible && lastDailyFetchDate != nil && lastWeeklyFetchDate != nil {
            return
        }

        if viewMode == .day {
            refreshDailyData()
        } else {
            refreshWeeklyData()
        }
    }

    private func refreshDailyData() {
        let calendar = Calendar.current
        let now = Date()

        // Check if we already have this data and it's not stale (30 second cache)
        if let lastDate = lastDailyFetchDate,
            let lastFetchTime = lastDailyFetchTime,
            calendar.isDate(lastDate, inSameDayAs: selectedDate),
            now.timeIntervalSince(lastFetchTime) < TrackingService.dataPersistenceInterval
        {
            return
        }

        // Check if we're already fetching
        if isDailyFetching {
            return
        }

        isDailyFetching = true
        Task {
            let results = await fetchDailyData()

            await MainActor.run {
                cachedWorkPeriods = results.workPeriods
                cachedTotalActiveTime = results.totalActiveTime
                cachedTopApps = results.topApps
                cachedTopWebsites = results.topWebsites
                lastDailyFetchDate = selectedDate
                lastDailyFetchTime = Date()
                isDailyFetching = false
            }
        }
    }

    private func refreshWeeklyData() {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let now = Date()

        // Check if we already have this data and it's not stale (30 second cache)
        if let lastDate = lastWeeklyFetchDate,
            let lastFetchTime = lastWeeklyFetchTime,
            let lastWeekStart = calendar.dateInterval(of: .weekOfYear, for: lastDate)?.start,
            calendar.isDate(currentWeekStart, inSameDayAs: lastWeekStart),
            now.timeIntervalSince(lastFetchTime) < TrackingService.dataPersistenceInterval
        {
            return
        }

        // Check if we're already fetching
        if isWeeklyFetching {
            return
        }

        isWeeklyFetching = true
        Task {
            let results = await fetchWeeklyData()

            await MainActor.run {
                cachedWeeklyActivity = results.weeklyActivity
                cachedWeeklyTotalActiveTime = results.weeklyTotalActiveTime
                cachedWeeklyTopApps = results.weeklyTopApps
                cachedWeeklyTopWebsites = results.weeklyTopWebsites
                lastWeeklyFetchDate = selectedDate
                lastWeeklyFetchTime = Date()
                isWeeklyFetching = false
            }
        }
    }

    private func handleError(_ error: Error, context: String) {
        DispatchQueue.main.async {
            errorMessage = "\(context): \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Database Queries

    private struct DailyDataResults {
        let workPeriods: [(startTime: Date, endTime: Date, duration: TimeInterval)]
        let totalActiveTime: TimeInterval
        let topApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
        let topWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    }

    private struct WeeklyDataResults {
        let weeklyActivity: [String: TimeInterval]
        let weeklyTotalActiveTime: TimeInterval
        let weeklyTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
        let weeklyTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    }

    @MainActor
    private func fetchDailyData() async -> DailyDataResults {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let dailyDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfDay && session.startTime < endOfDay && session.endTime != nil
                },
                sortBy: [
                    SortDescriptor(\.type),
                    SortDescriptor(\.identifier),
                    SortDescriptor(\.startTime),
                ]
            )

            let iconDescriptor = FetchDescriptor<Icon>()
            let icons = try modelContext.fetch(iconDescriptor)
            let iconMap = Dictionary(
                uniqueKeysWithValues: icons.compactMap { icon in
                    icon.iconData != nil ? (icon.identifier, icon.iconData!) : nil
                }
            )

            let dailyResult = try modelContext.fetch(dailyDescriptor)
            let appSessions = dailyResult.filter { $0.type == "app" }
            let websiteSessions = dailyResult.filter { $0.type == "website" }

            let workPeriods = computeWorkPeriods(from: appSessions)
            let totalActiveTime = appSessions.reduce(0) { $0 + $1.duration }
            let topApps = aggregateAppSessions(appSessions, iconMap: iconMap)
            let topWebsites = aggregateWebsiteSessions(websiteSessions, iconMap: iconMap)

            return DailyDataResults(
                workPeriods: workPeriods,
                totalActiveTime: totalActiveTime,
                topApps: topApps,
                topWebsites: topWebsites
            )
        } catch {
            handleError(error, context: "Failed to load daily data")
            return DailyDataResults(
                workPeriods: [],
                totalActiveTime: 0,
                topApps: [],
                topWebsites: []
            )
        }
    }

    @MainActor
    private func fetchWeeklyData() async -> WeeklyDataResults {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!

        do {
            let weeklyDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfWeek && session.startTime < endOfWeek && session.type == "app" && session.endTime != nil
                },
                sortBy: [SortDescriptor(\.startTime)]
            )

            let weeklyWebsiteDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfWeek && session.startTime < endOfWeek && session.type == "website" && session.endTime != nil
                },
                sortBy: [SortDescriptor(\.startTime)]
            )

            let iconDescriptor = FetchDescriptor<Icon>()
            let icons = try modelContext.fetch(iconDescriptor)
            let iconMap = Dictionary(
                uniqueKeysWithValues: icons.compactMap { icon in
                    icon.iconData != nil ? (icon.identifier, icon.iconData!) : nil
                }
            )

            let weeklyResult = try modelContext.fetch(weeklyDescriptor)
            let weeklyWebsiteResult = try modelContext.fetch(weeklyWebsiteDescriptor)

            let weeklyActivity = computeWeeklyActivity(from: weeklyResult)
            let weeklyTotalActiveTime = weeklyResult.reduce(0) { $0 + $1.duration }
            let weeklyTopApps = aggregateAppSessions(weeklyResult, iconMap: iconMap)
            let weeklyTopWebsites = aggregateWebsiteSessions(weeklyWebsiteResult, iconMap: iconMap)

            return WeeklyDataResults(
                weeklyActivity: weeklyActivity,
                weeklyTotalActiveTime: weeklyTotalActiveTime,
                weeklyTopApps: weeklyTopApps,
                weeklyTopWebsites: weeklyTopWebsites
            )
        } catch {
            handleError(error, context: "Failed to load weekly data")
            return WeeklyDataResults(
                weeklyActivity: [:],
                weeklyTotalActiveTime: 0,
                weeklyTopApps: [],
                weeklyTopWebsites: []
            )
        }
    }

    // MARK: - Session Data Processing

    private func computeWorkPeriods(from sessions: [UsageSession]) -> [(startTime: Date, endTime: Date, duration: TimeInterval)] {
        // Filter out sessions without end times and sort by start time
        let completedSessions = sessions.compactMap { session -> (Date, Date)? in
            guard let endTime = session.endTime else { return nil }
            return (session.startTime, endTime)
        }.sorted { $0.0 < $1.0 }

        guard !completedSessions.isEmpty else {
            return []
        }

        var mergedPeriods: [(Date, Date)] = []
        var currentStart = completedSessions[0].0
        var currentEnd = completedSessions[0].1

        for (sessionStartTime, sessionEndTime) in completedSessions.dropFirst() {
            if sessionStartTime <= currentEnd {
                // Overlapping or adjacent sessions - merge them
                currentEnd = max(currentEnd, sessionEndTime)
            } else {
                // Non-overlapping session - save current period and start new one
                mergedPeriods.append((currentStart, currentEnd))
                currentStart = sessionStartTime
                currentEnd = sessionEndTime
            }
        }

        // Add the last period
        mergedPeriods.append((currentStart, currentEnd))

        // Convert to the expected format with duration
        let result = mergedPeriods.map { (periodStartTime, periodEndTime) in
            let duration = periodEndTime.timeIntervalSince(periodStartTime)
            return (startTime: periodStartTime, endTime: periodEndTime, duration: duration)
        }

        return result
    }

    private func aggregateAppSessions(_ sessions: [UsageSession], iconMap: [String: Data]) -> [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        var appData: [String: (name: String, totalTime: TimeInterval)] = [:]

        for session in sessions {
            let existing = appData[session.identifier, default: (name: session.name, totalTime: 0)]
            appData[session.identifier] = (
                name: existing.name,
                totalTime: existing.totalTime + session.duration
            )
        }

        let result =
            appData
            .map { (identifier, data) in
                (identifier: identifier, name: data.name, iconData: iconMap[identifier], totalTime: data.totalTime)
            }
            .sorted { $0.totalTime > $1.totalTime }

        return result
    }

    private func aggregateWebsiteSessions(_ sessions: [UsageSession], iconMap: [String: Data]) -> [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        var websiteData: [String: (name: String, totalTime: TimeInterval)] = [:]

        for session in sessions {
            let existing = websiteData[session.identifier, default: (name: session.name, totalTime: 0)]
            websiteData[session.identifier] = (
                name: existing.name,
                totalTime: existing.totalTime + session.duration
            )
        }

        let result =
            websiteData
            .map { (identifier, data) in
                (identifier: identifier, name: data.name, iconData: iconMap[identifier] ?? nil, totalTime: data.totalTime)
            }
            .sorted { $0.totalTime > $1.totalTime }

        return result
    }

    private func computeWeeklyActivity(from sessions: [UsageSession]) -> [String: TimeInterval] {
        var weeklyActivity: [String: TimeInterval] = [:]
        let calendar = Calendar.current

        for session in sessions {
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: session.startTime) - 1]
            let dayKey = String(dayName.prefix(3)).uppercased()  // Use 3-letter abbreviations
            weeklyActivity[dayKey, default: 0] += session.duration
        }

        return weeklyActivity
    }

    // MARK: - UI Computed Properties

    private var headerTitle: String {
        let formatter = DateFormatter()
        if viewMode == .day {
            if Calendar.current.isDateInToday(selectedDate) {
                return "Today"
            } else {
                formatter.dateFormat = "dd MMMM yyyy"
                return formatter.string(from: selectedDate)
            }
        } else {
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedDate

            formatter.dateFormat = "dd.MM.yyyy"
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        }
    }

    private var canGoToNextPeriod: Bool {
        let calendar = Calendar.current
        let today = Date()

        if viewMode == .day {
            return !calendar.isDate(selectedDate, inSameDayAs: today)
        } else {
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let selectedWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            return selectedWeekStart < currentWeekStart
        }
    }

    private var isViewingToday: Bool {
        let calendar = Calendar.current
        let today = Date()

        if viewMode == .day {
            return calendar.isDate(selectedDate, inSameDayAs: today)
        } else {
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let selectedWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            return calendar.isDate(selectedWeekStart, inSameDayAs: currentWeekStart)
        }
    }

    // MARK: - Helper Methods

    private func updateIdealHeight() {
        let totalHeight = scrollContentHeight + headerHeight + bottomHeight
        if abs(heightManager.idealHeight - totalHeight) > 1 {
            heightManager.idealHeight = totalHeight
        }
    }

    private func updateTodayViewingStatus() {
        isViewingTodayWhenSelected = viewMode == .day && Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }

    private func previousPeriod() {
        if viewMode == .day {
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        }
    }

    private func nextPeriod() {
        if viewMode == .day {
            selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        } else {
            selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        }
    }

    private func goToToday() {
        selectedDate = Date()
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func clearData(for date: Date, period: ViewMode) {
        let calendar = Calendar.current
        let (startDate, endDate, errorContext): (Date, Date, String)

        if period == .day {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            (startDate, endDate, errorContext) = (startOfDay, endOfDay, "Failed to clear day data")
        } else {
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            (startDate, endDate, errorContext) = (startOfWeek, endOfWeek, "Failed to clear week data")
        }

        do {
            let descriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startDate && session.startTime < endDate
                }
            )
            let sessions = try modelContext.fetch(descriptor)
            try modelContext.transaction {
                for session in sessions {
                    modelContext.delete(session)
                }
            }
            // Invalidate cache since we cleared data
            lastDailyFetchDate = nil
            lastWeeklyFetchDate = nil
            lastDailyFetchTime = nil
            lastWeeklyFetchTime = nil
            isDailyFetching = false
            isWeeklyFetching = false
            refreshCachedValues()
        } catch {
            handleError(error, context: errorContext)
        }
    }
}

#Preview {
    ContentView()
}
