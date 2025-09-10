//
//  PermissionBannerView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 04.09.2025.
//

import SwiftUI

/// Displays informational banners for permission requests and error states.
/// Provides consistent styling for system permission prompts and error notifications.
/// Supports customizable colors, dismissal actions, and primary action buttons.
struct PermissionBannerView: View {
    /// Banner title text
    let title: String
    /// Detailed message text
    let message: String
    /// Title for the primary action button
    let primaryButtonTitle: String
    /// Primary action to perform when button is tapped
    let primaryAction: () -> Void
    /// Optional dismiss action for closeable banners
    let dismissAction: (() -> Void)?
    /// Accent color for the banner (affects border, background, and icon)
    let color: Color
    
    /// Creates a permission banner with specified content and styling
    /// - Parameters:
    ///   - title: Banner title text
    ///   - message: Detailed explanatory message
    ///   - primaryButtonTitle: Text for primary action button
    ///   - primaryAction: Action to perform when primary button is tapped
    ///   - dismissAction: Optional action for dismissing banner
    ///   - color: Accent color for styling (default: red)
    init(
        title: String,
        message: String,
        primaryButtonTitle: String,
        primaryAction: @escaping () -> Void,
        dismissAction: (() -> Void)? = nil,
        color: Color = .red
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.dismissAction = dismissAction
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                
                if let dismissAction = dismissAction {
                    Button("Dismiss") {
                        dismissAction()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button(primaryButtonTitle) {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}