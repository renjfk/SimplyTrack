//
//  HourlyTimelineChart.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 11.09.2025.
//

import SwiftUI

/// Displays a horizontal timeline showing work periods throughout the day.
/// Shows active periods as blue rectangles positioned according to their start time and duration.
struct HourlyTimelineChart: View {
    /// Selected date for timeline display
    let selectedDate: Date
    /// Work periods to display on the timeline
    let workPeriods: [(startTime: Date, endTime: Date, duration: TimeInterval)]
    
    var body: some View {
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
                    
                    ForEach(Array(workPeriods.enumerated()), id: \.offset) { index, period in
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
}