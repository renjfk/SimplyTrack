//
//  UsagePieChart.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 11.09.2025.
//

import Charts
import SwiftUI

/// Displays a pie chart showing top usage categories including apps and idle time.
/// Shows the top 5 usage categories by time with colored segments and labels.
struct UsagePieChart: View {
    /// Selected date for animation key
    let selectedDate: Date
    /// Top usage categories data for pie chart display (apps, idle, etc.)
    let topApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]

    private var topFiveApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        Array(topApps.prefix(6)) // Increased to 6 to accommodate idle time
    }

    private let colors: [Color] = [.blue, .green, .orange, .red, .purple, .gray]

    var body: some View {
        HStack(spacing: 12) {
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
}
