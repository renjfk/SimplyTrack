//
//  SettingsWindow.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import SwiftUI

/// Main settings window with tabbed interface for app configuration.
/// Provides organized access to general settings and AI configuration options.
struct SettingsWindow: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("General")
                }
                .tag(0)

            AISettingsView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI")
                }
                .tag(1)

            PrivacySettingsView()
                .tabItem {
                    Image(systemName: "lock.fill")
                    Text("Privacy")
                }
                .tag(2)
        }
        .frame(width: 550, height: 400)
    }
}

#Preview {
    SettingsWindow()
}
