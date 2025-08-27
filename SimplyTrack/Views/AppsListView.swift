//
//  AppsListView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI

struct AppsListView: View {
    let apps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    @Binding var showAllApps: Bool
    
    private var displayedApps: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        showAllApps ? apps : Array(apps.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Apps")
                    .font(.headline)
                Spacer()
                if apps.count > 5 {
                    Button(showAllApps ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllApps.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(displayedApps.enumerated()), id: \.element.identifier) { index, app in
                    HStack {
                        IconView(type: .app(identifier: app.identifier, iconData: app.iconData), size: 25)

                        Text(app.name)

                        Spacer()

                        Text(app.totalTime.formattedDuration)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
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
}