//
//  ContentView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 27.08.2025.
//

import SwiftUI
import SwiftData
import AppKit
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .day
    @State private var showingCalendar = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var loginItemPermissionDenied = false
    @EnvironmentObject private var appDelegate: AppDelegate
    
    @State private var showingClearDataConfirmation = false
    
    // Track when user is viewing "today" for automatic date updates
    @State private var isViewingTodayWhenSelected = true
    
    // Cached computed values
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
    
    
    // Page view state
    @State private var currentPage = 0
    
    // Computed display arrays based on view mode
    private var currentTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        viewMode == .day ? cachedTopApps : cachedWeeklyTopApps
    }
    
    private var currentTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        viewMode == .day ? cachedTopWebsites : cachedWeeklyTopWebsites
    }
    
    private var currentTotalActiveTime: TimeInterval {
        viewMode == .day ? cachedTotalActiveTime : cachedWeeklyTotalActiveTime
    }

    enum ViewMode {
        case day, week
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

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
                    if loginItemPermissionDenied {
                        PermissionBannerView(
                            title: "Login Items Permission Required",
                            message: "SimplyTrack needs permission to start automatically. Enable it in Login Items settings.",
                            primaryButtonTitle: "Open Login Items Settings",
                            primaryAction: { openLoginItemsSettings() },
                            dismissAction: { loginItemPermissionDenied = false },
                            color: .orange
                        )
                    }
                    
                    
                    // Active Time Chart
                    ActiveTimeView(
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
                    AppsListView(
                        apps: currentTopApps,
                        showAllApps: $showAllApps
                    )

                    // Websites Section
                    WebsitesListView(
                        websites: currentTopWebsites,
                        showAllWebsites: $showAllWebsites
                    )
                }
                .padding(12)
            }

            // Bottom Controls
            bottomControls
        }
        .frame(width: 340, height: 600)
        .onChange(of: selectedDate) { _, _ in
            isViewingTodayWhenSelected = viewMode == .day && Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            MockDataGenerator.populateWithMockData(
                for: selectedDate,
                modelContext: modelContext,
                config: MockDataConfig.intense,
                sampleFromDate: { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: "2025-09-05") ?? Date() }()
            )
            refreshCachedValues()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverWillShow"))) { _ in
            if isViewingTodayWhenSelected {
                selectedDate = Date()
            }
            refreshCachedValues()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverDidClose"))) { _ in
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
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all tracking data for the selected \(viewMode == .day ? "day" : "week"). This action cannot be undone.")
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
                loginItemPermissionDenied: $loginItemPermissionDenied,
                viewMode: viewMode,
                showingClearDataConfirmation: $showingClearDataConfirmation
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Data Management
    
    private func refreshCachedValues() {
        Task {
            await refreshCachedValuesAsync()
        }
    }
    
    private func refreshCachedValuesAsync() async {
        let results = await fetchAllDataAsync()
        
        await MainActor.run {
            cachedWorkPeriods = results.workPeriods
            cachedWeeklyActivity = results.weeklyActivity
            cachedTotalActiveTime = results.totalActiveTime
            cachedTopApps = results.topApps
            cachedTopWebsites = results.topWebsites
            
            // Update weekly cached data
            cachedWeeklyTotalActiveTime = results.weeklyTotalActiveTime
            cachedWeeklyTopApps = results.weeklyTopApps
            cachedWeeklyTopWebsites = results.weeklyTopWebsites
        }
    }
    
    private func handleError(_ error: Error, context: String) {
        DispatchQueue.main.async {
            errorMessage = "\(context): \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Database Queries

    private struct AllDataResults {
        let workPeriods: [(startTime: Date, endTime: Date, duration: TimeInterval)]
        let weeklyActivity: [String: TimeInterval]
        let totalActiveTime: TimeInterval
        let topApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
        let topWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
        
        // Weekly aggregated data
        let weeklyTotalActiveTime: TimeInterval
        let weeklyTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
        let weeklyTopWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    }
    
    private func fetchAllDataAsync() async -> AllDataResults {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                continuation.resume(returning: fetchAllSessionData())
            }
        }
    }
    
    private func fetchAllSessionData() -> AllDataResults {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        
        do {
            // Query for daily sessions
            let dailyDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfDay && session.startTime < endOfDay && session.endTime != nil
                },
                sortBy: [
                    SortDescriptor(\.type),
                    SortDescriptor(\.identifier),
                    SortDescriptor(\.startTime)
                ]
            )
            let dailySessions = try modelContext.fetch(dailyDescriptor)
            
            // Query for weekly sessions (app sessions only)
            let weeklyDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfWeek && session.startTime < endOfWeek && session.type == "app" && session.endTime != nil
                },
                sortBy: [SortDescriptor(\.startTime)]
            )
            let weeklySessions = try modelContext.fetch(weeklyDescriptor)
            
            // Separate sessions by type 
            let appSessions = dailySessions.filter { $0.type == "app" }
            let websiteSessions = dailySessions.filter { $0.type == "website" }
            
            // Compute work periods from app sessions
            let workPeriods = computeWorkPeriods(from: appSessions)
            
            // Compute total active time (app sessions only)
            let totalActiveTime = appSessions.reduce(0) { $0 + $1.duration }
            
            // Aggregate and convert sessions to display format
            let topApps = aggregateAppSessions(appSessions)
            let topWebsites = aggregateWebsiteSessions(websiteSessions)
            
            // Compute weekly activity
            let weeklyActivity = computeWeeklyActivity(from: weeklySessions)
            
            // Calculate weekly aggregated data
            let weeklyTotalActiveTime = weeklySessions.reduce(0) { $0 + $1.duration }
            let weeklyTopApps = aggregateAppSessions(weeklySessions)
            
            // Get weekly website sessions
            let weeklyWebsiteDescriptor = FetchDescriptor<UsageSession>(
                predicate: #Predicate<UsageSession> { session in
                    session.startTime >= startOfWeek && session.startTime < endOfWeek && session.type == "website" && session.endTime != nil
                },
                sortBy: [SortDescriptor(\.startTime)]
            )
            let weeklyWebsiteSessions = (try? modelContext.fetch(weeklyWebsiteDescriptor)) ?? []
            let weeklyTopWebsites = aggregateWebsiteSessions(weeklyWebsiteSessions)
            
            return AllDataResults(
                workPeriods: workPeriods,
                weeklyActivity: weeklyActivity,
                totalActiveTime: totalActiveTime,
                topApps: topApps,
                topWebsites: topWebsites,
                weeklyTotalActiveTime: weeklyTotalActiveTime,
                weeklyTopApps: weeklyTopApps,
                weeklyTopWebsites: weeklyTopWebsites
            )
        } catch {
            handleError(error, context: "Failed to load session data")
            return AllDataResults(
                workPeriods: [],
                weeklyActivity: [:],
                totalActiveTime: 0,
                topApps: [],
                topWebsites: [],
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
        
        guard !completedSessions.isEmpty else { return [] }
        
        var mergedPeriods: [(Date, Date)] = []
        var currentStart = completedSessions[0].0
        var currentEnd = completedSessions[0].1
        
        for (startTime, endTime) in completedSessions.dropFirst() {
            if startTime <= currentEnd {
                // Overlapping or adjacent sessions - merge them
                currentEnd = max(currentEnd, endTime)
            } else {
                // Non-overlapping session - save current period and start new one
                mergedPeriods.append((currentStart, currentEnd))
                currentStart = startTime
                currentEnd = endTime
            }
        }
        
        // Add the last period
        mergedPeriods.append((currentStart, currentEnd))
        
        // Convert to the expected format with duration
        return mergedPeriods.map { (startTime, endTime) in
            let duration = endTime.timeIntervalSince(startTime)
            return (startTime: startTime, endTime: endTime, duration: duration)
        }
    }
    
    private func aggregateAppSessions(_ sessions: [UsageSession]) -> [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        var appData: [String: (name: String, totalTime: TimeInterval)] = [:]
        
        for session in sessions {
            let existing = appData[session.identifier, default: (name: session.name, totalTime: 0)]
            appData[session.identifier] = (
                name: existing.name,
                totalTime: existing.totalTime + session.duration
            )
        }
        
        // Fetch icon data separately
        let iconDescriptor = FetchDescriptor<Icon>()
        let icons = (try? modelContext.fetch(iconDescriptor)) ?? []
        let iconMap = Dictionary(uniqueKeysWithValues: icons.compactMap { icon in
            icon.iconData != nil ? (icon.identifier, icon.iconData!) : nil
        })
        
        return appData
            .map { (identifier, data) in
                (identifier: identifier, name: data.name, iconData: iconMap[identifier], totalTime: data.totalTime)
            }
            .sorted { $0.totalTime > $1.totalTime }
    }
    
    private func aggregateWebsiteSessions(_ sessions: [UsageSession]) -> [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        var websiteData: [String: (name: String, totalTime: TimeInterval)] = [:]
        
        for session in sessions {
            let existing = websiteData[session.identifier, default: (name: session.name, totalTime: 0)]
            websiteData[session.identifier] = (
                name: existing.name,
                totalTime: existing.totalTime + session.duration
            )
        }
        
        // Fetch website icons from database
        let iconDescriptor = FetchDescriptor<Icon>()
        let icons = (try? modelContext.fetch(iconDescriptor)) ?? []
        let iconMap = Dictionary(uniqueKeysWithValues: icons.map { ($0.identifier, $0.iconData) })
        
        return websiteData
            .map { (identifier, data) in
                (identifier: identifier, name: data.name, iconData: iconMap[identifier] ?? nil, totalTime: data.totalTime)
            }
            .sorted { $0.totalTime > $1.totalTime }
    }
    
    private func computeWeeklyActivity(from sessions: [UsageSession]) -> [String: TimeInterval] {
        var weeklyActivity: [String: TimeInterval] = [:]
        let calendar = Calendar.current
        
        for session in sessions {
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: session.startTime) - 1]
            let dayKey = String(dayName.prefix(3)).uppercased() // Use 3-letter abbreviations
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
    
    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
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
            refreshCachedValues()
        } catch {
            handleError(error, context: errorContext)
        }
    }
}

#Preview {
    ContentView()
}
