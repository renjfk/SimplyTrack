//
//  ActiveTimeView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI
import Charts

/// Displays active time visualizations using charts and timelines.
/// Supports both daily and weekly views with multiple chart types (timeline, bar, pie).
/// Shows work periods, daily breakdowns, and top application usage patterns.
struct ActiveTimeView: View {
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
                    hourlyChart
                } else {
                    pieChartView
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
                    weeklyChart
                } else {
                    weeklyPieChartView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentPage)
        }
        .frame(height: 120)
    }
    
    private var hourlyChart: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let timelineWidth = geometry.size.width
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: selectedDate)
                let dayDuration: TimeInterval = 24 * 3600
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(height: 80)
                        .cornerRadius(2)
                    
                    ForEach(Array(cachedWorkPeriods.enumerated()), id: \.offset) { index, period in
                        let sessionStart = period.startTime.timeIntervalSince(startOfDay)
                        let sessionDuration = period.duration
                        let startPosition = (sessionStart / dayDuration) * timelineWidth
                        let sessionWidth = max((sessionDuration / dayDuration) * timelineWidth, 2)
                        
                        Rectangle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: sessionWidth, height: 80)
                            .cornerRadius(1)
                            .offset(x: startPosition)
                    }
                }
            }
            .frame(height: 80)
            
            HStack {
                ForEach(Array(stride(from: 0, through: 21, by: 3)), id: \.self) { hour in
                    Text("\(hour)")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(height: 100)
    }
    
    private var weeklyChart: some View {
        Chart {
            ForEach(0..<7, id: \.self) { dayOffset in
                let calendar = Calendar.current
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) ?? selectedDate
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: dayDate) - 1]
                let dayKey = String(dayName.prefix(3)).uppercased()
                let totalTime = cachedWeeklyActivity[dayKey] ?? 0
                
                BarMark(
                    x: .value("Day", dayKey),
                    y: .value("Time", viewMode == .week ? totalTime : 0)
                )
                .foregroundStyle(.blue.opacity(0.8))
                .cornerRadius(2)
                .opacity(1)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(Color(NSColor.separatorColor))
                AxisValueLabel {
                    Text(value.as(String.self) ?? "")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
            }
        }
        .chartYAxis {
            let maxValue = cachedWeeklyActivity.values.max() ?? 43200
            let stepSize = maxValue / 4
            let axisValues = stride(from: 0.0, through: Double(maxValue), by: Double(stepSize)).map { $0 }
            
            AxisMarks(values: axisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color(NSColor.separatorColor))
                AxisValueLabel {
                    let hours = Int((value.as(Double.self) ?? 0) / 3600)
                    Text("\(hours)h")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }
            }
        }
        .chartYScale(domain: 0...(cachedWeeklyActivity.values.max() ?? 43200))
        .frame(height: 100)
        .animation(.easeInOut(duration: 0.8), value: "\(selectedDate)\(cachedWeeklyActivity.count)")
    }
    
    private var pieChartView: some View {
        let topFiveApps = Array(topApps.prefix(5))
        let colors: [Color] = [.blue, .green, .orange, .red, .purple]
        
        return HStack(spacing: 12) {
            Chart {
                ForEach(Array(topFiveApps.enumerated()), id: \.element.identifier) { index, app in
                    SectorMark(
                        angle: .value("Usage", app.totalTime),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colors[index % colors.count].opacity(0.8))
                    .opacity(1)
                }
            }
            .frame(width: 100, height: 100)
            .animation(.easeInOut(duration: 0.8), value: "\(selectedDate)\(topApps.count)")
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                ForEach(Array(topFiveApps.enumerated()), id: \.element.identifier) { index, app in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count].opacity(0.8))
                            .frame(width: 8, height: 8)
                        
                        Text(app.name)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 100)
    }
    
    private var weeklyPieChartView: some View {
        let topFiveApps = Array(weeklyTopApps.prefix(5))
        let colors: [Color] = [.blue, .green, .orange, .red, .purple]
        
        return HStack(spacing: 12) {
            Chart {
                ForEach(Array(topFiveApps.enumerated()), id: \.element.identifier) { index, app in
                    SectorMark(
                        angle: .value("Usage", app.totalTime),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(colors[index % colors.count].opacity(0.8))
                    .opacity(1)
                }
            }
            .frame(width: 100, height: 100)
            .animation(.easeInOut(duration: 0.8), value: "\(selectedDate)\(weeklyTopApps.count)")
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                ForEach(Array(topFiveApps.enumerated()), id: \.element.identifier) { index, app in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count].opacity(0.8))
                            .frame(width: 8, height: 8)
                        
                        Text(app.name)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 100)
    }
}