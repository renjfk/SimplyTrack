//
//  PrivacySettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 12.09.2025.
//

import SwiftUI

/// Privacy settings view for controlling private browsing tracking behavior.
/// Provides user control over whether private/incognito tabs should be tracked.
struct PrivacySettingsView: View {
    @AppStorage("trackPrivateBrowsing", store: .app) private var trackPrivateBrowsing = AppStorageDefaults.trackPrivateBrowsing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                            .padding(.top, 2)
                        Toggle("Track activity in private/incognito tabs", isOn: $trackPrivateBrowsing)
                            .toggleStyle(.switch)
                        Spacer()
                    }

                    Text("When enabled, SimplyTrack will monitor your activity even when browsing in private/incognito mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Text("Privacy Notice")
                            .font(.headline)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Private browsing tracking is disabled by default to protect your privacy")
                        Text("• When disabled, URLs from private/incognito tabs will not be recorded")
                        Text("• Some browsers may require additional permissions for private tab detection")
                        Text("• All supported browsers can detect private/incognito browsing mode")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text("Browser Support")
                            .font(.headline)
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Safari Private Browsing")
                        Spacer()
                        Text("Supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Chrome Incognito")
                        Spacer()
                        Text("Supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Edge InPrivate")
                        Spacer()
                        Text("Supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    PrivacySettingsView()
        .frame(width: 550, height: 400)
}
