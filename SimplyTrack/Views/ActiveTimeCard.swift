//
//  ActiveTimeCard.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 11.09.2025.
//

import SwiftUI

/// Wrapper card component that displays active time information with chart switching.
/// Contains header with total time and chart picker for different visualization modes.
struct ActiveTimeCard: View {
    /// Current display mode (daily or weekly)
    let viewMode: ContentView.ViewMode
    /// Selected date for data display
    let selectedDate: Date
    /// Cached work periods for timeline visualization
    let cachedWorkPeriods: [(startTime: Date, endTime: Date, duration: TimeInterval)]
    /// Cached weekly activity breakdown by day
    let cachedWeeklyActivity: [String: TimeInterval]
    /// Total active time for the current period
    let totalActiveTime: TimeInterval
    /// Top applications for daily pie chart
    let topApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    /// Top applications for weekly pie chart
    let weeklyTopApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    /// Current chart page (0: timeline/bar, 1: pie chart)
    @Binding var currentPage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Time")
                    .font(.headline)
                Spacer()
                Text(totalActiveTime.formattedDuration)
            }

            if viewMode == .day {
                dailyPageView
            } else {
                weeklyPageView
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private var dailyPageView: some View {
        VStack(spacing: 8) {
            Picker(selection: $currentPage, label: EmptyView()) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .tag(0)
                Image(systemName: "chart.pie")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .fixedSize()

            Group {
                if currentPage == 0 {
                    HourlyTimelineChart(
                        selectedDate: selectedDate,
                        workPeriods: cachedWorkPeriods
                    )
                } else {
                    UsagePieChart(
                        selectedDate: selectedDate,
                        topApps: topApps
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentPage)
        }
        .frame(height: 120)
    }

    private var weeklyPageView: some View {
        VStack(spacing: 8) {
            Picker(selection: $currentPage, label: EmptyView()) {
                Image(systemName: "chart.bar")
                    .tag(0)
                Image(systemName: "chart.pie")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .fixedSize()

            Group {
                if currentPage == 0 {
                    WeeklyBarChart(
                        selectedDate: selectedDate,
                        weeklyActivity: cachedWeeklyActivity
                    )
                } else {
                    UsagePieChart(
                        selectedDate: selectedDate,
                        topApps: weeklyTopApps
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentPage)
        }
        .frame(height: 120)
    }
}
