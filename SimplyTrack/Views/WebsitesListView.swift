//
//  WebsitesListView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI

struct WebsitesListView: View {
    let websites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)]
    @Binding var showAllWebsites: Bool
    
    private var displayedWebsites: [(identifier: String, name: String, iconData: Data?, totalTime: TimeInterval)] {
        showAllWebsites ? websites : Array(websites.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Websites")
                    .font(.headline)
                Spacer()
                if websites.count > 5 {
                    Button(showAllWebsites ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAllWebsites.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(displayedWebsites.enumerated()), id: \.element.identifier) { index, website in
                    HStack {
                        IconView(type: .website(domain: website.name, iconData: website.iconData), size: 20)

                        Text(website.name)

                        Spacer()

                        Text(website.totalTime.formattedDuration)
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