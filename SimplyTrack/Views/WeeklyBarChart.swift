//
//  WeeklyBarChart.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 11.09.2025.
//

import SwiftUI
import Charts

/// Displays a bar chart showing weekly activity breakdown by day.
/// Shows usage time for each day of the week with animated transitions.
struct WeeklyBarChart: View {
    /// Selected date for determining the week
    let selectedDate: Date
    /// Weekly activity data mapped by day abbreviation (MON, TUE, etc.)
    let weeklyActivity: [String: TimeInterval]
    
    var body: some View {
        Chart {
            ForEach(0..<7, id: \.self) { dayOffset in
                let calendar = Calendar.current
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) ?? selectedDate
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: dayDate) - 1]
                let dayKey = String(dayName.prefix(3)).uppercased()
                let totalTime = weeklyActivity[dayKey] ?? 0
                
                BarMark(
                    x: .value("Day", dayKey),
                    y: .value("Time", totalTime)
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
            let maxValue = weeklyActivity.values.max() ?? 43200
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
        .chartYScale(domain: 0...(weeklyActivity.values.max() ?? 43200))
        .frame(height: 100)
        .animation(.easeInOut(duration: 0.8), value: "\(selectedDate)\(weeklyActivity.count)")
    }
}
